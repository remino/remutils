# rsdeploy

Deploy directory to remote server by using rsync.

Rémino Rem <https://remino.net/>, 2022

<!-- mtoc-start -->

- [Installation](#installation)
    - [Homebrew](#homebrew)
    - [Download](#download)
    - [Git clone](#git-clone)
- [Usage](#usage)

<!-- mtoc-end -->

## Installation

### Homebrew

```sh
brew install remino/remino/rsdeploy
./rsdeploy
```

### Download

Go to the
[GitHub download page](https://github.com/remino/remutils/releases/latest) for
the latest release, and download the source code from there.

### Git clone

```sh
git clone git@github.com:remino/remutils.git
cd remutils/rsdeploy
./rsdeploy
```

## Usage

You need to set the source directory, destination host and directory, as well as
an optional filter file.

See `.env.example` or `rsdeploy -h`.
