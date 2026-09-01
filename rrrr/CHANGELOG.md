# CHANGELOG

<!-- mtoc-start -->

- [Unreleased](#unreleased)

<!-- mtoc-end -->

## Unreleased

- Write backups to a temporary snapshot and publish only after rsync succeeds,
  allowing failed runs to be retried on the same day.
- Validate runtime requirements before creating backup paths, with support for
  GNU and BSD date implementations.
- Reject hostnames that cannot safely name a configuration directory.
