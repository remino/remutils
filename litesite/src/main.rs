#[tokio::main]
async fn main() {
    if let Err(error) = litesite::run().await {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
