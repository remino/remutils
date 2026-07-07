# vidmod

Video modification helpers.

Rémino Rem <https://remino.net/>, 2026

## Usage

Run `vidmod` without arguments to see how to use it.

Vidmod 2 exposes the old vidmod 1 changes as command plugins:

```sh
vidmod mp4 input.mov
vidmod rotate90 input.mov rotated.mov
vidmod twitter input.mov twitter.mp4
```

Each command processes one input file. Vidmod 1 command chaining is
intentionally not part of vidmod 2; run multiple `vidmod` commands when you need
multiple changes.

## Commands

The bundled legacy command plugins are:

```text
169 43 60fps audio butter crop219 crossfade hevc loop mono mp4 mute qt reverse
rotate90 rotate180 rotate270 slowdown twitter
```

Each legacy command accepts:

```text
-f  Extra ffmpeg options.
-h  Show help.
-v  Show command version.
```

## Plugins

`vidmod` commands are executable plugin files named `vidmod-<command>`. Local
plugins can be installed under XDG data directories:

```sh
~/.local/share/vidmod/plugins/vidmod-example
```

Create a starter plugin:

```sh
vidmod newplugin example
```

Completion data is available through the bundled completion plugin:

```sh
vidmod completion bash
vidmod completion zsh
vidmod completion fish
```
