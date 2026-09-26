#!/usr/bin/env bats

setup() {

	IFTTTNOTIFY="$BATS_TEST_DIRNAME/../iftttnotify"
}

@test "reports its version" {

	run "$IFTTTNOTIFY" -v

	[ "$status" -eq 0 ]
	[ "$output" = 'iftttnotify 1.0.1' ]
}

@test "shows help without requiring an IFTTT key" {

	run "$IFTTTNOTIFY" -h

	[ "$status" -eq 0 ]
	[[ "$output" == *'Send notification via IFTTT Webhooks'* ]]
}

@test "requires a key before sending a notification" {

	run env -u IFTT_WEBHOOKS_KEY HOME="$BATS_TEST_TMPDIR" "$IFTTTNOTIFY" 'hello'

	[ "$status" -eq 18 ]
	[[ "$output" == *'Missing key.'* ]]
}
