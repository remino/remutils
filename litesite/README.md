# litesite

Create and work with tiny static sites that keep their source in `src/` and
publish to `dist/`.

Rémino Rem <https://remino.net/>, 2026

<!-- mtoc-start -->

- [Installation](#installation)
    - [Homebrew](#homebrew)
    - [Git clone](#git-clone)
- [Usage](#usage)
- [Development](#development)
- [Licence](#licence)

<!-- mtoc-end -->

## Installation

### Homebrew

```sh
brew install remino/remino/litesite
litesite
```

### Git clone

```sh
git clone git@github.com:remino/remutils.git
cd remutils/litesite
./litesite
```

## Usage

Run `man litesite` or `litesite --help` to see how to use it.

With no arguments, `litesite` prints the usage screen.

The command expects a site root with:

- `src/`
- `.deploy-filter`
- `justfile`
- `.editorconfig`

The site `.env` can disable build-time extras:

- `LITESITE_BUILD_BROTLI=0` skips Brotli output
- `LITESITE_BUILD_GZIP=0` skips gzip output
- `LITESITE_BUILD_AVIF_JPEG=0` skips JPG derivative generation
- `LITESITE_BUILD_AVIF_WEBP=0` skips WebP derivative generation

`rsdeploy` is required only for `litesite deploy`.

`litesite new <slug>` creates `./<slug>` by default. `init` remains available as
an alias.

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
