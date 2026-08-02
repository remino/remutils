# CHANGELOG

<!-- mtoc-start -->

- [v2.3.1](#v231)
- [v2.2.0](#v220)
- [v2.1.0](#v210)
- [v2.0.0](#v200)
- [v1.3.1](#v131)
- [v1.0.0](#v100)

<!-- mtoc-end -->

## v2.3.1

- Prepare `litesite` for publication to crates.io and document installation with
  Cargo.

## v2.2.0

- Extract the default site scaffold into a Mustache template directory.
- Add `litesite new --template` (and `-t`) with built-in, project-local, XDG
  config, and explicit-path template resolution.
- Add repeatable `--var KEY=VALUE` and `--vars FILE.json` template variables for
  both Mustache content and bracketed output paths.
- Let templates set default variables in a root `.litesite.json`, without
  copying that metadata file into generated sites.
- Rename default license variables to `year` and `author`, and let templates or
  command-line variables override them. `author` now falls back from local Git
  configuration to `whoami`, then `Your Name`.

## v2.1.0

- Make `litesite serve` print the program name, served root directory, local
  URL, bind address, and a `Ctrl-C` stop hint when the preview server starts.
- Make `litesite serve` log file access requests and live-reload events with a
  shared output style.
- Make `litesite serve` use Tornado-style log prefixes with ANSI colors similar
  to `python-livereload`.
- Make `litesite serve` switch to SSE live reload with CSS-only hot swaps and
  boot-id reconnect handling inspired by `umbral-livereload`.

## v2.0.0

- Port `litesite` to a Rust-backed executable, using native Rust build,
  compression, dotenv, and live-server integrations.
- Benchmark results against the previous Bash implementation on a 441-file
  fixture, with AVIF conversion disabled:

| Benchmark                       | Bash      | Rust     | Result             |
| ------------------------------- | --------- | -------- | ------------------ |
| `version`                       | 8.1 ms    | 5.3 ms   | Rust 1.5x faster   |
| `init` scaffold                 | 62.3 ms   | 18.3 ms  | Rust 3.4x faster   |
| build copy-only                 | 2.124 s   | 37.1 ms  | Rust 57.3x faster  |
| build with includes             | 5.539 s   | 63.5 ms  | Rust 87.3x faster  |
| build with includes/compression | 8.477 s   | 729.1 ms | Rust 11.6x faster  |
| build minify-only               | 114.049 s | 127.4 ms | Rust 895.4x faster |

The minify-only result is a single-run measurement after warming the old
`npx`-backed minifier cache.

## v1.3.1

- Make generated site licenses use the current year and a configurable holder.

## v1.0.0

- Add `litesite` to the `remutils` collection as a self-contained site
  scaffolding and build command.
