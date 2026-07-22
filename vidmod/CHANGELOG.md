# Changelog

<!-- mtoc-start -->

- [Unreleased](#unreleased)
- [v3.0.0](#v300)
- [v2.4.1](#v241)
- [v2.4.0](#v240)
- [v2.2.0](#v220)
- [v2.0.0](#v200)

<!-- mtoc-end -->

## Unreleased

- Change `169` and `43` to crop video frames to `16:9` and `4:3` instead of only
  rewriting display aspect ratio metadata.
- Add top-level overwrite controls: prompt by default, `-y`/`--overwrite` to
  overwrite, `-i`/`--interactive` to always prompt, and `-N`/`--no-overwrite` to
  refuse overwrites.

## v3.0.0

- Change output-producing commands to use `-o <output>` for explicit output
  paths instead of positional output arguments.

## v2.4.1

- Fix the Homebrew formula template to install bundled manpages from `libexec`.
- Add manpages for every bundled plugin.

## v2.4.0

- Add `fit1080` command to fit video into a centered `1920x1080` black frame.

## v2.2.0

- Add `chain` command to run multiple plugins in sequence.

## v2.0.0

- Rewrite vidmod in the style of imgmod.
- Move old vidmod 1 changes into bundled command plugins.
- Add XDG plugin lookup, command completion data, and plugin scaffolding.
