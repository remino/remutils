# CHANGELOG

<!-- mtoc-start -->

- [Unreleased](#unreleased)
- [v3.0.2](#v302)
- [v3.0.1](#v301)
- [v3.0.0](#v300)

<!-- mtoc-end -->

## Unreleased

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
