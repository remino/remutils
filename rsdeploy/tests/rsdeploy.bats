#!/usr/bin/env bats

teardown() {
	if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

@test "rsdeploy shows usage with -h" {
	run "$BATS_TEST_DIRNAME/../rsdeploy" -h
	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE:"* ]]
}

@test "rsdeploy shows version with -v" {
	run "$BATS_TEST_DIRNAME/../rsdeploy" -v
	[ "$status" -eq 0 ]
	[[ "$output" =~ ^rsdeploy' '[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "rsdeploy uses an explicit config instead of a nearby .env" {
	TMP_DIR="$(mktemp -d)"
	mkdir -p "$TMP_DIR/project" "$TMP_DIR/bin"

	printf '%s\n' \
		'RSDEPLOY_DEST=explicit.example:/site/' \
		'RSDEPLOY_SRC=explicit-src' > "$TMP_DIR/explicit.env"
	printf '%s\n' \
		'RSDEPLOY_DEST=local.example:/site/' \
		'RSDEPLOY_SRC=local-src' > "$TMP_DIR/project/.env"
	printf '%s\n' '#!/bin/sh' 'exit 0' > "$TMP_DIR/bin/rsync"
	chmod +x "$TMP_DIR/bin/rsync"

	run bash -c 'cd "$1" && PATH="$2:$PATH" "$3" -c "$4"' _ \
		"$TMP_DIR/project" "$TMP_DIR/bin" "$BATS_TEST_DIRNAME/../rsdeploy" "$TMP_DIR/explicit.env"

	[ "$status" -eq 0 ]
	[[ "$output" == *"RSDEPLOY_DEST=explicit.example:/site/"* ]]
	[[ "$output" == *"RSDEPLOY_SRC=explicit-src"* ]]
}
