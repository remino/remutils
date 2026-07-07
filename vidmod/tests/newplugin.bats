#!/usr/bin/env bats

load helpers

@test "creates plugin in XDG data home" {
	run "$BATS_TEST_DIRNAME/../vidmod" newplugin sample

	[ "$status" -eq 0 ]
	[ "$output" = "$XDG_DATA_HOME/vidmod/plugins/vidmod-sample" ]
	[ -x "$output" ]
	grep -q "sample_start" "$output"
}

@test "-n creates plugin shortcut" {
	run "$BATS_TEST_DIRNAME/../vidmod" -n shortcut

	[ "$status" -eq 0 ]
	[ "$output" = "$XDG_DATA_HOME/vidmod/plugins/vidmod-shortcut" ]
	[ -x "$output" ]
}
