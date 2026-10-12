# prj

Create and manage dated project directories from optional templates.

- <https://remino.net/prj/>
- [Source code](https://github.com/remino/remutils/tree/main/prj)

2026 Rémino Rem <https://remino.net/>

---

<!-- mtoc-start -->

- [Installation](#installation)
- [Usage](#usage)
- [Project roots](#project-roots)
- [Project templates](#project-templates)

<!-- mtoc-end -->

## Installation

```sh
brew install remino/remino/prj
```

The formula installs `prj` and the deprecated `mkprj` compatibility command.

## Usage

Run `prj help` or `prj -h` for complete usage information.

```sh
prj new notes
prj mk notes
prj make notes
prj ls
prj t
prj d
prj i
```

`prj new notes` creates `YYYYMMDD notes` in the default project root. The
deprecated `mkprj notes` remains equivalent to `prj new notes` and emits a
warning.

Short aliases are `n` for `new`, `ls`/`l` for `list`, `t` for `templates`, `d`
for `doctor`, `i` for `info`, `v` for `version`, and `h` for `help`.

Use `prj help <command>` as an alternative to `<command> -h`, for example
`prj help list`.

## Project roots

A project root is a directory containing project directories. Set
`PRJ_PROJECTS_DIR` for the creation default and `PRJ_PROJECTS_DIRS` to a
colon-separated list of roots. When the singular value is unset, `new` uses the
first plural value. `list` combines both values, preserves root order, and
prints each immediate child directory as an absolute path.

`PROJECTS_DIR` and `PROJECTS_DIRS` are deprecated compatibility names and emit a
warning when used.

## Project templates

`prj` resolves named templates from bundled templates, `PRJ_TEMPLATES_DIR`,
ancestor `.prj/templates/` and `.config/prj/templates/` directories, then an
explicit path passed to `--template`. `PRJ_TEMPLATE_DIR` overrides the bundled
template parent. `prj templates` prints the effective named templates.

Files ending in `.mustache` are rendered without that suffix. Paths can use
bracket variables such as `[slug]`; Mustache content uses `{{slug}}`. Templates
receive `project_dir`, `project_name`, `project_date`, `projects_dir`, `name`,
`date`, `year`, and `slug`.

Use `.prj/setup` for an executable setup script and `.prj.json` for template
metadata. The old `mkprj` paths and `MKPRJ_TEMPLATE_DIR`/`TEMPLATES_DIR`
variables remain supported with a warning.
