use crate::config::load_site_env;
use anyhow::{bail, Context, Result};
use std::path::Path;
use std::process::Command;

pub fn run_rsdeploy(root: &Path, dry_run: bool, extra_args: &[String]) -> Result<()> {
    let values = load_site_env(root)?;
    let mut command = Command::new("rsdeploy");
    command.current_dir(root);
    command
        .arg("-s")
        .arg("dist/")
        .arg("-f")
        .arg(".deploy-filter");
    if !dry_run {
        command.arg("-w");
    }
    command.args(extra_args);
    for (key, value) in values {
        command.env(key, value);
    }
    let status = command
        .status()
        .context("litesite: failed to run rsdeploy")?;
    if !status.success() {
        bail!("litesite: rsdeploy failed");
    }
    Ok(())
}
