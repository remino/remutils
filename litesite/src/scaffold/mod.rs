mod templates;

use crate::fsutil::{copy_file, write_file};
use anyhow::{bail, Result};
use chrono::Datelike;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use templates::*;

pub fn init_site(slug: &str, dest_arg: Option<&String>) -> Result<()> {
    if slug.is_empty() {
        bail!("USAGE: litesite new <site_slug> [<dest_dir>]");
    }
    if slug.contains('/') {
        bail!("litesite: SITE_SLUG must not contain /");
    }

    let dest = dest_arg
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(format!("./{slug}")));
    let license_year = chrono::Local::now().year();
    let license_holder = license_holder();

    if dest.exists() {
        bail!("litesite: destination already exists: {}", dest.display());
    }

    fs::create_dir_all(dest.join(format!("src/public/{slug}")))?;
    fs::create_dir_all(dest.join("src/nginx"))?;

    write_file(&dest.join(".editorconfig"), EDITORCONFIG)?;
    write_file(&dest.join(".deploy-filter"), "- .DS_Store\n")?;
    write_file(&dest.join(".gitignore"), GITIGNORE)?;
    write_file(&dest.join(".env.example"), ENV_EXAMPLE)?;
    copy_file(&dest.join(".env.example"), &dest.join(".env"))?;
    write_file(&dest.join("justfile"), JUSTFILE)?;
    write_file(
        &dest.join("README.md"),
        &README_TEMPLATE.replace("__SITE_SLUG__", slug),
    )?;
    write_file(
        &dest.join("LICENSE.txt"),
        &format!("{LICENSE_TEMPLATE_START}{license_year} {license_holder}{LICENSE_TEMPLATE_END}"),
    )?;
    write_file(&dest.join("src/public/index.html"), &index_html(slug))?;
    write_file(&dest.join("src/public/style.css"), STYLE_CSS)?;
    write_file(&dest.join("src/public/main.js"), MAIN_JS)?;
    write_file(&dest.join("src/public/favicon.svg"), FAVICON_SVG)?;
    write_file(&dest.join("src/public/share.svg"), SHARE_SVG)?;
    write_file(
        &dest.join(format!("src/nginx/{slug}.conf")),
        &format!("# {slug}\nserver {{\n\tlisten 80;\n\tserver_name {slug};\n}}\n"),
    )?;

    let _ = Command::new("git")
        .arg("-C")
        .arg(&dest)
        .arg("init")
        .arg("-q")
        .status();
    println!("Created {}", dest.display());

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
