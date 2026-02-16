# cb2pdf

Convert `.cbz` and `.cbr` comic book archives into PDF files.

Rémino Rem <https://remino.net/>, 2026

<!-- mtoc-start -->

- [Installation](#installation)
    - [Homebrew](#homebrew)
    - [Download](#download)
    - [Git clone](#git-clone)
- [Usage](#usage)
- [Dependencies](#dependencies)

<!-- mtoc-end -->

## Installation

### Homebrew

```sh
brew install remino/remino/cb2pdf
./cb2pdf
```

### Download

Go to the
[GitHub download page](https://github.com/remino/remutils/releases/latest) for
the latest release, and download the source code from there.

### Git clone

```sh
git clone git@github.com:remino/remutils.git
cd remutils/cb2pdf
./cb2pdf
```

## Usage

Run `man cb2pdf` or `cb2pdf -h` to see how to use it.

Example:

```sh
cb2pdf issue-001.cbz
cb2pdf issue-001.cbr output.pdf
cb2pdf -d 300 issue-001.cbz output.pdf
cb2pdf -e 'extras/*' issue-001.cbz output.pdf
cb2pdf -E issue-001.cbz output.pdf
```

`cb2pdf` defaults to `300` DPI when laying out pages (`CB2PDF_DPI` env var can
override this default). This avoids inconsistent embedded image DPI metadata
causing spread pages to be shrunk.

By default, `cb2pdf` excludes hidden paths, AppleDouble files (`._*`),
`.DS_Store`, `Thumbs.db`, and `__MACOSX` paths from extracted images. You can
add more excludes with `-e/--exclude` (repeatable), or disable defaults with
`-E`.

## Dependencies

- `7z` for `.cbz` extraction
- For `.cbr`: `7z`, `unrar`, or `unar` (`cb2pdf` falls back to `unrar`/`unar` if
  needed)
- `img2pdf` for PDF generation
