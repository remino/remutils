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
