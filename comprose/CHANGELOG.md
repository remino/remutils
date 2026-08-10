# Changelog

## Unreleased

- Simplify template context by removing the `has*` presence flags; custom
  templates should use their corresponding value directly as a Mustache section.

## v0.2.0

- Prefer project-local and user template directories over bundled templates.
- Add a generated GitHub Pages docs flow with a README landing page and JSDoc
  API output published through a dedicated `docs` worktree.
- Add a local `dress.css`-powered JSDoc theme for the published API site.

## v0.1.0

- Initial release.
