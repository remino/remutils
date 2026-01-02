#!/usr/bin/env bats

teardown() {
	if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

@test "mkiso shows usage with no arguments" {
	run "$BATS_TEST_DIRNAME/../mkiso"
	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE:"* ]]
}

@test "mkiso shows version with -v" {
	run "$BATS_TEST_DIRNAME/../mkiso" -v
	[ "$status" -eq 0 ]
	[[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "mkiso fails with missing arguments" {
	run "$BATS_TEST_DIRNAME/../mkiso" /some/dir
	[ "$status" -ne 0 ]
	[[ "$output" == *"FATAL: Missing arguments."* ]]
}

@test "mkiso fails with non-existent input directory" {
	run "$BATS_TEST_DIRNAME/../mkiso" /non/existent/dir output.iso
	[ "$status" -ne 0 ]
	[[ "$output" == *"FATAL: Missing or not a directory:"* ]]
}

@test "mkiso creates ISO from valid directory" {
	TMP_DIR=$(mktemp -d)
	echo "Hello, World!" >"$TMP_DIR/file1.txt"
	echo "This is a test." >"$TMP_DIR/file2.txt"

	output_iso="$TMP_DIR/output.iso"

	run "$BATS_TEST_DIRNAME/../mkiso" "$TMP_DIR" "$output_iso"
	[ "$status" -eq 0 ]

	[ -f "$output_iso" ]

	rm -rf "$TMP_DIR"
}
