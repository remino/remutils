# urlshortcut

Read and write Internet Shortcut (`.url`) files.

2026 Rémino Rem <https://remino.net/>

<!-- mtoc-start -->

- [Installation](#installation)
- [Usage](#usage)

<!-- mtoc-end -->

## Installation

```sh
brew install remino/remino/urlshortcut
```

Or run the script directly from a clone:

```sh
git clone git@github.com:remino/remutils.git
cd remutils/urlshortcut
./urlshortcut -h
```

## Usage

Write a shortcut file:

```sh
urlshortcut write https://remino.net remino.url
```

The scheme is optional and defaults to `https`:

```sh
urlshortcut write remino.net
```

Read a URL from a shortcut file:

```sh
urlshortcut read remino.url
```

When no file is supplied, `read` consumes standard input, so this round trip
also works:

```sh
urlshortcut write remino.net | urlshortcut read
```
