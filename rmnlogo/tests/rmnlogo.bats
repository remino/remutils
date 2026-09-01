#!/usr/bin/env bats

@test "shows version" {
	run "$BATS_TEST_DIRNAME/../rmnlogo" -v

	[ "$status" -eq 0 ]
	[ "$output" = "rmnlogo 1.1.0" ]
}

@test "shows help" {
	run "$BATS_TEST_DIRNAME/../rmnlogo" -h

	[ "$status" -eq 0 ]
	[[ "$output" == *"Outputs the RÉMINO logo"* ]]
}

@test "renders the logo" {
	run "$BATS_TEST_DIRNAME/../rmnlogo"

	[ "$status" -eq 0 ]
	[[ "$output" == *"▀▀███▄"* ]]
}
