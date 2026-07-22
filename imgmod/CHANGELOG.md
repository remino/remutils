# CHANGELOG

<!-- mtoc-start -->

- [Unreleased](#unreleased)
- [v2.0.0](#v200)
- [v1.4.1](#v141)
- [v1.4.0](#v140)
- [v1.1.0](#v110)
- [v1.0.0](#v100)

<!-- mtoc-end -->

## Unreleased

- Add top-level overwrite controls: prompt by default, `-y`/`--overwrite` to
  overwrite, `-i`/`--interactive` to always prompt, and `-N`/`--no-overwrite` to
  refuse overwrites.

## v2.0.0

- Add `collage` command to stitch multiple images together vertically or
  horizontally.
- Change output-producing commands to use `-o <output>` for explicit output
  paths instead of positional output arguments.
- Prefer top-level `-O`, `--optim`, and `--optimize` for output optimization.
  Keep top-level `-o` as a deprecated alias.

## v1.4.1

- Fix the Homebrew formula template to install bundled manpages from `libexec`.

## v1.4.0

- Add `png8` command to convert images to PNG8.
- Add `scale4x` command to scale images 4x without antialiasing or smoothing.
- Add `vidframe` command to extract a frame from a video, with first-frame,
  frame-number, and timestamp modes.

## v1.1.0

- Add `chain` command to run multiple plugins in sequence.
- Add `optim` command for direct image optimization.

## v1.0.0

- Add `imgmod` wrapper script.
- Add `socshare` command to crop and resize images to `1200x630` for social
  sharing.
- Add plugin lookup from XDG data directories.
- Add shared `imgmod` helper library for plugins.
- Add `newplugin` command and `-n` shortcut to create new plugins from a
  template.
- Move the default `newplugin` template to Mustache and support custom templates
  with `-t`.
- Add `-o` option to optimize plugin-declared image outputs with `image_optim`.
- Add `imgmod_output` plugin hook for declaring optimizable outputs.
- Add hook-based plugin runtime with plugin-prefixed hooks and
  `imgmod_plugin_run`.
- Add plugin-backed Bash, Zsh, and Fish shell completions.
- Add manpages for `imgmod` and bundled plugins.
- Add `-v` and `--version` handling for shared-runtime plugins.
