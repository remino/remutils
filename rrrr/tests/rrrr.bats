#!/usr/bin/env bats

_canonical_path() {
	python3 - <<'PY' "$1"
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
}

setup() {
	TEST_ROOT="$(mktemp -d)"
	export XDG_CONFIG_HOME="$TEST_ROOT/config"
	mkdir -p "$XDG_CONFIG_HOME/rrrr"

	export RRRR_TEST_BACKUP_ROOT="$TEST_ROOT/backups"
	export RRRR_TEST_RSYNC_LOG="$TEST_ROOT/rsync.log"
	: >"$RRRR_TEST_RSYNC_LOG"

	STUB_DIR="$TEST_ROOT/bin"
	mkdir -p "$STUB_DIR"
	export PATH="$STUB_DIR:$PATH"

	_create_stub_rsync
	_create_stub_find
}

teardown() {
	rm -rf "$TEST_ROOT"
}

_create_stub_rsync() {
	cat <<'EOF' >"$STUB_DIR/rsync"
#!/usr/bin/env bash
set -euo pipefail
: "${RRRR_TEST_RSYNC_LOG:?}"
printf "%s\n" "$@" >>"$RRRR_TEST_RSYNC_LOG"
EOF
	chmod +x "$STUB_DIR/rsync"
}

_create_stub_find() {
	cat <<'EOF' >"$STUB_DIR/find"
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -eq 0 ]; then
	exit 1
fi
dir="$1"
shift || true
for entry in "$dir"/*; do
	[ -d "$entry" ] || continue
	basename "$entry"
done
EOF
	chmod +x "$STUB_DIR/find"
}

_write_basic_config() {
	local host="$1"
	local dir="$XDG_CONFIG_HOME/rrrr/$host"
	mkdir -p "$dir"

	local ssh_key="$TEST_ROOT/id_rrrr"
	printf 'dummy' >"$ssh_key"

	cat <<EOF >"$dir/config"
REMOTE_USER="backup"
REMOTE_SSH_HOST="${host}.example"
SSH_KEY="${ssh_key}"
BACKUP_ROOT="${RRRR_TEST_BACKUP_ROOT}/${host}"
KEEP_DAILY=1
KEEP_WEEKLY=0
KEEP_MONTHLY=0
EOF

	cat <<'EOF' >"$dir/filters"
+ /etc
- *
EOF
}

@test "fails when hostname argument missing" {
	run "$BATS_TEST_DIRNAME/../rrrr"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Usage: rrrr"* ]]
}

@test "runs backup using host config and applies filter file" {
	local host="webhost"
	_write_basic_config "$host"

	local host_root="$RRRR_TEST_BACKUP_ROOT/$host"
	mkdir -p "$host_root/snapshots/2000-01-01"

	run "$BATS_TEST_DIRNAME/../rrrr" "$host"

	[ "$status" -eq 0 ]
	[[ "$output" == *"Backup complete"* ]]

	local today snapshot_dir latest_link old_snapshot
	today="$(date +%F)"
	snapshot_dir="$host_root/snapshots/$today"
	latest_link="$host_root/latest"
	old_snapshot="$host_root/snapshots/2000-01-01"

	[ -d "$snapshot_dir" ]
	[ -L "$latest_link" ]
	[ "$(readlink "$latest_link")" = "$snapshot_dir" ]
	[ ! -d "$old_snapshot" ]

	local filter_arg used_path expected_path
	filter_arg="$(grep -- '--filter=merge ' "$RRRR_TEST_RSYNC_LOG" | head -n1)"
	used_path="${filter_arg#--filter=merge }"
	expected_path="$(_canonical_path "$XDG_CONFIG_HOME/rrrr/$host/filters")"
	[ "$used_path" = "$expected_path" ]
}

@test "uses FILTERS_FILE override when configured" {
	local host="override"
	local dir="$XDG_CONFIG_HOME/rrrr/$host"
	mkdir -p "$dir"

	local ssh_key="$TEST_ROOT/id_override"
	printf 'dummy' >"$ssh_key"

	local custom_filters="$TEST_ROOT/custom.filters"
	cat <<'EOF' >"$custom_filters"
- /override/**
EOF

	cat <<EOF >"$dir/config"
REMOTE_USER="backup"
REMOTE_SSH_HOST="${host}.example"
SSH_KEY="${ssh_key}"
BACKUP_ROOT="${RRRR_TEST_BACKUP_ROOT}/${host}"
FILTERS_FILE="${custom_filters}"
KEEP_DAILY=1
KEEP_WEEKLY=0
KEEP_MONTHLY=0
EOF

	run "$BATS_TEST_DIRNAME/../rrrr" "$host"

	[ "$status" -eq 0 ]
	local filter_arg used_path expected_path
	filter_arg="$(grep -- '--filter=merge ' "$RRRR_TEST_RSYNC_LOG" | head -n1)"
	used_path="${filter_arg#--filter=merge }"
	expected_path="$(_canonical_path "${custom_filters}")"
	[ "$used_path" = "$expected_path" ]
}
