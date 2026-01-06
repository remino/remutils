#!/usr/bin/env bats

teardown() {
	if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

@test "file2dataurl shows usage with no arguments" {
	skip "FIXME Broken in 1.0.1"
	run "$BATS_TEST_DIRNAME/../file2dataurl"
	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE:"* ]]
}

@test "file2dataurl shows version with -v" {
	run "$BATS_TEST_DIRNAME/../file2dataurl" -v
	[ "$status" -eq 0 ]
	[[ "$output" =~ ^file2dataurl' '[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "file2dataurl shows help with -h" {
	run "$BATS_TEST_DIRNAME/../file2dataurl" -h
	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE:"* ]]
}

@test "file2dataurl converts a text file to data URL" {
	TMP_DIR=$(mktemp -d)
	echo "Hello, World!" >"$TMP_DIR/hello.txt"

	run "$BATS_TEST_DIRNAME/../file2dataurl" "$TMP_DIR/hello.txt"
	[ "$status" -eq 0 ]
	expected_output="data:text/plain;base64,SGVsbG8sIFdvcmxkIQo"
	[[ "$output" == "$expected_output" ]]
}
