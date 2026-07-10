use anyhow::{anyhow, Result};
use std::env;
use std::path::Path;

pub async fn serve_site(root: &Path) -> Result<()> {
    let public = root.join("src/public");
    let port = env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let addr = format!("0.0.0.0:{port}");

    if env::var("LITESITE_SERVE_ONCE").is_ok() {
        println!("Serving \"./src/public\" at http://127.0.0.1:{port}");
        return Ok(());
    }

    live_server::listen(&addr, public)
        .await
        .map_err(|error| anyhow!("litesite: failed to start live server: {error}"))?
        .start(live_server::Options::default())
        .await
        .map_err(|error| anyhow!("litesite: live server failed: {error}"))
}
