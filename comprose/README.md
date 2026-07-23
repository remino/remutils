# comprose

Create and import prose content entries.

`comprose` creates Markdown entries for prose-oriented static sites. It can use
built-in or custom Mustache templates to support different site layouts.

## Install

```sh
npm install -g @remino/comprose
```

## Usage

```sh
comprose help
comprose new [options] -s <slug>
comprose import [options] <path>
```

The default `default` template is for projects with `src/content/<collection>`,
`src/styles/<collection>`, and `public/<collection>`:

```sh
comprose new --template default -c journal -s my-new-entry
comprose import --template default -c notes /tmp/source-entry
```

The `middleman-blog` template is for single-file blog entries with assets beside
the entry:

```sh
comprose new --template middleman-blog -c posts -s my-entry
comprose import --template middleman-blog -c posts /tmp/source-entry
```

If `-c` is omitted, the current directory name is used as the collection. If
`--pubname` is omitted, `comprose` tries to derive it from a reverse-DNS package
name such as `com.example.journal`, producing `example-journal`.

## Commands

### `new`

Create a new entry scaffold:

```sh
comprose new -c journal -t "My New Entry" -d 2026-05-06 -g terminal -g css
```

With the default `default` template, this creates:

- `src/content/<collection>/<date>-<slug>/index.md`
- `src/styles/<collection>/<slug>.css`
- `public/<collection>/<slug>/`

Piped standard input seeds the Markdown body:

```sh
printf 'Draft body.\n' | comprose new -c journal -s draft-entry
```

### `import`

Import a directory containing a Markdown file:

```sh
comprose import -c journal /tmp/source-entry
```

The import command looks first for `entry.md`, `post.md`, `note.md`, or
`article.md`, then falls back to the first Markdown file. It preserves selected
frontmatter fields, removes the first Markdown heading when it becomes the
generated title, copies `style.css` when the selected template supports a
stylesheet, and rewrites referenced local image links into the asset folder.

Use `-f` to replace an existing generated entry:

```sh
comprose import -c journal /tmp/source-entry -f
```

## Options

- `--template <name-or-path>`: Template layout. Defaults to `default`.
- `-s <slug>`: Entry slug.
- `-t <title>`: Entry title.
- `-d <iso-8601>`: Entry date.
- `-k`, `--type`, `--kind <kind>`: `article` or `note`.
- `-g <tag>`: Add a tag. Repeatable.
- `-i <path>`: Copy an image into the entry asset directory. Repeatable.
- `-e`: Open generated text files in `$EDITOR`.
- `-o`: Open the public folder in Finder.
- `-f`: Replace an existing imported entry.
- `-c`, `--collection <name>`: Content collection name.
- `--pubname <name>`: Frontmatter `pubname`.

## Templates

Built-in templates:

- `default`: Writes `src/content/<collection>/<date>-<slug>/index.md`, a
  matching stylesheet, and assets under `public/<collection>/<slug>/`.
- `astro-content`: Writes `src/content/<collection>/<date>-<slug>/index.md`, a
  matching stylesheet, and assets under `public/<collection>/<slug>/`.
- `middleman-blog`: Writes `source/<collection>/<slug>.html.md` and assets under
  `source/<collection>/<slug>/`. It does not create a stylesheet by default.

Template directories define output paths directly. Directory and file names can
include path variables such as `[collection]`, `[date]`, and `[slug]`. Files
ending in `.mustache` are rendered and written without the `.mustache` suffix.
Place a `.comprose-assets` marker file in the directory where copied images
should be written.

Template names are resolved in this order:

1. Built-in templates bundled with `comprose`.
2. `.comprose/templates/<name>` in the current directory or any parent
   directory.
3. `.config/comprose/templates/<name>` in the current directory or any parent
   directory.
4. `$XDG_CONFIG_HOME/comprose/templates/<name>`, or
   `$HOME/.config/comprose/templates/<name>` when `XDG_CONFIG_HOME` is unset.
5. A relative or absolute directory path passed to `--template`.

For example:

```text
templates/example/
  source/[collection]/
    [slug].html.md.mustache
    [slug]/
      .comprose-assets
```

## Dependencies

`comprose` uses Node.js, Mustache, and `sharp`. Image imports that keep
PNG/GIF/HEIC output also require ImageMagick. PNG and GIF outputs are passed
through `image_optim` when that command is available.

## Maintainer docs

The published docs site is generated into a separate `docs/` worktree checked
out at the repo root on the orphan `docs` branch.

The published layout is:

- `docs/comprose/index.html`: README landing page
- `docs/comprose/docs/`: generated JSDoc API site
- `docs/.nojekyll`: GitHub Pages Jekyll bypass marker

Build and publish docs with:

```sh
npm run docs:publish --prefix comprose
```

The docs scripts expect `../docs` from the `comprose/` directory to already be a
Git worktree on the `docs` branch. If that worktree is missing or on another
branch, the build fails with a descriptive error.
