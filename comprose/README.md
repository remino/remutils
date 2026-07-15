# comprose

Create and import prose content entries.

`comprose` is a generalized version of the `entry` scripts used by blog-style
Astro projects. It creates dated Markdown entry folders, matching CSS files,
public asset directories, and frontmatter fields commonly used by prose sites.

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

For projects with `src/content/<project>`, `src/styles/<project>`, and
`public/<project>`, pass the section name with `-p`:

```sh
comprose new -p journal --pubname example-journal -s my-new-entry
comprose import -p notes --pubname field-notes /tmp/source-entry
```

If `-p` is omitted, the current directory name is used. If `--pubname` is
omitted, `comprose` tries to derive it from a reverse-DNS package name such as
`com.example.journal`, producing `example-journal`.

## Commands

### `new`

Create a new entry scaffold:

```sh
comprose new -p journal -t "My New Entry" -d 2026-05-06 -g terminal -g css
```

This creates:

- `src/content/<project>/<date>-<slug>/index.md`
- `src/styles/<project>/<slug>.css`
- `public/<project>/<slug>/`

Piped standard input seeds the Markdown body:

```sh
printf 'Draft body.\n' | comprose new -p journal -s draft-entry
```

### `import`

Import a directory containing a Markdown file:

```sh
comprose import -p journal /tmp/source-entry
```

The import command looks first for `entry.md`, `post.md`, `note.md`, or
`article.md`, then falls back to the first Markdown file. It preserves selected
frontmatter fields, removes the first Markdown heading when it becomes the
generated title, copies `style.css` when present, and rewrites referenced local
image links into the public asset folder.

Use `-f` to replace an existing generated entry:

```sh
comprose import -p journal /tmp/source-entry -f
```

## Options

- `-s <slug>`: Entry slug.
- `-t <title>`: Entry title.
- `-d <iso-8601>`: Entry date.
- `-k`, `--type`, `--kind <kind>`: `article` or `note`.
- `-g <tag>`: Add a tag. Repeatable.
- `-i <path>`: Copy an image into the public folder. Repeatable.
- `-e`: Open generated text files in `$EDITOR`.
- `-o`: Open the public folder in Finder.
- `-f`: Replace an existing imported entry.
- `-p`, `--project <name>`: Project section name.
- `--pubname <name>`: Frontmatter `pubname`.
- `--content-root <path>`: Override content root.
- `--styles-root <path>`: Override styles root.
- `--public-root <path>`: Override public root.
- `--images-root <path>`: Alias for `--public-root`.
- `--public-prefix <path>`: Override public URL prefix.
- `--images-prefix <path>`: Alias for `--public-prefix`.
- `--style-prefix <path>`: Override style frontmatter prefix.

## Dependencies

`comprose` uses Node.js and `sharp`. Image imports that keep PNG/GIF/HEIC output
also require ImageMagick. PNG and GIF outputs are passed through `image_optim`
when that command is available.
