use crate::build::build_site;
use crate::compress::build_compressed_files;
use crate::config::ensure_site_root;
use crate::deploy::run_rsdeploy;
use crate::fsutil::remove_dir_if_exists;
use crate::media::{avif_to_jpg, avif_to_webp, build_media, MediaMode};
use crate::scaffold::init_site;
use crate::serve::serve_site;
use anyhow::{bail, Context, Result};
use std::env;
use std::path::{Path, PathBuf};

const VERSION: &str = env!("CARGO_PKG_VERSION");
const SCRIPT_NAME: &str = "litesite";

pub async fn run() -> Result<()> {
    let mut args: Vec<String> = env::args().skip(1).collect();
    let mut site_root =
        env::current_dir().context("litesite: cannot determine current directory")?;

    while let Some(arg) = args.first().cloned() {
        match arg.as_str() {
            "-C" | "--cwd" => {
                if args.len() < 2 {
                    bail!("litesite: missing argument for {arg}");
                }
                site_root = PathBuf::from(args[1].clone());
                args.drain(0..2);
            }
            "-h" | "--help" => {
                print_usage();
                return Ok(());
            }
            "-v" | "--version" => {
                println!("{SCRIPT_NAME} {VERSION}");
                return Ok(());
            }
            "--" => {
                args.remove(0);
                break;
            }
            value if value.starts_with('-') => bail!("litesite: unknown option: {value}"),
            _ => break,
        }
    }

    let command = args
        .first()
        .map(String::as_str)
        .unwrap_or("help")
        .to_string();
    if !args.is_empty() {
        args.remove(0);
    }

    match command.as_str() {
        "build" => {
            ensure_site_root(&site_root)?;
            build_site(&site_root)?;
        }
        "clean" => {
            ensure_site_root(&site_root)?;
            remove_dir_if_exists(&site_root.join("dist"))?;
        }
        "serve" => {
            ensure_site_root(&site_root)?;
            serve_site(&site_root).await?;
        }
        "deploy" => {
            ensure_site_root(&site_root)?;
            let dry_run = args.first().map(String::as_str) == Some("-n");
            if dry_run {
                args.remove(0);
            }
            build_site(&site_root)?;
            run_rsdeploy(&site_root, dry_run, &args)?;
        }
        "compress" => {
            ensure_site_root(&site_root)?;
            build_compressed_files(&site_root.join("dist"))?;
        }
        "media" => {
            ensure_site_root(&site_root)?;
            build_media(&site_root.join("dist"), MediaMode::All)?;
        }
        "new" | "init" => init_site(args.first().map(String::as_str).unwrap_or(""), args.get(1))?,
        "jpg" => {
            if args.is_empty() {
                bail!("USAGE: litesite jpg <file.avif> [<file.avif...>]");
            }
            for file in args {
                avif_to_jpg(Path::new(&file), None)?;
            }
        }
        "webp" | "webm" => {
            if args.is_empty() {
                bail!("USAGE: litesite webp <file.avif> [<file.avif...>]");
            }
            for file in args {
                avif_to_webp(Path::new(&file), None)?;
            }
        }
        "version" => println!("{SCRIPT_NAME} {VERSION}"),
        "help" => print_usage(),
        _ => {
            eprintln!("litesite: unknown command: {command}");
            print_usage_to_stderr();
            std::process::exit(1);
        }
    }

    Ok(())
}

fn print_usage() {
    print!("{}", usage());
}

fn print_usage_to_stderr() {
    eprint!("{}", usage());
}

fn usage() -> String {
    format!(
        "litesite {VERSION}

USAGE: litesite [<options>] [<command> [<args...>]]

Create and work with tiny static sites that keep their source in src/ and
publish to dist/.

COMMANDS:

\tbuild                 Build dist/ from src/
\tclean                 Remove dist/
\tserve                 Run a local preview server
\tdeploy                Build and deploy dist/; use -n for a dry-run
\tcompress              Regenerate Brotli, gzip, and zstd files
\tmedia                 Regenerate AVIF JPG and WebP derivatives
\tnew <slug> [<dest>]   Create a new site scaffold
\tinit <slug> [<dest>]  Alias for new
\tjpg <files...>        Convert AVIF files to JPG
\twebp <files...>       Convert AVIF files to WebP

OPTIONS:

\t-C <dir>    Run the command against a different site root.
\t-h          Show this help screen.
\t-v          Show version information.

When no command is supplied, this screen is shown.
"
    )
}
