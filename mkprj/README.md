# mkprj

Create dated project directories from optional templates.

2026 Rémino Rem <https://remino.net/>

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
brew install remino/remino/mkprj
```

### Download

Download the latest source archive from the
[GitHub releases page](https://github.com/remino/remutils/releases/latest).

### Git clone

```sh
git clone git@github.com:remino/remutils.git
cd remutils/mkprj
./mkprj -h
```

## Usage

Run `man mkprj` or `mkprj -h` for complete usage information.

By default, `mkprj notes` creates `YYYYMMDD notes` in the current directory. Set
`PROJECTS_DIR` to choose a different parent directory.

### Project templates

`mkprj` uses a Mustache template tree, following the same conventions as
`litesite` and `comprose`:

```sh
mkprj --template research --var client=Acme notes
mkprj -t ./templates/research --var client=Acme notes
```

Template names resolve from the bundled templates (or `MKPRJ_TEMPLATE_DIR`),
then `.mkprj/templates/` and `.config/mkprj/templates/` in the current directory
or a parent, then the XDG config template directory, and finally a directory
path passed with `--template`.

Files ending in `.mustache` are rendered and written without that suffix. Paths
can use bracket variables such as `[slug]` and `[client]`; Mustache content uses
`{{slug}}` and `{{client}}`. Every template receives `project_dir`,
`project_name`, `project_date`, `projects_dir`, `name`, `date`, `year`, and
`slug`. Extra variables come from repeatable `--var key=value` options. The
built-in values are reserved.
