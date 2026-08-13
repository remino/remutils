#!/usr/bin/env bats

setup() {
	SCRIPT_DIR="$BATS_TEST_DIRNAME/.."
	OSC52="$SCRIPT_DIR/osc52"
	COPY="$SCRIPT_DIR/osc52copy"
	PASTE="$SCRIPT_DIR/osc52paste"
	TTY_FILE="$(mktemp)"
}

teardown() {
	rm -f "$TTY_FILE"
}

@test "osc52copy encodes an argument as OSC 52" {
	run env OSC52_TTY="$TTY_FILE" "$COPY" 'hello'
	[ "$status" -eq 0 ]
	[ "$output" = '' ]
	[ "$(cat "$TTY_FILE")" = $'\033]52;c;aGVsbG8=\a' ]
}

@test "osc52 dispatches copy and paste subcommands" {
	run env OSC52_TTY="$TTY_FILE" "$OSC52" copy 'hello'
	[ "$status" -eq 0 ]
	[ "$(cat "$TTY_FILE")" = $'\033]52;c;aGVsbG8=\a' ]

	run "$OSC52" paste
	[ "$status" -ne 0 ]
	[[ "$output" != *'unbound variable'* ]]
}

@test "osc52copy encodes standard input as OSC 52" {
	run bash -c "printf 'hello' | OSC52_TTY='$TTY_FILE' '$COPY'"
	[ "$status" -eq 0 ]
	[ "$(cat "$TTY_FILE")" = $'\033]52;c;aGVsbG8=\a' ]
}

@test "both utilities report their version" {
	run "$OSC52" --version
	[ "$status" -eq 0 ]
	[ "$output" = 'osc52 0.1.0' ]

	run "$COPY" --version
	[ "$status" -eq 0 ]
	[ "$output" = 'osc52copy 0.1.0' ]

	run "$PASTE" --version
	[ "$status" -eq 0 ]
	[ "$output" = 'osc52paste 0.1.0' ]
}

@test "osc52paste accepts no arguments before opening the terminal" {
	local output

	run "$PASTE"
	[ "$status" -ne 0 ]
	[[ "$output" != *'unbound variable'* ]]
}
