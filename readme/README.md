# readme

Open the nearest README file.

- <https://remino.net/readme/>
- [Source code](https://github.com/remino/remutils/tree/main/readme)

2026 Rémino Rem <https://remino.net/>

---

<!-- mtoc-start -->

- [Installation](#installation)
- [Usage](#usage)

<!-- mtoc-end -->

## Installation

```sh
brew install remino/remino/readme
```

Or run the script directly from a clone:

```sh
git clone git@github.com:remino/remutils.git
cd remutils/readme
./readme
```

## Usage

Run `readme` to open the README in the current directory. If none exists, it
opens the first README found in an immediate child directory. `glow` is used
when available; otherwise, the README opens in `less`.

Use `-l` to list all matching README files in that order:

```sh
readme -l
```

Pass a filename or pattern to restrict the search:

```sh
readme README.md
readme -l 'README.*'
```

Run `readme -h` or `man readme` for the full reference.
