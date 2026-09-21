#!/usr/bin/env bats

setup() {

	MACONF="$BATS_TEST_DIRNAME/../maconf"
}

@test "reports its version" {

	run "$MACONF" -v

	[ "$status" -eq 0 ]
	[ "$output" = 'maconf 1.1.1' ]
}

@test "shows top-level and command help without macOS utilities" {

	run "$MACONF" -h

	[ "$status" -eq 0 ]
	[[ "$output" == *'Get and set various settings in macOS.'* ]]

	run "$MACONF" help dock

	[ "$status" -eq 0 ]
	[[ "$output" == *'Get or set settings related to the Dock.'* ]]
}
