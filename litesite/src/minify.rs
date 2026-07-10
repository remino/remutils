use anyhow::{anyhow, bail, Context, Result};
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
        rendered.push_str(&expand_html_includes(&include_path, stack)?);
        last = matched.end();
    }
    stack.pop();
    rendered.push_str(&html[last..]);

    Ok(rendered)
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
