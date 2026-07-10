use crate::compress::{build_brotli, build_gzip, build_zstd};
use crate::config::{env_enabled, env_enabled_includes, load_site_env};
use crate::fsutil::{copy_file, has_ext, remove_dir_if_exists, write_file};
use crate::media::{build_media, MediaMode};
use crate::minify::{expand_html_includes, minify_css, minify_html, minify_js};
use anyhow::Result;
use std::collections::HashMap;
use std::fs;
use std::path::Path;
use walkdir::WalkDir;

pub fn build_site(root: &Path) -> Result<()> {
    let values = load_site_env(root)?;
    let src = root.join("src");
    let dist = root.join("dist");

    remove_dir_if_exists(&dist)?;
    minify_site(&src, &dist, &values)?;

    if env_enabled(&values, "LITESITE_BUILD_AVIF_JPEG") {
        build_media(&dist, MediaMode::Jpg)?;
    }
    if env_enabled(&values, "LITESITE_BUILD_AVIF_WEBP") {
        build_media(&dist, MediaMode::Webp)?;
    }
    if env_enabled(&values, "LITESITE_BUILD_BROTLI") {
        build_brotli(&dist)?;
    }
    if env_enabled(&values, "LITESITE_BUILD_GZIP") {
        build_gzip(&dist)?;
    }
    if env_enabled(&values, "LITESITE_BUILD_ZSTD") {
        build_zstd(&dist)?;
    }

    Ok(())
}

fn minify_site(src: &Path, dist: &Path, values: &HashMap<String, String>) -> Result<()> {
    fs::create_dir_all(dist)?;
    let do_minify = env_enabled(values, "LITESITE_BUILD_MINIFY");

    for entry in WalkDir::new(src).into_iter().filter_map(Result::ok) {
        if !entry.file_type().is_file() {
            continue;
        }

        let file = entry.path();
        let rel = file.strip_prefix(src)?;
        let target = dist.join(rel);

        if do_minify {
            if has_ext(rel, &["html"]) {
                let html = if env_enabled_includes(values) {
                    expand_html_includes(file, &mut Vec::new())?
                } else {
                    fs::read_to_string(file)?
                };
                write_file(&target, &minify_html(&html))?;
            } else if has_ext(rel, &["js", "mjs", "cjs"]) {
                write_file(&target, &minify_js(&fs::read_to_string(file)?))?;
            } else if has_ext(rel, &["css"]) {
                write_file(&target, &minify_css(&fs::read_to_string(file)?))?;
            } else {
                copy_file(file, &target)?;
            }
        } else if has_ext(rel, &["html"]) && env_enabled_includes(values) {
            write_file(&target, &expand_html_includes(file, &mut Vec::new())?)?;
        } else {
            copy_file(file, &target)?;
        }
    }

    Ok(())
}
