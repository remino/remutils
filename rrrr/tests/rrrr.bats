#!/usr/bin/env bats

_canonical_path() {
	python3 - "$1" << 'PY'
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
	: > "$RRRR_TEST_RSYNC_LOG"

	STUB_DIR="$TEST_ROOT/bin"
	mkdir -p "$STUB_DIR"
	export PATH="$STUB_DIR:$PATH"
	unset RRRR_TEST_RSYNC_FAIL

	_create_stub_rsync
}

teardown() {
	rm -rf "$TEST_ROOT"
}

_create_stub_rsync() {
	cat << 'EOF' > "$STUB_DIR/rsync"
#!/usr/bin/env bash
set -euo pipefail
: "${RRRR_TEST_RSYNC_LOG:?}"
printf "%s\n" "$@" >>"$RRRR_TEST_RSYNC_LOG"

if [ "${RRRR_TEST_RSYNC_FAIL:-0}" = "1" ]; then
	exit 12
fi
EOF
	chmod +x "$STUB_DIR/rsync"
}

_write_basic_config() {
	local host="$1"
	local dir="$XDG_CONFIG_HOME/rrrr/$host"
	mkdir -p "$dir"

	local ssh_key="$TEST_ROOT/id_rrrr"
	printf 'dummy' > "$ssh_key"

	cat << EOF > "$dir/config"
REMOTE_USER="backup"
REMOTE_SSH_HOST="${host}.example"
SSH_KEY="${ssh_key}"
BACKUP_ROOT="${RRRR_TEST_BACKUP_ROOT}/${host}"
KEEP_DAILY=1
KEEP_WEEKLY=0
KEEP_MONTHLY=0
EOF

	cat << 'EOF' > "$dir/filters"
+ /etc
- *
EOF
}

@test "fails when hostname argument missing" {
	run "$BATS_TEST_DIRNAME/../rrrr"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Usage: rrrr"* ]]
}

@test "rejects an unsafe hostname" {
	run "$BATS_TEST_DIRNAME/../rrrr" "../webhost"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Hostname must be a single safe path component"* ]]
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
	printf 'dummy' > "$ssh_key"

	local custom_filters="$TEST_ROOT/custom.filters"
	cat << 'EOF' > "$custom_filters"
- /override/**
EOF

	cat << EOF > "$dir/config"
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

@test "runs storage hooks around a backup" {
	local host="mounted"
	_write_basic_config "$host"

	local storage_root="$TEST_ROOT/mounted-storage"
	local hooks_log="$TEST_ROOT/storage-hooks.log"
	cat << EOF >> "$XDG_CONFIG_HOME/rrrr/$host/config"
rrrr_storage_mount() {
	mkdir -p "${storage_root}"
	BACKUP_ROOT="${storage_root}"
	printf 'mount\\n' >> "${hooks_log}"
}

rrrr_storage_unmount() {
	printf 'unmount\\n' >> "${hooks_log}"
}
EOF

	run "$BATS_TEST_DIRNAME/../rrrr" "$host"

	[ "$status" -eq 0 ]
	[ -d "$storage_root/snapshots/$(date +%F)" ]
	[ "$(cat "$hooks_log")" = $'mount\nunmount' ]
}

@test "requires an unmount hook when a mount hook is configured" {
	local host="missing-unmount"
	_write_basic_config "$host"

	cat << 'EOF' >> "$XDG_CONFIG_HOME/rrrr/$host/config"
rrrr_storage_mount() {
	BACKUP_ROOT="/unused"
}
EOF

	run "$BATS_TEST_DIRNAME/../rrrr" "$host"

	[ "$status" -eq 1 ]
	[[ "$output" == *"rrrr_storage_unmount must be defined"* ]]
}

@test "runs the unmount hook after rsync fails" {
	local host="failed-mounted"
	_write_basic_config "$host"

	local storage_root="$TEST_ROOT/failed-mounted-storage"
	local hooks_log="$TEST_ROOT/failed-storage-hooks.log"
	cat << EOF >> "$XDG_CONFIG_HOME/rrrr/$host/config"
rrrr_storage_mount() {
	mkdir -p "${storage_root}"
	BACKUP_ROOT="${storage_root}"
	printf 'mount\\n' >> "${hooks_log}"
}

rrrr_storage_unmount() {
	printf 'unmount\\n' >> "${hooks_log}"
}
EOF

	run env RRRR_TEST_RSYNC_FAIL=1 "$BATS_TEST_DIRNAME/../rrrr" "$host"

	[ "$status" -eq 12 ]
	[ "$(cat "$hooks_log")" = $'mount\nunmount' ]
}

@test "removes an incomplete snapshot after rsync fails" {
	local host="failed"
	_write_basic_config "$host"

	run env RRRR_TEST_RSYNC_FAIL=1 "$BATS_TEST_DIRNAME/../rrrr" "$host"

	[ "$status" -eq 12 ]
	[ ! -e "$RRRR_TEST_BACKUP_ROOT/$host/snapshots/$(date +%F)" ]
	[ ! -e "$RRRR_TEST_BACKUP_ROOT/$host/latest" ]

	local -a incomplete=()
	shopt -s nullglob
	incomplete=("$RRRR_TEST_BACKUP_ROOT/$host/snapshots"/.*.incomplete.*)
	[ "${#incomplete[@]}" -eq 0 ]

	run "$BATS_TEST_DIRNAME/../rrrr" "$host"

	[ "$status" -eq 0 ]
	[ -d "$RRRR_TEST_BACKUP_ROOT/$host/snapshots/$(date +%F)" ]
}

@test "uses latest snapshot as link-dest" {
	local host="linked"
	_write_basic_config "$host"

	local host_root="$RRRR_TEST_BACKUP_ROOT/$host"
	local previous="$host_root/snapshots/2000-01-01"
	mkdir -p "$previous"
	ln -s "$previous" "$host_root/latest"

	run "$BATS_TEST_DIRNAME/../rrrr" "$host"

	[ "$status" -eq 0 ]
	grep -Fx -- "--link-dest" "$RRRR_TEST_RSYNC_LOG"
	grep -Fx -- "$previous" "$RRRR_TEST_RSYNC_LOG"
}

@test "keeps daily, weekly, and monthly retention snapshots" {
	local host="retention"
	_write_basic_config "$host"

	local host_root="$RRRR_TEST_BACKUP_ROOT/$host"
	mkdir -p "$host_root/snapshots/1999-12-31"
	mkdir -p "$host_root/snapshots/2000-01-01"
	mkdir -p "$host_root/snapshots/2000-01-02"

	cat << EOF >> "$XDG_CONFIG_HOME/rrrr/$host/config"
KEEP_DAILY=1
KEEP_WEEKLY=1
KEEP_MONTHLY=2
EOF

	run "$BATS_TEST_DIRNAME/../rrrr" "$host"

	[ "$status" -eq 0 ]
	[ ! -d "$host_root/snapshots/1999-12-31" ]
	[ -d "$host_root/snapshots/2000-01-01" ]
	[ -d "$host_root/snapshots/2000-01-02" ]
}
