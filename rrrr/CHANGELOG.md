# CHANGELOG

<!-- mtoc-start -->

- [Unreleased](#unreleased)
- [v1.3.0](#v130)
- [v1.2.0](#v120)
- [v1.1.0](#v110)
- [v1.0.1](#v101)

<!-- mtoc-end -->

## Unreleased

- Add `backup`, `mount`, `unmount`, `help`, and `version` subcommands.
- Retain `rrrr <hostname>` as a compatibility alias for
  `rrrr backup <hostname>`.

## v1.3.0

- Add configurable rsync verbosity.
- Respect SSH configuration when no port override is set.
- Allow Linux-to-macOS backups to disable incompatible ACL preservation.
- Retain readable data from rsync exit-23 runs as partial snapshots.
- Always detach managed storage when incomplete snapshot cleanup fails.
- Allow expected rsync exit-23 runs to become the latest snapshot.

## v1.2.0

- Add a built-in APFS sparse bundle storage provider for macOS.
- Add `-v` as the documented version flag and retain `-V` as a compatibility
  alias.
- Use a writable temporary mountpoint by default for APFS sparse bundles.
- Keep SSH authentication prompts interactive and write rsync errors to the run
  log.

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
