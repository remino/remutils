# remutils

Collection of utility scripts.

Rémino Rem <https://remino.net/>, 2026

<!-- mtoc-start -->

- [Installation & Usage](#installation--usage)
- [Development](#development)
    - [Git Hooks](#git-hooks)
    - [Tasks](#tasks)
    - [Release Scripts](#release-scripts)
- [Licence](#licence)

<!-- mtoc-end -->

## Installation & Usage

See `README.md` for the relevant subdirectory of the script you wish to install.

Most scripts can be installed via Homebrew, simply by cloning the repo,
downloading its tarball, or the script itself.

## Development

Every directory except `bin`, `lib`, and `tests` houses a script of its own,
along with documentation and a test suite. For example:

- `hello`
    - `CHANGELOG.md`
    - `hello`: executable script named the same than its parent directory.
    - `formula.rb.mustache`: Mustache template of the script's Homebrew formula.
    - `man/hello.1`
    - `README.md`
    - `tests/`: Bats test suite directory.

### Git Hooks

Install Git hooks with:

```sh
just hooks
```

The pre-commit hook formats staged shell files with `shfmt` and staged Markdown,
JSON, YAML, HTML, CSS, and JavaScript files with `prettier`.

### Tasks

Use `just` for common development tasks:

- `just list`
    - List tools managed by this repo.
- `just tests [name]`
    - Run all tests, or one tool's test suite when `name` is provided.
- `just format [name]`
    - Format the whole repo, or one tool when `name` is provided.
- `just lint [name]`
    - Check formatting for the whole repo, or one tool when `name` is provided.
- `just version [name]`
    - Show versions for all tools, or one tool when `name` is provided.
- `just release <name> <initial|major|minor|patch> [--github]`
    - Create a release commit and tag, optionally publishing to GitHub.
- `just clean`
    - Remove generated release tarballs and checksum files.

### Release Scripts

The `just` recipes call scripts in `bin` for lower-level release operations:

- `script-tests`
    - To run the test suite of a script.
- `version`
    - To update the version of a script.
- `version-commit`
    - To commit versioned changes of a script to its containing git repo.
- `release`
    - To create the initial commit/tag for a script or delegate later versioned
      releases to `version-commit`. Pass `--github` to also publish the GitHub
      release.
- `version-tarball`
    - To generate a tarball of a versioned release of a script.
- `version-release`
    - To publish a versioned release of a script to GitHub.
- `version-formula`
    - To generate a Homebrew formula in a given directory.

## Licence

See `LICENSE.txt`.
