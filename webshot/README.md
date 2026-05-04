# webshot

Capture a webpage as an image.

Rémino Rem <https://remino.net/>, 2026

<!-- mtoc-start -->

- [Installation](#installation)
  - [Homebrew](#homebrew)
  - [Download](#download)
  - [Git clone](#git-clone)
- [Usage](#usage)
- [Options](#options)
- [Development](#development)
- [Dependencies](#dependencies)

<!-- mtoc-end -->

## Installation

### npm

```sh
npm install -g @remino/webshot
webshot
```

### Homebrew

```sh
brew install remino/remino/webshot
webshot
```

### Download

Go to the
[GitHub download page](https://github.com/remino/remutils/releases/latest) for
the latest release, and download the source code from there.

### Git clone

```sh
git clone git@github.com:remino/remutils.git
cd remutils/webshot
npm install
./webshot
```

## Usage

Run `man webshot`, `webshot -h`, or `webshot -v` to see how to use it.

Example:

```sh
webshot https://example.com
webshot https://example.com share.png
webshot -W 1200 -H 630 -w 0.5 https://example.com og.webp
webshot -z 1.25 -d 192 https://example.com og@2x.png
webshot -c ./share.css -j ./prepare.js https://example.com card.jpg
webshot -f jpeg https://example.com share-image
```

With no arguments, `webshot` exits successfully and prints the usage screen.
If the output file is omitted, `webshot` writes a file based on the URL.
The default extension is `.png`, unless `-f` sets another format.
If the URL has no protocol, `http://` is assumed.

The output image format is inferred from the file extension. Supported formats
are PNG, JPEG, AVIF, and WebP. The `.jpg` extension maps to JPEG.

`-d 96` maps to a device scale factor of `1`. For example, `-d 192` captures at
2x pixel density while keeping the CSS viewport size unchanged.

## Options

```text
-h             Show the usage screen
-v             Show the version
-W <pixels>    Viewport width, default 1200
-H <pixels>    Viewport height, default 630
-w <seconds>   Seconds to wait after page load before capture, default 0
-z <factor>    Page zoom factor, default 1
-d <dpi>       Screenshot density in DPI, default 96
-f <format>    Override image format: png, jpeg, avif, webp
-c <css-file>  CSS file to embed before capture
-j <js-file>   JavaScript file to run before capture
```

## Development

Run the package tests from the `webshot` directory:

```sh
npm test
npm run lint
npm run format:check
```

The CLI wrapper is [`webshot`](webshot), which runs
[`bin/webshot.js`](bin/webshot.js).

## Dependencies

- Node.js 20 or later
- Puppeteer for browser automation
- sharp for AVIF output
