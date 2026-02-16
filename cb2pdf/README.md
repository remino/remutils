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

Run `cb2pdf -h` to see how to use it.

Example:

```sh
cb2pdf issue-001.cbz
cb2pdf issue-001.cbr output.pdf
```

## Dependencies

- `7z` for archive extraction
- `img2pdf` for PDF generation
