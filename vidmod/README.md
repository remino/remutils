# vidmod

Video modification helpers.

2026 Rémino Rem <https://remino.net/>

## Usage

Run `vidmod` without arguments to see how to use it.

Vidmod 2 exposes the old vidmod 1 changes as command plugins:

```sh
vidmod mp4 input.mov
vidmod fit1080 -o framed.mov input.mov
vidmod rotate90 -o rotated.mov input.mov
vidmod twitter -o twitter.mp4 input.mov
vidmod stitch -o combined.mp4 clip-01.mp4 clip-02.mp4 clip-03.mp4
vidmod chain mp4 -- twitter -- input.mov twitter.mp4
```

Most commands process one input file. Use `stitch` to concatenate multiple
videos without re-encoding, or `chain` when you need multiple changes in
sequence.

`stitch` uses ffmpeg's concat demuxer and requires every input to have
compatible stream layouts and encoding parameters, including codecs, video
dimensions, frame rates, time bases, and audio properties. It does not normalize
or re-encode incompatible inputs, so ffmpeg may reject them or the result may
have timestamp or playback problems. An explicit `-o <output>` is required. In a
`chain`, the generated input is appended after any explicit `stitch` inputs.

The `169` and `43` commands crop the frame to the requested aspect ratio. They
do not stretch or squash the image.

When an output path already exists, `vidmod` prompts before overwriting it on a
TTY. Use `-y` or `--overwrite` before the command to overwrite without
prompting, `-i` or `--interactive` to always prompt, or `-N` or `--no-overwrite`
to refuse overwrites.

## Commands

The bundled legacy command plugins are:

```text
169 43 60fps audio butter crop219 crossfade fit1080 hevc loop mono mp4 mute
qt reverse rotate90 rotate180 rotate270 slowdown stitch twitter
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
