use crate::fsutil::has_ext;
use anyhow::Result;
use brotli::CompressorWriter;
use flate2::write::GzEncoder;
use flate2::Compression;
use std::ffi::OsStr;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

const COMPRESSIBLE_EXTENSIONS: &[&str] = &[
    "html",
    "css",
    "js",
    "mjs",
    "cjs",
    "svg",
    "json",
    "xml",
    "txt",
    "webmanifest",
    "wasm",
];

pub fn build_compressed_files(target: &Path) -> Result<()> {
    build_brotli(target)?;
    build_gzip(target)?;
    build_zstd(target)
}

pub fn build_brotli(target: &Path) -> Result<()> {
    if !target.is_dir() {
        return Ok(());
    }
    for file in compressible_files(target) {
        let input = fs::read(&file)?;
        let output = file.with_file_name(format!(
            "{}.br",
            file.file_name().and_then(OsStr::to_str).unwrap_or_default()
        ));
        let mut encoder = CompressorWriter::new(Vec::new(), 4096, 11, 22);
        encoder.write_all(&input)?;
        fs::write(output, encoder.into_inner())?;
    }
    Ok(())
}

pub fn build_gzip(target: &Path) -> Result<()> {
    if !target.is_dir() {
        return Ok(());
    }
    for file in compressible_files(target) {
        let input = fs::read(&file)?;
        let output = file.with_file_name(format!(
            "{}.gz",
            file.file_name().and_then(OsStr::to_str).unwrap_or_default()
        ));
        let mut encoder = GzEncoder::new(Vec::new(), Compression::best());
        encoder.write_all(&input)?;
        fs::write(output, encoder.finish()?)?;
    }
    Ok(())
}

pub fn build_zstd(target: &Path) -> Result<()> {
    if !target.is_dir() {
        return Ok(());
    }
    for file in compressible_files(target) {
        let input = fs::read(&file)?;
        let output = file.with_file_name(format!(
            "{}.zst",
            file.file_name().and_then(OsStr::to_str).unwrap_or_default()
        ));
        fs::write(output, zstd::encode_all(input.as_slice(), 19)?)?;
    }
    Ok(())
}

fn compressible_files(target: &Path) -> Vec<PathBuf> {
    WalkDir::new(target)
        .into_iter()
        .filter_map(Result::ok)
        .filter(|entry| entry.file_type().is_file())
        .map(|entry| entry.into_path())
        .filter(|path| {
            has_ext(path, COMPRESSIBLE_EXTENSIONS) && !has_ext(path, &["br", "gz", "zst"])
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_compressible_extensions() {
        assert!(has_ext(Path::new("index.html"), COMPRESSIBLE_EXTENSIONS));
        assert!(!has_ext(Path::new("image.avif"), COMPRESSIBLE_EXTENSIONS));
    }
}
