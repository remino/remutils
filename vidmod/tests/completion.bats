#!/usr/bin/env bats

load helpers

@test "lists bundled commands" {
	run "$BATS_TEST_DIRNAME/../vidmod" completion commands

	[ "$status" -eq 0 ]
	_output_has_line chain
	_output_has_line completion
	_output_has_line newplugin
	_output_has_line 169
	_output_has_line mp4
	_output_has_line twitter
}

@test "lists chain command options" {
	run "$BATS_TEST_DIRNAME/../vidmod" completion options chain

	[ "$status" -eq 0 ]
	_output_has_line -h
	_output_has_line -v
	_output_has_line --version
}

@test "lists top-level options" {
	run "$BATS_TEST_DIRNAME/../vidmod" completion options

	[ "$status" -eq 0 ]
	_output_has_line -h
	_output_has_line --help
	_output_has_line -n
	_output_has_line -v
}

@test "lists legacy command options" {
	run "$BATS_TEST_DIRNAME/../vidmod" completion options mp4

	[ "$status" -eq 0 ]
	_output_has_line -f
	_output_has_line -o
}
