use crate::fsutil::{copy_file, write_file};
use anyhow::{bail, Context, Result};
use chrono::Datelike;
use include_dir::{include_dir, Dir};
use mustache::MapBuilder;
use regex::Regex;
use serde_json::Value;
use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::{Component, Path, PathBuf};
use std::process::Command;
use walkdir::WalkDir;

const DEFAULT_TEMPLATE: &str = "default";
const TEMPLATE_SUFFIX: &str = ".mustache";
const TEMPLATE_VARIABLES_FILE: &str = ".litesite.json";
static BUILT_IN_TEMPLATES: Dir<'_> = include_dir!("$CARGO_MANIFEST_DIR/templates");

enum Template {
    Directory(PathBuf),
    Embedded(&'static Dir<'static>),
}

pub fn init_site(
    slug: &str,
    dest_arg: Option<&String>,
    template_arg: Option<&str>,
    extra_variables: &BTreeMap<String, String>,
    lookup_root: &Path,
) -> Result<()> {
    if slug.is_empty() {
        bail!("USAGE: litesite new [options] <site_slug> [<dest_dir>]");
    }
    if slug.contains('/') {
        bail!("litesite: SITE_SLUG must not contain /");
    }

    let dest = dest_arg
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(format!("./{slug}")));
    if dest.exists() {
        bail!("litesite: destination already exists: {}", dest.display());
    }

    let template = resolve_template(template_arg, lookup_root)?;
    let year = chrono::Local::now().year().to_string();
    let author = author(lookup_root);
    let mut variables = BTreeMap::from([
        ("slug".to_string(), slug.to_string()),
        ("year".to_string(), year),
        ("author".to_string(), author),
    ]);
    variables.extend(load_template_variables(&template)?);
    variables.extend(extra_variables.clone());
    let context = variables
        .iter()
        .fold(MapBuilder::new(), |builder, (key, value)| {
            builder.insert_str(key, value)
        });
    let context = context.build();

    fs::create_dir_all(&dest)?;
    for (relative, source) in template_files(&template)? {
        if relative == Path::new(TEMPLATE_VARIABLES_FILE) {
            continue;
        }
        let output_relative = render_path(&relative, &variables);
        ensure_safe_relative_path(&output_relative)?;
        let output = dest.join(output_relative);
        let content = if relative.to_string_lossy().ends_with(TEMPLATE_SUFFIX) {
            render(&source, &context)?
        } else {
            source
        };

        write_file(&output, &content)?;
    }
    if dest.join(".env.example").is_file() {
        copy_file(&dest.join(".env.example"), &dest.join(".env"))?;
    }

    let _ = Command::new("git")
        .arg("-C")
        .arg(&dest)
        .arg("init")
        .arg("-q")
        .status();
    println!("Created {}", dest.display());

    Ok(())
}

fn load_template_variables(template: &Template) -> Result<BTreeMap<String, String>> {
    let (content, label) = match template {
        Template::Directory(template) => {
            let path = template.join(TEMPLATE_VARIABLES_FILE);
            if !path.is_file() {
                return Ok(BTreeMap::new());
            }
            (
                fs::read_to_string(&path)
                    .with_context(|| format!("litesite: cannot read {}", path.display()))?,
                path.display().to_string(),
            )
        }
        Template::Embedded(template) => match template.get_file(TEMPLATE_VARIABLES_FILE) {
            Some(file) => (
                file.contents_utf8()
                    .context("litesite: built-in template variables are not UTF-8")?
                    .to_string(),
                format!("built-in/{TEMPLATE_VARIABLES_FILE}"),
            ),
            None => return Ok(BTreeMap::new()),
        },
    };
    let config =
        serde_json::from_str(&content).with_context(|| format!("litesite: invalid {label}"))?;
    let Value::Object(mut config) = config else {
        bail!("litesite: {label} must contain a JSON object");
    };
    let Some(Value::Object(values)) = config.remove("vars") else {
        bail!("litesite: {label} must contain a vars object");
    };

    values
        .into_iter()
        .map(|(key, value)| {
            validate_template_variable_key(&key)?;
            let Value::String(value) = value else {
                bail!("litesite: template variable {key} must be a string");
            };
            Ok((key, value))
        })
        .collect()
}

fn validate_template_variable_key(key: &str) -> Result<()> {
    if key == "slug" {
        bail!("litesite: template variable is reserved: {key}");
    }
    if key.is_empty()
        || !key.chars().enumerate().all(|(index, character)| {
            character == '_'
                || character.is_ascii_alphanumeric()
                    && (index > 0 || character.is_ascii_alphabetic())
        })
    {
        bail!("litesite: invalid template variable name: {key}");
    }
    Ok(())
}

fn resolve_template(template_arg: Option<&str>, lookup_root: &Path) -> Result<Template> {
    let template_name = template_arg.unwrap_or(DEFAULT_TEMPLATE);
    let is_name = Path::new(template_name).components().count() == 1;

    if is_name {
        let template_roots = [
            env::var_os("LITESITE_TEMPLATE_DIR").map(PathBuf::from),
            Some(Path::new(env!("CARGO_MANIFEST_DIR")).join("templates")),
        ];
        for template_root in template_roots.into_iter().flatten() {
            let built_in = template_root.join(template_name);
            if built_in.is_dir() {
                return Ok(Template::Directory(built_in));
            }
        }
        if let Some(built_in) = BUILT_IN_TEMPLATES.get_dir(template_name) {
            return Ok(Template::Embedded(built_in));
        }

        let mut dir = lookup_root;
        loop {
            for candidate in [
                dir.join(".litesite/templates").join(template_name),
                dir.join(".config/litesite/templates").join(template_name),
            ] {
                if candidate.is_dir() {
                    return Ok(Template::Directory(candidate));
                }
            }

            let Some(parent) = dir.parent() else {
                break;
            };
            if parent == dir {
                break;
            }
            dir = parent;
        }

        let config_home = env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".config")));
        if let Some(config_home) = config_home {
            let candidate = config_home.join("litesite/templates").join(template_name);
            if candidate.is_dir() {
                return Ok(Template::Directory(candidate));
            }
        }
    }

    let custom = lookup_root.join(template_name);
    if custom.is_dir() {
        return Ok(Template::Directory(custom));
    }

    bail!("litesite: template not found: {template_name}")
}

fn template_files(template: &Template) -> Result<Vec<(PathBuf, String)>> {
    match template {
        Template::Directory(template) => WalkDir::new(template)
            .into_iter()
            .filter_map(Result::ok)
            .filter(|entry| entry.file_type().is_file())
            .map(|entry| {
                Ok((
                    entry.path().strip_prefix(template)?.to_path_buf(),
                    fs::read_to_string(entry.path())?,
                ))
            })
            .collect(),
        Template::Embedded(template) => template
            .files()
            .map(|file| {
                Ok((
                    file.path().strip_prefix(template.path())?.to_path_buf(),
                    file.contents_utf8()
                        .context("litesite: built-in template file is not UTF-8")?
                        .to_string(),
                ))
            })
            .collect(),
    }
}

fn render_path(path: &Path, variables: &BTreeMap<String, String>) -> PathBuf {
    let path = path.to_string_lossy();
    let path = path.strip_suffix(TEMPLATE_SUFFIX).unwrap_or(&path);
    let placeholder = Regex::new(r"\[([a-zA-Z0-9_]+)\]").expect("valid path placeholder regex");
    PathBuf::from(
        placeholder
            .replace_all(path, |captures: &regex::Captures| {
                variables
                    .get(&captures[1])
                    .cloned()
                    .unwrap_or_else(|| captures[0].to_string())
            })
            .into_owned(),
    )
}

fn render(template: &str, context: &mustache::Data) -> Result<String> {
    let template =
        mustache::compile_str(template).context("litesite: invalid Mustache template")?;
    let mut output = Vec::new();
    template
        .render_data(&mut output, context)
        .context("litesite: could not render Mustache template")?;
    String::from_utf8(output).context("litesite: template output is not UTF-8")
}

fn ensure_safe_relative_path(path: &Path) -> Result<()> {
    if path.as_os_str().is_empty()
        || path.is_absolute()
        || path.components().any(|component| {
            matches!(
                component,
                Component::ParentDir | Component::RootDir | Component::Prefix(_)
            )
        })
    {
        bail!(
            "litesite: template output escapes destination: {}",
            path.display()
        );
    }
    Ok(())
}

fn author(lookup_root: &Path) -> String {
    if let Ok(output) = Command::new("git")
        .arg("-C")
        .arg(lookup_root)
        .args(["config", "--local", "user.name"])
        .output()
    {
        if output.status.success() {
            let value = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if !value.is_empty() {
                return value;
            }
        }
    }
    if let Ok(output) = Command::new("whoami").output() {
        if output.status.success() {
            let value = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if !value.is_empty() {
                return value;
            }
        }
    }
    "Your Name".to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_unsafe_rendered_paths() {
        assert!(ensure_safe_relative_path(Path::new("../outside")).is_err());
        assert!(ensure_safe_relative_path(Path::new("/outside")).is_err());
        assert!(ensure_safe_relative_path(Path::new("src/index.html")).is_ok());
    }

    #[test]
    fn path_placeholders_match_comprose_format() {
        let variables = BTreeMap::from([
            ("slug".to_string(), "site".to_string()),
            ("section".to_string(), "docs".to_string()),
        ]);
        assert_eq!(
            render_path(Path::new("src/[section]/[slug].html.mustache"), &variables),
            PathBuf::from("src/docs/site.html")
        );
    }
}
