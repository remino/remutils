use crate::fsutil::has_ext;
use anyhow::{anyhow, bail, Context, Result};
use comrak::{markdown_to_html, Options};
use minify_html::{minify, Cfg};
use regex::Regex;
use std::fs;
use std::path::{Path, PathBuf};

pub fn expand_html_includes(input: &Path, stack: &mut Vec<PathBuf>) -> Result<String> {
    let abs_file = input
        .canonicalize()
        .with_context(|| format!("litesite: cannot resolve {}", input.display()))?;

    if stack.contains(&abs_file) {
        let chain = stack
            .iter()
            .chain(std::iter::once(&abs_file))
            .map(|path| path.display().to_string())
            .collect::<Vec<_>>()
            .join(" -> ");
        bail!("litesite: circular include detected: {chain}");
    }

    let html = fs::read_to_string(&abs_file)
        .with_context(|| format!("litesite: cannot read {}", abs_file.display()))?;
    let pattern = Regex::new(r#"<!--#include\s+file="([^"]+)"\s*-->"#)?;
    let mut rendered = String::new();
    let mut last = 0;

    stack.push(abs_file.clone());
    for captures in pattern.captures_iter(&html) {
        let matched = captures.get(0).expect("include match");
        let include = captures.get(1).expect("include path").as_str();
        let include_path = if Path::new(include).is_absolute() {
            PathBuf::from(include)
        } else {
            abs_file
                .parent()
                .ok_or_else(|| {
                    anyhow!("litesite: cannot resolve parent for {}", abs_file.display())
                })?
                .join(include)
        };
        rendered.push_str(&html[last..matched.start()]);
        if has_ext(&include_path, &["md", "markdown"]) {
            rendered.push_str(&render_markdown_file(&include_path)?);
        } else {
            rendered.push_str(&expand_html_includes(&include_path, stack)?);
        }
        last = matched.end();
    }
    stack.pop();
    rendered.push_str(&html[last..]);

    Ok(rendered)
}

fn render_markdown_file(input: &Path) -> Result<String> {
    let markdown = fs::read_to_string(input)
        .with_context(|| format!("litesite: cannot read {}", input.display()))?;
    Ok(render_markdown(&markdown))
}

fn render_markdown(markdown: &str) -> String {
    let html = markdown_to_html(markdown, &markdown_options());
    render_block_attributes(markdown, html)
}

fn markdown_options() -> Options<'static> {
    let mut options = Options::default();
    options.extension.table = true;
    options.extension.description_lists = true;
    options.extension.header_attributes = true;
    options.extension.fenced_code_attributes = true;
    options.extension.inline_code_attributes = true;
    options.extension.link_attributes = true;
    options.parse.smart = true;
    options.render.r#unsafe = true;
    options
}

fn render_block_attributes(markdown: &str, mut html: String) -> String {
    let heading =
        Regex::new(r"^(#{1,6})\s+.*\{([^}]*)\}\s*#*\s*$").expect("valid heading attribute regex");
    let fenced_code = Regex::new(r"^(`{3,}|~{3,})[^\n]*\{([^}]*)\}\s*$")
        .expect("valid fenced-code attribute regex");

    let mut heading_position = 0;
    let mut code_position = 0;
    for line in markdown.lines() {
        if let Some(captures) = heading.captures(line) {
            let level = captures.get(1).expect("heading markers").as_str().len();
            let attrs = render_attributes(captures.get(2).expect("heading attributes").as_str());
            insert_attributes(
                &mut html,
                &format!("<h{level}"),
                &attrs,
                &mut heading_position,
            );
        } else if let Some(captures) = fenced_code.captures(line) {
            let attrs = render_attributes(captures.get(2).expect("code attributes").as_str());
            insert_attributes(&mut html, "<pre", &attrs, &mut code_position);
        }
    }

    html
}

fn render_attributes(input: &str) -> String {
    let mut ids = Vec::new();
    let mut classes = Vec::new();
    let mut pairs = Vec::new();

    for token in input.split_whitespace() {
        if let Some(id) = token.strip_prefix('#') {
            ids.push(id);
        } else if let Some(class) = token.strip_prefix('.') {
            classes.push(class);
        } else if let Some((key, value)) = token.split_once('=') {
            pairs.push((key, value.trim_matches('\"')));
        }
    }

    let mut rendered = String::new();
    if let Some(id) = ids.last() {
        rendered.push_str(&format!(" id=\"{}\"", escape_attribute(id)));
    }
    if !classes.is_empty() {
        rendered.push_str(&format!(
            " class=\"{}\"",
            escape_attribute(&classes.join(" "))
        ));
    }
    for (key, value) in pairs {
        rendered.push_str(&format!(
            " {}=\"{}\"",
            escape_attribute(key),
            escape_attribute(value)
        ));
    }
    rendered
}

fn insert_attributes(html: &mut String, tag: &str, attributes: &str, position: &mut usize) {
    if attributes.is_empty() {
        return;
    }
    if let Some(index) = html[*position..].find(tag).map(|index| index + *position) {
        html.insert_str(index + tag.len(), attributes);
        *position = index + tag.len() + attributes.len();
    }
}

fn escape_attribute(value: &str) -> String {
    value
        .replace('&', "&amp;")
        .replace('\"', "&quot;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

pub fn minify_html(html: &str) -> String {
    let html = remove_regular_html_comments(html);
    let cfg = Cfg {
        keep_closing_tags: true,
        keep_comments: true,
        minify_css: true,
        minify_js: true,
        ..Cfg::default()
    };

    String::from_utf8(minify(html.as_bytes(), &cfg)).unwrap_or(html)
}

pub fn minify_css(css: &str) -> String {
    let comments = important_block_comments(css);
    let css = remove_regular_block_comments(css);
    let minified = minify_html(&format!("<style>{css}</style>"))
        .strip_prefix("<style>")
        .and_then(|value| value.strip_suffix("</style>"))
        .unwrap_or(&css)
        .to_string();

    prepend_comments(comments, minified)
}

pub fn minify_js(js: &str) -> String {
    let comments = important_block_comments(js);
    let js = remove_regular_block_comments(js);
    let minified = minify_html(&format!("<script>{js}</script>"))
        .strip_prefix("<script>")
        .and_then(|value| value.strip_suffix("</script>"))
        .unwrap_or(&js)
        .to_string();

    prepend_comments(comments, minified)
}

fn remove_regular_html_comments(html: &str) -> String {
    let mut output = String::new();
    let mut rest = html;

    while let Some(start) = rest.find("<!--") {
        output.push_str(&rest[..start]);
        let comment_and_after = &rest[start..];
        if let Some(end) = comment_and_after.find("-->") {
            let comment = &comment_and_after[..end + 3];
            if comment.starts_with("<!--!") {
                output.push_str(comment);
            }
            rest = &comment_and_after[end + 3..];
        } else {
            rest = comment_and_after;
            break;
        }
    }

    output.push_str(rest);
    output
}

fn important_block_comments(input: &str) -> Vec<String> {
    Regex::new(r#"(?s)/\*!.*?\*/"#)
        .expect("valid important comment regex")
        .find_iter(input)
        .map(|matched| matched.as_str().to_string())
        .collect()
}

fn remove_regular_block_comments(input: &str) -> String {
    let mut output = String::new();
    let mut rest = input;

    while let Some(start) = rest.find("/*") {
        output.push_str(&rest[..start]);
        let comment_and_after = &rest[start..];
        if let Some(end) = comment_and_after.find("*/") {
            let comment = &comment_and_after[..end + 2];
            if comment.starts_with("/*!") {
                output.push_str(comment);
            }
            rest = &comment_and_after[end + 2..];
        } else {
            rest = comment_and_after;
            break;
        }
    }

    output.push_str(rest);
    output
}

fn prepend_comments(comments: Vec<String>, minified: String) -> String {
    if comments.is_empty() {
        return minified;
    }

    format!("{}\n{}", comments.join("\n"), minified)
}

#[cfg(test)]
mod tests {
    use super::render_markdown;

    #[test]
    fn markdown_options_render_supported_extensions() {
        let html = render_markdown(
            "# Heading {.feature #markdown-heading}\n\n\
             \"Smart quotes\" and -- dashes.\n\n\
             | Name | Value |\n| --- | --- |\n| One | Two |\n\n\
             Term\n\n: Definition\n\n\
             ```rust {.code #sample-code}\nlet answer = 42;\n```\n\n\
             <aside>Embedded HTML.</aside>\n",
        );

        assert!(html.contains("id=\"markdown-heading\""));
        assert!(html.contains("class=\"feature\""));
        assert!(html.contains("“Smart quotes” and – dashes."));
        assert!(html.contains("<table>"));
        assert!(html.contains("<dl>"));
        assert!(html.contains("id=\"sample-code\""));
        assert!(html.contains("<aside>Embedded HTML.</aside>"));
    }
}
