#!/usr/bin/env bats

setup() {
	GENRAND="$BATS_TEST_DIRNAME/../genrand"
}

@test "genrand produces a 32-character alphanumeric string by default" {
	run "$GENRAND"
	[ "$status" -eq 0 ]
	[[ "$output" =~ ^[a-zA-Z0-9]{32}$ ]]
}

@test "genrand supports the specified width and character type" {
	run "$GENRAND" 16 lower
	[ "$status" -eq 0 ]
	[[ "$output" =~ ^[a-z0-9]{16}$ ]]

	run "$GENRAND" 8 numbers
	[ "$status" -eq 0 ]
	[[ "$output" =~ ^[0-9]{8}$ ]]
}

@test "genrand accepts character types case-insensitively" {
	run "$GENRAND" 12 LOWER
	[ "$status" -eq 0 ]
	[[ "$output" =~ ^[a-z0-9]{12}$ ]]
}

@test "genrand reports help and version" {
	run "$GENRAND" -h
	[ "$status" -eq 0 ]
	[[ "$output" == *'USAGE: genrand'* ]]

	run "$GENRAND" -v
	[ "$status" -eq 0 ]
	[ "$output" = 'genrand 0.1.0' ]
}

@test "genrand rejects invalid widths" {
	run "$GENRAND" 0
	[ "$status" -eq 17 ]
	[[ "$output" == *'width must be an integer of 1 or higher'* ]]

	run "$GENRAND" abc
	[ "$status" -eq 17 ]
	[[ "$output" == *'width must be an integer of 1 or higher'* ]]
}

@test "genrand rejects invalid types and excess arguments" {
	run "$GENRAND" 8 invalid
	[ "$status" -eq 18 ]
	[[ "$output" == *'invalid type: invalid'* ]]

	run "$GENRAND" 8 lower extra
	[ "$status" -eq 16 ]
	[[ "$output" == *'too many arguments'* ]]
}
