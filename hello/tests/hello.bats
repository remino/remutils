#!/usr/bin/env bats

@test "hello script outputs 'hello'" {
	run "$BATS_TEST_DIRNAME/../hello"
	[ "$status" -eq 0 ]
	[ "$output" = "hello" ]
}
