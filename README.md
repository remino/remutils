# remutils

Collection of utility scripts.

Rémino Rem <https://remino.net/>, 2026

<!-- mtoc-start -->

- [Installation & Usage](#installation--usage)
- [Development](#development)
    - [Scripts](#scripts)
- [Licence](#licence)

<!-- mtoc-end -->

## Installation & Usage

See `README.md` for the relevant subdirectory of the script you wish to install.

Most scripts can be installed via Homebrew, simply by cloning the repo,
downloading its tarball, or the script itself.

## Development

Every directory except `bin` and `lib` houses a script of its own, along with
documentation and a test suite. For example:

- `hello`
    - `CHANGELOG.md`
    - `hello`: executable script named the same than its parent directory.
    - `formula.rb.mustache`: Mustache template of the script's Homebrew formula.
    - `README.md`
    - `tests/`: Bats test suite directory.

### Scripts

Use the following scripts in `bin` to help deploy updates, listed below in the
order of execution:

- `script-tests`
    - To run the test suite of a script.
- `version`
    - To update the version of a script.
- `version-commit`
    - To commit versioned changes of a script to its containing git repo.
- `version-tarball`
    - To generate a tarball of a versioned release of a script.
- `version-release`
    - To publish a versioned release of a script to GitHub.
- `version-formula`
    - To generate a Homebrew formula in a given directory.

## Licence

See `LICENSE.txt`.
