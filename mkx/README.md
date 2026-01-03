# mkx

Make new executable shell script file from template.

Rémino Rem <https://remino.net/>, 2022

<!-- mtoc-start -->

- [Installation](#installation)
    - [Homebrew](#homebrew)
    - [Download](#download)
    - [Git clone](#git-clone)
- [Usage](#usage)
- [Formerly _mksh_](#formerly-_mksh)

<!-- mtoc-end -->

## Installation

### Homebrew

```sh
brew install remino/remino/mkx
./mkx
```

### Download

Go to the
[GitHub download page](https://github.com/remino/remutils/releases/latest) for
the latest release, and download the source code from there.

### Git clone

```sh
git clone git@github.com:remino/remutils.git
cd remutils/mkx
./mkx
```

## Usage

Run `man mkx` or `mkx -h` to see how to use it.

## Formerly _mksh_

As the name _mksh_ is more commonly associated with the
[MirBSD Korn Shell](https://www.mirbsd.org/mksh.htm), this repo has been renamed
from _mksh_ to _mkx_. The same goes for the namesake script within.

Invoking `mksh` with `mkx` used to be the equivalent of `mksh -b` or
`mksh -i <interpreter>`. But the with this name change, `mkx` was now made to
work like `mksh`.
