# litesite

Create and work with tiny static sites that keep their source in `src/` and
publish to `dist/`.

Rémino Rem <https://remino.net/>, 2026

<!-- mtoc-start -->

- [Installation](#installation)
    - [Homebrew](#homebrew)
    - [Git clone](#git-clone)
- [Usage](#usage)
- ["What about this feature?"](#what-about-this-feature)
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
- `LITESITE_BUILD_ZSTD=0` skips zstd output
- `LITESITE_BUILD_INCLUDES=0` skips HTML file includes
- `LITESITE_BUILD_MINIFY=0` skips HTML/CSS/JS minification
- `LITESITE_BUILD_AVIF_JPEG=0` skips JPG derivative generation
- `LITESITE_BUILD_AVIF_WEBP=0` skips WebP derivative generation

HTML files can include other files with SSI-style directives:

```html
<!--#include file="relative/path/to/file" -->
```

The path is resolved relative to the file being processed. Relative paths,
absolute paths, and paths outside the site root are all accepted.

ImageMagick is required only for AVIF derivative generation. `rsdeploy` is
required only for `litesite deploy`.

`litesite new <slug>` creates `./<slug>` by default. `init` remains available as
an alias.

AVIF derivatives are written as sibling files:

- `*.avif.jpg`
- `*.avif.webp`

## "What about this feature?"

This is by no means a tool made to build a modern website with all the
tree-shaking, auto-prefixing, pre-rendering, etc.

It's meant to be a simple tool that lets you write your own HTML, CSS, and
JavaScript, and stay out of your way, with no hand holding.

What it does help you with is to run the site locally with live reload, so you
don't have to hit the Refresh button of your browser at every change, build the
files with minification unless you disable it, automatically add Gzip, Brotli,
and zstd derivates, as well as JPEG and WebP derivatives for AVIF image files,
if you use those. Then, with `rsdeploy`, it will help you deploy the site.

That's it.

## Development

```sh
bats tests
```

The package follows the same top-level convention as the other `remutils` tools,
with a Rust implementation behind the executable shim:

- `litesite`: executable shim
- `Cargo.toml`: Rust package metadata and version source
- `src/`: Rust implementation
- `man/litesite.1`: manual page
- `homebrew.rb.mustache`: Homebrew formula template
- `tests/`: Bats test suite

## Licence

See `LICENSE.txt`.
