# genrand

Generate cryptographically random strings.

2026 Rémino Rem <https://remino.net/>

<!-- mtoc-start -->

- [Installation](#installation)
- [Usage](#usage)

<!-- mtoc-end -->

## Installation

```sh
brew install remino/remino/genrand
```

Or run the script directly from a clone:

```sh
git clone git@github.com:remino/remutils.git
cd remutils/genrand
./genrand
```

## Usage

Generate a 32-character alphanumeric string (the default):

```sh
genrand
```

Set a length and character set:

```sh
genrand 16 lower
genrand 8 numbers
genrand 64 mixed
```

Available character sets are `alphanum`, `lower`, `mixed`, and `numbers`. Run
`genrand -h` or `man genrand` for the full reference.
