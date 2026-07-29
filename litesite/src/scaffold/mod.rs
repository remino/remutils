use crate::fsutil::{copy_file, write_file};
use anyhow::{bail, Context, Result};
use chrono::Datelike;
use mustache::MapBuilder;
use std::env;
use std::fs;
use std::path::{Component, Path, PathBuf};
use std::process::Command;
use walkdir::WalkDir;

const DEFAULT_TEMPLATE: &str = "default";
const TEMPLATE_SUFFIX: &str = ".mustache";

pub fn init_site(
    slug: &str,
    dest_arg: Option<&String>,
    template_arg: Option<&str>,
    lookup_root: &Path,
) -> Result<()> {
    if slug.is_empty() {
        bail!("USAGE: litesite new [--template <name-or-path>] <site_slug> [<dest_dir>]");
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
    let license_year = chrono::Local::now().year().to_string();
    let license_holder = license_holder();
    let context = MapBuilder::new()
        .insert_str("slug", slug)
        .insert_str("license_year", &license_year)
        .insert_str("license_holder", &license_holder)
        .build();

    fs::create_dir_all(&dest)?;
    for entry in WalkDir::new(&template).into_iter().filter_map(Result::ok) {
        if !entry.file_type().is_file() {
            continue;
        }

        let relative = entry.path().strip_prefix(&template)?;
        let output_relative = render_path(relative, slug);
        ensure_safe_relative_path(&output_relative)?;
        let output = dest.join(output_relative);
        let source = fs::read_to_string(entry.path())?;
        let content = if entry.path().to_string_lossy().ends_with(TEMPLATE_SUFFIX) {
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

fn resolve_template(template_arg: Option<&str>, lookup_root: &Path) -> Result<PathBuf> {
    let template_name = template_arg.unwrap_or(DEFAULT_TEMPLATE);
    let is_name = Path::new(template_name).components().count() == 1;

    if is_name {
        let built_in = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("templates")
            .join(template_name);
        if built_in.is_dir() {
            return Ok(built_in);
        }

        let mut dir = lookup_root;
        loop {
            for candidate in [
                dir.join(".litesite/templates").join(template_name),
                dir.join(".config/litesite/templates").join(template_name),
            ] {
                if candidate.is_dir() {
                    return Ok(candidate);
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
                return Ok(candidate);
            }
        }
    }

    let custom = lookup_root.join(template_name);
    if custom.is_dir() {
        return Ok(custom);
    }

    bail!("litesite: template not found: {template_name}")
}

fn render_path(path: &Path, slug: &str) -> PathBuf {
    let path = path.to_string_lossy();
    let path = path.strip_suffix(TEMPLATE_SUFFIX).unwrap_or(&path);
    PathBuf::from(path.replace("[slug]", slug))
}

fn render(template: &str, context: &mustache::Data) -> Result<String> {
    let template = mustache::compile_str(template).context("litesite: invalid Mustache template")?;
    let mut output = Vec::new();
    template
        .render_data(&mut output, context)
        .context("litesite: could not render Mustache template")?;
    String::from_utf8(output).context("litesite: template output is not UTF-8")
}

fn ensure_safe_relative_path(path: &Path) -> Result<()> {
    if path.as_os_str().is_empty()
        || path.is_absolute()
        || path
            .components()
            .any(|component| matches!(component, Component::ParentDir | Component::RootDir | Component::Prefix(_)))
    {
        bail!("litesite: template output escapes destination: {}", path.display());
    }
    Ok(())
}

fn license_holder() -> String {
    if let Ok(value) = env::var("LITESITE_LICENSE_HOLDER") {
        if !value.is_empty() {
            return value;
        }
    }
    if let Ok(output) = Command::new("git").args(["config", "user.name"]).output() {
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
        assert_eq!(
            render_path(Path::new("src/[slug].html.mustache"), "site"),
            PathBuf::from("src/site.html")
        );
    }
}
