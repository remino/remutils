# Agent Notes

This repo is a collection of independently released command-line tools. Each
tool lives in a top-level directory named after its executable, for example
`mkx/mkx`, `imgmod/imgmod`, or `webshot/webshot`.

## Tool Layout

Most tool directories contain:

- `<name>`: executable entrypoint. Shell tools keep `VERSION` here.
- `package.json`: version source for Node-backed tools such as `webshot`.
- `CHANGELOG.md`: release notes for that tool only.
- `man/*.1`: manpages for the tool and bundled subcommands/plugins.
- `README.md`: user-facing documentation.
- `homebrew.rb.mustache`: Homebrew formula template.
- `tests/`: Bats tests for that tool.

Shared release scripts live in `bin/`. Shared libraries live in `lib/`.

## Version Sources

Use `bin/version show <tool>/<tool>` to read the current version. Do not infer a
tool version from README examples, manpages, tags, or changelog headings.

For shell tools, the executable's first `VERSION=` assignment is canonical. For
Node-backed tools, `<tool>/package.json` is canonical, even when the executable
is a shell wrapper.

## Release Update Checklist

Use `bin/version <major|minor|patch> <tool>/<tool>` to perform a version bump.
It updates the canonical version source and release-adjacent files in the same
tool directory:

- `CHANGELOG.md`: if the top work-in-progress section is named `HEAD` or
  `Unreleased`, it is promoted to `vX.Y.Z`, including its mtoc entry when one is
  present.
- `man/*.1`: existing `.TH` source/version strings for the tool are updated to
  the new version.
- `package.json`: updated for Node-backed tools.

When preparing release notes, put unreleased items under `## HEAD` or
`## Unreleased` before running the bump script. If there are no unreleased
items, add the new changelog section manually or confirm that no changelog entry
is needed.

Use `bin/version-commit <tool> <major|minor|patch>` only from a clean worktree.
It bumps versions, updates `package-lock.json` when present, commits the changed
tool directory, and creates the `<tool>@<version>` annotated tag.

Use `bin/release <tool> <initial|major|minor|patch> [--github]` for the higher
level release flow. With `--github`, it pushes tags and calls
`bin/version-release`.

## Verification

Format modified files before finishing work. Use `prettier` for Markdown, JSON,
YAML, HTML, CSS, and JavaScript files, and `shfmt` for shell scripts and Bats
tests. Prefer the repo wrappers when possible:

```sh
just format <tool>
just lint <tool>
```

For a single tool, run:

```sh
bin/script-tests <tool>
```

For the full repo, run:

```sh
just tests-all
```

Run `just lint` when changing shell, Markdown, JSON, or formatting-sensitive
files. If you update generated Homebrew output outside this repo, use
`bin/version-formula <tool> <formula_dir>` after the tag exists.

Git hooks are managed with `lefthook`. Use `lefthook install` to enable the
tracked hooks and `lefthook run pre-commit` to run staged formatting manually.
Do not add Husky, lint-staged, or a root `package.json` for hook management.

## Agent Rules

- Keep changes scoped to the requested tool unless the user asks for a shared
  release/script change.
- When adding or changing user-facing behavior, update that tool's
  `CHANGELOG.md` with an `## Unreleased` section at the top. Add the matching
  mtoc entry, `- [Unreleased](#unreleased)`, when the changelog has an mtoc
  block.
- Do not manually edit release tags or tarballs. Use the scripts in `bin/`.
- Before a release commit, make sure `git status --short` is clean unless the
  current task is specifically to prepare uncommitted changes.
- Preserve existing changelog style. This repo uses `## vX.Y.Z` headings and
  mtoc entries such as `- [v1.2.3](#v123)`.
