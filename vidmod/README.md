# vidmod

Video modification helpers.

Rémino Rem <https://remino.net/>, 2026

## Usage

Run `vidmod` without arguments to see how to use it.

Vidmod 2 exposes the old vidmod 1 changes as command plugins:

```sh
vidmod mp4 input.mov
vidmod fit1080 -o framed.mov input.mov
vidmod rotate90 -o rotated.mov input.mov
vidmod twitter -o twitter.mp4 input.mov
vidmod chain mp4 -- twitter -- input.mov twitter.mp4
```

Each normal command processes one input file. Use `chain` when you need multiple
changes in sequence.

The `169` and `43` commands crop the frame to the requested aspect ratio. They
do not stretch or squash the image.

## Commands

The bundled legacy command plugins are:

```text
169 43 60fps audio butter crop219 crossfade fit1080 hevc loop mono mp4 mute
qt reverse rotate90 rotate180 rotate270 slowdown twitter
```

Each legacy command accepts:

```text
-f  Extra ffmpeg options.
-h  Show help.
-o  Output video file.
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

## Chains

Run multiple plugins in sequence with `chain`. Separate each plugin stage with
`--`, then pass the input and final output after the last separator:

```sh
vidmod chain mp4 -- twitter -- input.mov twitter.mp4
vidmod chain 169 -f "-y" -- rotate90 -- input.mov rotated.mov
```

Chainable plugins must accept the standard plugin arguments:

```text
<command> [<options>] [-o <output>] <input>
```

The final output path is required for chains.
