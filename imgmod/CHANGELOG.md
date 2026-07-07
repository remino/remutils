# CHANGELOG

<!-- mtoc-start -->

- [v1.3.0](#v130)
- [v1.1.0](#v110)
- [v1.0.0](#v100)

<!-- mtoc-end -->

## v1.3.0

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
