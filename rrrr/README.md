# rrrr — Reliable Recursive Redundant RSync

`rrrr` is a snapshot-style backup runner that uses `rsync` over SSH to pull
incremental backups from a remote host. Each run creates
`<backup_root>/snapshots/YYYY-MM-DD`, updates a `latest` symlink, and enforces
a daily/weekly/monthly retention policy.

The tool is configured per host so the same script can back up multiple servers.
Run `rrrr <hostname>` and it will look for host-specific configuration at:

1. `$XDG_CONFIG_HOME/rrrr/<hostname>`
2. Each directory in `$XDG_CONFIG_DIRS` (default: `/etc/xdg`), under
   `rrrr/<hostname>`
3. `/etc/rrrr/<hostname>`

The first directory found wins.

## Host directory layout

Each host directory must contain at least a `config` file:

```
~/.config/rrrr/webhost/
├── config
└── filters     # optional (overrides builtin defaults)
```

### `config`

The file is `source`d by the script, so set shell variables there. The following
variables are required:

- `REMOTE_USER` – SSH user to connect as.
- `SSH_KEY` – private key on the backup host.
- `BACKUP_ROOT` – local directory that stores the snapshots.

Common optional variables:

- `HOSTNAME_REMOTE` – label used for logging.
- `REMOTE_SSH_HOST` – actual hostname/IP (defaults to the `<hostname>` argument).
- `REMOTE_SSH_PORT` – SSH port (defaults to `22`).
- `REMOTE_ROOT` – remote path to sync (defaults to `/`).
- `KEEP_DAILY`, `KEEP_WEEKLY`, `KEEP_MONTHLY` – retention counts.
- `FILTERS_FILE` – alternate path to an rsync filter file (if not using the
  host-local `filters` file).
- `SNAPS_DIR`, `LOG_DIR`, `LATEST_LINK` – override default paths inside
  `BACKUP_ROOT`.

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

## Running

```bash
rrrr webhost
```

The script writes logs to `<backup_root>/logs/YYYY-MM-DD.log` and mirrors the
output to stdout/stderr. Each run performs:

1. Validation of required commands and SSH key.
2. Snapshot directory creation and optional `--link-dest` reuse.
3. `rsync -aHAX --numeric-ids --delete` with the configured filter rules.
4. `latest` symlink update and retention pruning.

See `man rrrr` for the full reference.
