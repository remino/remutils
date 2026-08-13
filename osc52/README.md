# osc52

Copy and paste through a terminal emulator that supports the OSC 52 clipboard
sequence.

2026 Rémino Rem <https://remino.net/>

<!-- mtoc-start -->

- [Installation](#installation)
- [Usage](#usage)

<!-- mtoc-end -->

## Installation

```sh
brew install remino/remino/osc52
```

Or run the scripts directly from a clone:

```sh
git clone git@github.com:remino/remutils.git
cd remutils/osc52
```

## Usage

Copy standard input or arguments:

```sh
printf 'Hello, clipboard!' | osc52copy
osc52copy 'Hello, clipboard!'
# equivalent: osc52 copy 'Hello, clipboard!'
```

Paste the terminal clipboard to standard output:

```sh
osc52paste
# equivalent: osc52 paste
```

Your terminal emulator must enable OSC 52 clipboard read and write access.
