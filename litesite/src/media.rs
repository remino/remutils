use crate::fsutil::has_ext;
use anyhow::{bail, Context, Result};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use walkdir::WalkDir;

#[derive(Clone, Copy)]
pub enum MediaMode {
    All,
    Jpg,
    Webp,
}

pub fn build_media(dist: &Path, mode: MediaMode) -> Result<()> {
    if !dist.is_dir() {
        return Ok(());
    }

    for entry in WalkDir::new(dist).into_iter().filter_map(Result::ok) {
        let path = entry.path();
        if !entry.file_type().is_file() || !has_ext(path, &["avif"]) {
            continue;
        }

        match mode {
            MediaMode::All => {
                avif_to_jpg(path, None)?;
                avif_to_webp(path, None)?;
            }
            MediaMode::Jpg => avif_to_jpg(path, None)?,
            MediaMode::Webp => avif_to_webp(path, None)?,
        }
    }

    Ok(())
}

pub fn avif_to_jpg(input: &Path, output: Option<&Path>) -> Result<()> {
    if !input.is_file() {
        return Ok(());
    }
    let default_output = PathBuf::from(format!("{}.jpg", input.display()));
    let output = output.unwrap_or(&default_output);
    run_magick(input, output, "85")
}

pub fn avif_to_webp(input: &Path, output: Option<&Path>) -> Result<()> {
    if !input.is_file() {
        return Ok(());
    }
    let default_output = PathBuf::from(format!("{}.webp", input.display()));
    let output = output.unwrap_or(&default_output);
    run_magick(input, output, "82")
}

fn run_magick(input: &Path, output: &Path, quality: &str) -> Result<()> {
    if let Some(parent) = output.parent() {
        fs::create_dir_all(parent)?;
    }
    let status = Command::new("magick")
        .arg(input)
        .args([
            "-auto-orient",
            "-background",
            "white",
            "-alpha",
            "remove",
            "-strip",
            "-quality",
            quality,
        ])
        .arg(output)
        .status()
        .context("litesite: failed to run magick")?;
    if !status.success() {
        bail!("litesite: magick failed");
    }
    Ok(())
}
