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

The default `astro-content` template is for projects with
`src/content/<project>`, `src/styles/<project>`, and `public/<project>`:

```sh
comprose new --template astro-content -p journal -s my-new-entry
comprose import --template astro-content -p notes /tmp/source-entry
```

The `middleman-blog` template is for single-file blog entries with assets beside
the entry:

```sh
comprose new --template middleman-blog --content-root source/posts -s my-entry
comprose import --template middleman-blog --content-root source/posts /tmp/source-entry
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

With the default `astro-content` template, this creates:

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
generated title, copies `style.css` when the selected template supports a
stylesheet, and rewrites referenced local image links into the asset folder.

Use `-f` to replace an existing generated entry:

```sh
comprose import -p journal /tmp/source-entry -f
```

## Options

- `--template <name-or-path>`: Template layout. Defaults to `astro-content`.
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

## Templates

Built-in templates:

- `astro-content`: Writes `src/content/<project>/<date>-<slug>/index.md`, a
  matching stylesheet, and assets under `public/<project>/<slug>/`.
- `middleman-blog`: Writes `<content-root>/<slug>.html.md` and assets under
  `<content-root>/<slug>/`. It does not create a stylesheet by default.

Custom template directories can be passed to `--template`. They must contain
`entry.md.mustache` and may contain `style.css.mustache`. A custom directory may
also include `layout.json` with `{ "layout": "middleman-blog" }`; otherwise it
uses the `astro-content` path layout.

## Dependencies

`comprose` uses Node.js, Mustache, and `sharp`. Image imports that keep
PNG/GIF/HEIC output also require ImageMagick. PNG and GIF outputs are passed
through `image_optim` when that command is available.
