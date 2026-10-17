# CHANGELOG

<!-- mtoc-start -->

- [Unreleased](#unreleased)
- [v4.0.1](#v401)
- [v4.0.0](#v400)
- [v3.0.4](#v304)
- [v3.0.3](#v303)
- [v3.0.2](#v302)
- [v3.0.1](#v301)
- [v3.0.0](#v300)

<!-- mtoc-end -->

## Unreleased

- Restore compatibility with macOS system Bash 3.2, including SSH and Shortcuts
  invocations.
- Make `list` skip missing project roots silently; use `doctor` for diagnostics.
- Resolve bundled templates from both Homebrew and Makefile installation
  layouts.
- Align the Homebrew formula with the canonical `libexec/prj` layout.

## v4.0.1

- Use canonical `PRJ_*` variables internally and expose them to template setup
  scripts; retain legacy setup variables only for compatibility.

## v4.0.0

- Rename `mkprj` to `prj` and retain `mkprj` as a deprecated compatibility
  command.
- Add `new`, `mk`, `make`, `list`, `templates`, `doctor`, `version`, and `help`
  commands.
- Add canonical `PRJ_*` configuration and deprecated compatibility warnings for
  previous `mkprj` paths and environment variables.

## v3.0.4

- Fix setup scripts for projects created from relative paths.
- Add `make install` and `make uninstall` targets.

## v3.0.3

- Render Mustache template files whose paths contain spaces.

## v3.0.2

- Resolve the executable path before locating bundled templates, so Homebrew's
  `bin/mkprj` symlink works correctly.

## v3.0.1

- Fix Homebrew installations locating bundled project templates.

## v3.0.0

- Move `mkprj` from its standalone repository to this `remutils` monorepo.
- Refactor the command for the shared release, documentation, and test
  conventions.
- Reject invalid calendar dates and missing project names.
