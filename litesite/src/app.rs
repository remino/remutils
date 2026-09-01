use crate::build::build_site;
use crate::compress::build_compressed_files;
use crate::config::ensure_site_root;
use crate::deploy::run_rsdeploy;
use crate::fsutil::remove_dir_if_exists;
use crate::media::{avif_to_jpg, avif_to_webp, build_media, MediaMode};
use crate::scaffold::init_site;
use crate::serve::serve_site;
use anyhow::{bail, Context, Result};
use serde_json::Value;
use std::collections::BTreeMap;
use std::env;
use std::fs;
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
        "new" | "init" => {
            let new_args = parse_new_args(&args)?;
            init_site(
                &new_args.slug,
                new_args.dest.as_ref(),
                new_args.template.as_deref(),
                &new_args.variables,
                &site_root,
            )?;
        }
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

struct NewArgs {
    template: Option<String>,
    slug: String,
    dest: Option<String>,
    variables: BTreeMap<String, String>,
}

fn parse_new_args(args: &[String]) -> Result<NewArgs> {
    let mut template = None;
    let mut positional = Vec::new();
    let mut variables = BTreeMap::new();
    let mut index = 0;

    while index < args.len() {
        match args[index].as_str() {
            "-t" | "--template" => {
                let value = args
                    .get(index + 1)
                    .context(format!("litesite: missing argument for {}", args[index]))?;
                template = Some(value.clone());
                index += 2;
            }
            "--var" => {
                let value = args
                    .get(index + 1)
                    .context("litesite: missing argument for --var")?;
                let (key, value) = parse_variable(value)?;
                variables.insert(key, value);
                index += 2;
            }
            "--vars" => {
                let path = args
                    .get(index + 1)
                    .context("litesite: missing argument for --vars")?;
                for (key, value) in read_variables_file(path)? {
                    variables.insert(key, value);
                }
                index += 2;
            }
            value if value.starts_with('-') => bail!("litesite: unknown option: {value}"),
            value => {
                positional.push(value.to_string());
                index += 1;
            }
        }
    }

    if positional.len() > 2 {
        bail!("USAGE: litesite new [options] <site_slug> [<dest_dir>]");
    }

    Ok(NewArgs {
        template,
        slug: positional.first().cloned().unwrap_or_default(),
        dest: positional.get(1).cloned(),
        variables,
    })
}

fn parse_variable(value: &str) -> Result<(String, String)> {
    let (key, value) = value
        .split_once('=')
        .context("litesite: --var must use KEY=VALUE")?;
    validate_variable_key(key)?;
    Ok((key.to_string(), value.to_string()))
}

fn read_variables_file(path: &str) -> Result<BTreeMap<String, String>> {
    let content = fs::read_to_string(path)
        .with_context(|| format!("litesite: cannot read variables file: {path}"))?;
    let values: BTreeMap<String, Value> = serde_json::from_str(&content)
        .with_context(|| format!("litesite: invalid JSON variables file: {path}"))?;

    values
        .into_iter()
        .map(|(key, value)| {
            validate_variable_key(&key)?;
            let Value::String(value) = value else {
                bail!("litesite: JSON variable {key} must be a string");
            };
            Ok((key, value))
        })
        .collect()
}

fn validate_variable_key(key: &str) -> Result<()> {
    if key == "slug" {
        bail!("litesite: variable is reserved: {key}");
    }
    if key.is_empty()
        || !key.chars().enumerate().all(|(index, character)| {
            character == '_'
                || character.is_ascii_alphanumeric()
                    && (index > 0 || character.is_ascii_alphabetic())
        })
    {
        bail!("litesite: invalid variable name: {key}");
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
\tnew [options] <slug> [<dest>]
\t                      Create a new site scaffold
\tinit [options] <slug> [<dest>]
\t                      Alias for new
\tjpg <files...>        Convert AVIF files to JPG
\twebp <files...>       Convert AVIF files to WebP

OPTIONS:

\t-C <dir>    Run the command against a different site root.
\t-t <name>   Select the template for new or init.
\t--var K=V   Add a template variable; may be repeated.
\t--vars FILE Add string variables from a JSON object.
\t-h          Show this help screen.
\t-v          Show version information.

When no command is supplied, this screen is shown.
"
    )
}
