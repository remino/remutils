# timinal

Render the current time with any installed FIGlet font.

2026 Rémino Rem <https://remino.net/>

<!-- mtoc-start -->

- [Installation](#installation)
- [Usage](#usage)

<!-- mtoc-end -->

## Installation

```sh
brew install remino/remino/timinal
```

Or run it directly from a clone:

```sh
git clone git@github.com:remino/remutils.git
remutils/timinal/timinal --font standard
```

`timinal` requires Python 3 and [FIGlet](http://www.figlet.org/).

## Usage

Without `--font`, `timinal` uses FIGlet's default font. When supplied, the value
is passed directly to FIGlet's `-f` option; it may be any font name that FIGlet
can load or a path to an `.flf` file:

```sh
timinal
timinal --font standard
timinal --font /path/to/termino-tabular.flf
timinal --font-dir /path/to/figlet-fonts -f termino-tabular
```

`-F` / `--format` accepts Python `strftime` directives. Use the literal `\r`
escape to start a new FIGlet block; it is not printed. The default format is
`%Y-%m-%d\r%H:%M:%S`.

```sh
timinal --font standard -F '%H:%M\r%a, %d %b %Y'
timinal --live --font /path/to/termino-mono.flf --format '%H:%M:%S'
timinal --live --font standard --format '%I:%M %p\r%d/%m/%Y' --uppercase
```

The default alignment is left; use `-l`, `-c`, or `-r` to select left, center,
or right alignment. In live mode, press Q or Escape to quit. See `man timinal`
for all options, configuration, controls, and exit statuses.
