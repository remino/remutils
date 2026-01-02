# liverename

Watches a file with `watchexec` and renames it with a timestamp when it is
created.

Rémino Rem <https://remino.net/>, 2026

<!-- mtoc-start -->

- [Installation](#installation)
  - [Homebrew](#homebrew)
  - [Download](#download)
  - [Git clone](#git-clone)
- [Usage](#usage)
- [Known Issues](#known-issues)

<!-- mtoc-end -->

## Installation

### Homebrew

```sh
brew install remino/remino/liverename
./liverename
```

### Download

Go to the
[GitHub download page](https://github.com/remino/remutils/releases/latest) for
the latest release, and download the source code from there.

### Git clone

```sh
git clone git@github.com:remino/remutils.git
cd remutils/liverename
./liverename
```

## Usage

Run `liverename` without arguments to see how to use it.

## Known Issues

- The script does not work on file names starting with a hyphen (`-`).
- There are no proper tests for this script as it is complex to implement with
  `watchexec`.
