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
	export RRRR_TEST_STORAGE_LOG="$TEST_ROOT/storage.log"
	export TMPDIR="$TEST_ROOT/tmp"
	mkdir -p "$TMPDIR"
	: > "$RRRR_TEST_RSYNC_LOG"
	: > "$RRRR_TEST_STORAGE_LOG"

	STUB_DIR="$TEST_ROOT/bin"
	mkdir -p "$STUB_DIR"
	export PATH="$STUB_DIR:$PATH"
	unset RRRR_TEST_RSYNC_FAIL

	_create_stub_rsync
	_create_stub_storage_commands
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

_create_stub_storage_commands() {
	cat << 'EOF' > "$STUB_DIR/dd"
#!/usr/bin/env bash
set -euo pipefail
printf 'dd %s\n' "$*" >> "$RRRR_TEST_STORAGE_LOG"
for arg in "$@"; do
	case "$arg" in
		of=*) : > "${arg#of=}" ;;
	esac
done
EOF

	cat << 'EOF' > "$STUB_DIR/mkfs.ext4"
#!/usr/bin/env bash
set -euo pipefail
printf 'mkfs.ext4 %s\n' "$*" >> "$RRRR_TEST_STORAGE_LOG"
EOF

	cat << 'EOF' > "$STUB_DIR/losetup"
#!/usr/bin/env bash
set -euo pipefail
printf 'losetup %s\n' "$*" >> "$RRRR_TEST_STORAGE_LOG"
if [ "$1" = "-f" ]; then
	printf '%s\n' '/dev/loop-test'
fi
EOF

	cat << 'EOF' > "$STUB_DIR/mount"
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -eq 0 ]; then
	printf '/dev/loop-test on %s type ext4 (rw)\n' "${RRRR_TEST_MOUNTPOINT:?}"
	exit 0
fi
printf 'mount %s\n' "$*" >> "$RRRR_TEST_STORAGE_LOG"
EOF

	cat << 'EOF' > "$STUB_DIR/umount"
#!/usr/bin/env bash
set -euo pipefail
printf 'umount %s\n' "$*" >> "$RRRR_TEST_STORAGE_LOG"
EOF

	cat << 'EOF' > "$STUB_DIR/hdiutil"
#!/usr/bin/env bash
set -euo pipefail
printf 'hdiutil %s\n' "$*" >> "$RRRR_TEST_STORAGE_LOG"

case "$1" in
	create)
		mkdir -p "${!#}"
		;;
	attach)
		for ((i = 1; i <= $#; i += 1)); do
			if [ "${!i}" = "-mountpoint" ]; then
				j=$((i + 1))
				mkdir -p "${!j}"
				break
			fi
		done
		;;
	detach)
		if [ "${RRRR_TEST_REMOVE_MOUNTPOINT:-0}" = "1" ]; then
			rm -rf "$2"
		fi
		;;
esac
EOF

	cat << 'EOF' > "$STUB_DIR/sudo"
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo %s\n' "$*" >> "$RRRR_TEST_STORAGE_LOG"
if [ "$1" = "-n" ]; then
	shift
fi
if [ "$1" = "-u" ]; then
	shift 2
fi
exec "$@"
EOF

	for cmd in dd hdiutil mkfs.ext4 losetup mount sudo umount; do
		chmod +x "$STUB_DIR/$cmd"
	done
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

@test "prints version with -v and accepts -V for compatibility" {
	local expected_version
	expected_version="$(sed -nE 's/^VERSION="([^"]+)"/rrrr \1/p' "$BATS_TEST_DIRNAME/../rrrr")"

	run "$BATS_TEST_DIRNAME/../rrrr" -v

	[ "$status" -eq 0 ]
	[ "$output" = "$expected_version" ]

	run "$BATS_TEST_DIRNAME/../rrrr" -V

	[ "$status" -eq 0 ]
	[ "$output" = "$expected_version" ]
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

@test "creates, mounts, and unmounts an ext4 image" {
	local host="image"
	_write_basic_config "$host"

	local image="$TEST_ROOT/images/$host.img"
	export RRRR_TEST_MOUNTPOINT="$TEST_ROOT/mounts/$host"
	cat << EOF >> "$XDG_CONFIG_HOME/rrrr/$host/config"
STORAGE_PROVIDER="ext4-image"
STORAGE_IMAGE="${image}"
STORAGE_IMAGE_SIZE_MIB=16
STORAGE_MOUNTPOINT="${RRRR_TEST_MOUNTPOINT}"
STORAGE_ELEVATE_USER="admin"
EOF

	run "$BATS_TEST_DIRNAME/../rrrr" "$host"

	[ "$status" -eq 0 ]
	[ -f "$image" ]
	[ -d "$RRRR_TEST_MOUNTPOINT/snapshots/$(date +%F)" ]
	grep -Fx -- "dd if=/dev/zero of=$image bs=1M count=16" "$RRRR_TEST_STORAGE_LOG"
	grep -Fx -- "mkfs.ext4 -F -O ^metadata_csum_seed $image" "$RRRR_TEST_STORAGE_LOG"
	grep -Fx -- "sudo -n -u admin losetup -f" "$RRRR_TEST_STORAGE_LOG"
	grep -Fx -- "losetup /dev/loop-test $image" "$RRRR_TEST_STORAGE_LOG"
	grep -Fx -- "mount -t ext4 /dev/loop-test $RRRR_TEST_MOUNTPOINT" "$RRRR_TEST_STORAGE_LOG"
	grep -Fx -- "umount $RRRR_TEST_MOUNTPOINT" "$RRRR_TEST_STORAGE_LOG"
	grep -Fx -- "losetup -d /dev/loop-test" "$RRRR_TEST_STORAGE_LOG"
}

@test "creates, mounts, and unmounts an APFS sparse bundle" {
	local host="mac-image"
	_write_basic_config "$host"

	local image="$TEST_ROOT/images/$host.sparsebundle"
	local mountpoint="$TEST_ROOT/mounts/$host"
	cat << EOF >> "$XDG_CONFIG_HOME/rrrr/$host/config"
STORAGE_PROVIDER="apfs-sparsebundle"
STORAGE_IMAGE="${image}"
STORAGE_IMAGE_SIZE="16g"
STORAGE_MOUNTPOINT="${mountpoint}"
EOF

	run "$BATS_TEST_DIRNAME/../rrrr" "$host"

	[ "$status" -eq 0 ]
	[ -d "$image" ]
	[ -d "$mountpoint/snapshots/$(date +%F)" ]
	grep -Fx -- "hdiutil create -size 16g -type SPARSEBUNDLE -fs APFS -volname rrrr-$host $image" "$RRRR_TEST_STORAGE_LOG"
	grep -Fx -- "hdiutil attach $image -nobrowse -mountpoint $mountpoint" "$RRRR_TEST_STORAGE_LOG"
	grep -Fx -- "hdiutil detach $mountpoint" "$RRRR_TEST_STORAGE_LOG"
}

@test "uses a private temporary mountpoint for an APFS sparse bundle by default" {
	local host="default-mac-image"
	_write_basic_config "$host"

	local image="$TEST_ROOT/images/$host.sparsebundle"
	cat << EOF >> "$XDG_CONFIG_HOME/rrrr/$host/config"
STORAGE_PROVIDER="apfs-sparsebundle"
STORAGE_IMAGE="${image}"
STORAGE_IMAGE_SIZE="16g"
EOF

	run env RRRR_TEST_REMOVE_MOUNTPOINT=1 "$BATS_TEST_DIRNAME/../rrrr" "$host"

	[ "$status" -eq 0 ]
	grep -E -- "^hdiutil attach ${image} -nobrowse -mountpoint ${TMPDIR}/rrrr-${host}-[0-9]+$" "$RRRR_TEST_STORAGE_LOG"
	grep -E -- "^hdiutil detach ${TMPDIR}/rrrr-${host}-[0-9]+$" "$RRRR_TEST_STORAGE_LOG"
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
