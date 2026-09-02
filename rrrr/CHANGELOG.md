# CHANGELOG

<!-- mtoc-start -->

- [Unreleased](#unreleased)
- [v1.1.0](#v110)
- [v1.0.1](#v101)

<!-- mtoc-end -->

## Unreleased

- Add a built-in APFS sparse bundle storage provider for macOS.

## v1.1.0

- Add a built-in ext4 image storage provider for Linux and QNAP NAS systems.
- Support Bash 3 so rrrr can run on QNAP's bundled shell.
- Support passwordless elevation for image lifecycle operations on QNAP.

## v1.0.1

- Add a Homebrew formula template and document installation.
- Align the manpage header with rrrr's initial release version.
- Add optional mount and unmount hooks for image-backed or otherwise managed
  backup storage.
- Write backups to a temporary snapshot and publish only after rsync succeeds,
  allowing failed runs to be retried on the same day.
- Validate runtime requirements before creating backup paths, with support for
  GNU and BSD date implementations.
- Reject hostnames that cannot safely name a configuration directory.
