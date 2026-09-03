# rrrr

Create snapshot-style rsync backups over SSH.

⚠️ **Experimental**: Use at your own risk.

2026 Rémino Rem <https://remino.net/>

<!-- mtoc-start -->

- [Installation](#installation)
- [Configuration](#configuration)
    - [Host directory layout](#host-directory-layout)
        - [`config`](#config)
    - [Storage hooks](#storage-hooks)
    - [Built-in APFS sparse bundle storage](#built-in-apfs-sparse-bundle-storage)
    - [Built-in ext4 image storage](#built-in-ext4-image-storage)
    - [`filters` (optional)](#filters-optional)
- [Usage](#usage)

<!-- mtoc-end -->

## Installation

```sh
brew install remino/remino/rrrr
```

Or run the script directly from a clone:

```sh
git clone git@github.com:remino/remutils.git
cd remutils/rrrr
./rrrr -h
```

## Configuration

`rrrr` requires Bash 3 or newer, `rsync`, and OpenSSH. It is configured per
host, so the same runner can back up multiple servers. `rrrr backup <hostname>`
looks for host-specific configuration in this order:

1. `$XDG_CONFIG_HOME/rrrr/<hostname>`
2. Each directory in `$XDG_CONFIG_DIRS` (default: `/etc/xdg`), under
   `rrrr/<hostname>`
3. `/etc/rrrr/<hostname>`

The first directory found wins.

### Host directory layout

Each host directory must contain at least a `config` file:

```
~/.config/rrrr/webhost/
├── config
└── filters     # optional (overrides builtin defaults)
```

#### `config`

The file is `source`d by the script, so set shell variables there. The following
variables are required:

- `REMOTE_USER` – SSH user to connect as.
- `SSH_KEY` – private key on the backup host.

Set `BACKUP_ROOT` to the local directory that stores snapshots when not using a
storage provider or optional mount hook.

Common optional variables:

- `HOSTNAME_REMOTE` – label used for logging.
- `REMOTE_SSH_HOST` – actual hostname/IP (defaults to the `<hostname>`
  argument).
- `REMOTE_SSH_PORT` – optional SSH port override; when unset, SSH configuration
  (or SSH's own default) selects the port.
- `REMOTE_ROOT` – remote path to sync (defaults to `/`).
- `RSYNC_VERBOSE` – rsync output level: `0` (default), `1` (`-v`), `2` (`-vv`),
  or `3` (`-vvv`).
- `RSYNC_PRESERVE_ACLS` – preserve ACLs with `-A` (`1`, default) or disable it
  (`0`) when source and destination ACL formats are incompatible.
- `RSYNC_KEEP_PARTIAL` – retain rsync exit-23 results under `partials/` (`1`)
  instead of deleting the temporary snapshot (`0`, default).
- `RSYNC_ACCEPT_PARTIAL` – publish rsync exit-23 results as the current snapshot
  and update `latest` (`1`); disabled by default.
- `KEEP_DAILY`, `KEEP_WEEKLY`, `KEEP_MONTHLY` – retention counts.
- `FILTERS_FILE` – alternate path to an rsync filter file (if not using the
  host-local `filters` file).
- `SNAPS_DIR`, `LOG_DIR`, `LATEST_LINK` – override default paths inside
  `BACKUP_ROOT`.

### Storage hooks

By default, `rrrr` writes directly to `BACKUP_ROOT`. For image files, encrypted
volumes, datasets, or network storage, the sourced config may define both of
these functions:

- `rrrr_storage_mount` – mount or prepare the storage and set `BACKUP_ROOT` to
  its existing writable directory.
- `rrrr_storage_unmount` – detach or release that storage.

`rrrr` calls the mount hook before preparing backup paths and always calls the
unmount hook when it exits, including after an rsync failure or interruption.
The functions make the storage backend platform-specific while the backup runner
remains portable.

To keep managed storage mounted across commands, use `rrrr mount <hostname>`. It
records the mounted storage in
`${XDG_STATE_HOME:-$HOME/.local/state}/rrrr/<hostname>.storage`; the state
directory and record are private to the current user. A subsequent
`rrrr backup <hostname>` reuses that mount and leaves it attached. Run
`rrrr unmount <hostname>` to detach it and remove the state record. Custom
storage hooks must also set `STORAGE_MOUNTPOINT` when used with these commands
so `rrrr` can verify the recorded mount before a later backup.

### Built-in APFS sparse bundle storage

On macOS, set `STORAGE_PROVIDER="apfs-sparsebundle"` to keep a host's snapshots
in one APFS sparse bundle. `rrrr` creates the bundle on its first run, mounts it
for the backup, and detaches it when the run finishes or fails.

```bash
STORAGE_PROVIDER="apfs-sparsebundle"
STORAGE_IMAGE="$HOME/Documents/Backups/webhost.sparsebundle"
STORAGE_IMAGE_SIZE="500g"
```

`STORAGE_IMAGE_SIZE` is required only when creating the bundle. It is the
maximum virtual capacity; a sparse bundle consumes host filesystem space only as
backup data is stored. When `STORAGE_MOUNTPOINT` is unset, macOS mounts the
bundle under `/Volumes/<volume-name>`; the default volume name is
`rrrr-<hostname>`. Set `STORAGE_VOLUME_NAME` to change that name, or set
`STORAGE_MOUNTPOINT` to use an explicit custom location instead.

The provider requires macOS `hdiutil` and access to both the image location and
the mountpoint. Do not combine it with custom storage hooks.

For a Linux source backed up to macOS, set `RSYNC_PRESERVE_ACLS=0`: Linux ACLs
cannot be represented as macOS ACLs. If the backup account cannot read every
source path, set `RSYNC_KEEP_PARTIAL=1` to retain the readable data in a
date-and-process-specific directory under `partials/`. These retained snapshots
are never made `latest` and rsync still exits with status `23`, so automation
can report the incomplete run.

When unreadable paths are expected, set `RSYNC_ACCEPT_PARTIAL=1` instead. An
exit-23 run is then published and becomes `latest`, with the skipped paths
recorded in the run log.

SSH inherits the terminal input. When the key needs a passphrase or the remote
host requires a password, its prompt remains interactive. `rrrr` sends both
rsync output and errors to the terminal and run log.

### Built-in ext4 image storage

On Linux systems such as a QNAP NAS, set `STORAGE_PROVIDER="ext4-image"` to
store a host's snapshots in one ext4 filesystem image. The image is attached to
a loop device for the backup and detached when rrrr exits. `STORAGE_MOUNTPOINT`
is optional; rrrr creates and removes a private temporary mountpoint by default.

```bash
STORAGE_PROVIDER="ext4-image"
STORAGE_IMAGE="/share/Backups/rrrr/webhost.img"
STORAGE_IMAGE_SIZE_MIB=512000
STORAGE_ELEVATE_USER="admin"
```

An image is created and formatted only when `STORAGE_IMAGE` does not yet exist.
`STORAGE_IMAGE_SIZE_MIB` is required only for that first run. The provider
requires permission to use `losetup`, `mount`, and `umount`, plus `mkfs.ext4`
when creating an image. Set `STORAGE_MOUNTPOINT` only if you need a stable mount
location.

Set `STORAGE_ELEVATE_USER` when those operations need a privileged QNAP account.
rrrr then invokes only the image lifecycle commands with `sudo -n -u` and
changes the mounted image root back to the backup user. Configure a narrowly
scoped passwordless sudo rule; rrrr never prompts for a password. Images are
formatted with `metadata_csum_seed` disabled for compatibility with older QNAP
kernels.

For QNAP scheduled jobs, make the Entware tools available first:

```bash
export PATH="/opt/sbin:/opt/bin:/usr/bin:/bin"
```

Example:

```bash
REMOTE_USER="webbackup"
REMOTE_SSH_HOST="webhost"
SSH_KEY="/share/homes/admin/.ssh/webhost_backup_ed25519"
BACKUP_ROOT="/share/external/usb/Backups/webhost"
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=6
FILTERS_FILE="/etc/rrrr/default.filters"
```

### `filters` (optional)

If present, this file is passed to rsync via `--filter="merge <path>"`. Use it
for fine-grained include/exclude rules that are easier to express with rsync’s
filter syntax.

If neither a `filters` file nor `FILTERS_FILE` override is available, `rrrr`
falls back to a builtin filter list that mirrors the traditional Linux runtime
filesystem excludes.

Example `filters` file:

```
- /dev/**
- /proc/**
- /var/cache/**
+ /var/www/**
- *
```

## Usage

```bash
rrrr backup webhost
```

For managed storage, these commands can be used independently:

```bash
rrrr mount webhost
rrrr backup webhost
rrrr unmount webhost
```

The script writes logs to `<backup_root>/logs/YYYY-MM-DD.log`, updates `latest`
as a relative symlink to the published snapshot, and mirrors output to
stdout/stderr. Each run performs:

1. Validation of required commands and SSH key.
2. A temporary snapshot directory creation and optional `--link-dest` reuse.
3. `rsync -aHAX --numeric-ids --delete` with the configured filter rules.
4. Publishing the completed snapshot, `latest` symlink update, and retention
   pruning.

If rsync fails, rrrr removes the temporary snapshot and leaves `latest`
unchanged, so the backup can be retried on the same day.

See `man rrrr` for the full reference.
