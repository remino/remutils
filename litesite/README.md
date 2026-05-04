# litesite

Create and work with tiny static sites that keep their source in `src/` and
publish to `dist/`.

Rémino Rem <https://remino.net/>, 2026

<!-- mtoc-start -->

- [Installation & Usage](#installation--usage)
- [Development](#development)
- [Licence](#licence)

<!-- mtoc-end -->

## Installation & Usage

Install the `litesite` script from this directory, or clone `remutils` and run
it from the repo root.

The command expects a site root with:

- `src/`
- `.deploy-filter`
- `justfile`
- `.editorconfig`

See `man litesite` or `litesite --help` for the full command list.

With no arguments, `litesite` prints the usage screen.

The site `.env` can disable build-time extras:

- `LITESITE_BUILD_BROTLI=0` skips Brotli output
- `LITESITE_BUILD_GZIP=0` skips gzip output
- `LITESITE_BUILD_AVIF_JPEG=0` skips JPG derivative generation
- `LITESITE_BUILD_AVIF_WEBP=0` skips WebP derivative generation

`rsdeploy` is required only for `litesite deploy`.

`litesite new <slug>` creates `./<slug>` by default. `init` remains available
as an alias.

AVIF derivatives are written as sibling files:

- `*.avif.jpg`
- `*.avif.webp`

## Development

```sh
bats tests
```

The package follows the same convention as the other `remutils` scripts:

- `litesite`: executable script
- `man/litesite.1`: manual page
- `homebrew.rb.mustache`: Homebrew formula template
- `tests/`: Bats test suite

## Licence

See `LICENSE.txt`.
