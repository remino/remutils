#!/usr/bin/env bats

# TODO Add tests, though challenging with watchexec.

teardown() {
	if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

@test "liverename shows usage with no arguments" {
	run "$BATS_TEST_DIRNAME/../liverename"
	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE:"* ]]
}

@test "liverename shows version with -v" {
	run "$BATS_TEST_DIRNAME/../liverename" -v
	[ "$status" -eq 0 ]
	[[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}
