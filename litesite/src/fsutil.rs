use anyhow::Result;
use std::ffi::OsStr;
use std::fs;
use std::path::Path;

pub fn write_file(path: &Path, contents: &str) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, contents)?;
    Ok(())
}

pub fn copy_file(input: &Path, output: &Path) -> Result<()> {
    if let Some(parent) = output.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::copy(input, output)?;
    Ok(())
}

pub fn remove_dir_if_exists(path: &Path) -> Result<()> {
    if path.exists() {
        fs::remove_dir_all(path)?;
    }
    Ok(())
}

pub fn has_ext(path: &Path, exts: &[&str]) -> bool {
    path.extension()
        .and_then(OsStr::to_str)
        .map(|ext| {
            exts.iter()
                .any(|candidate| ext.eq_ignore_ascii_case(candidate))
        })
        .unwrap_or(false)
}
