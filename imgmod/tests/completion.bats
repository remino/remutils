#!/usr/bin/env bats

load helpers

@test "shows completion plugin version" {
	_assert_plugin_version completion "$BATS_TEST_DIRNAME/../imgmod" completion -v
}

@test "shows directly-run completion plugin version" {
	_assert_plugin_version completion "$BATS_TEST_DIRNAME/../plugins/imgmod-completion" -v
}

@test "shows completion plugin version with long option" {
	_assert_plugin_version completion "$BATS_TEST_DIRNAME/../imgmod" completion --version
}

@test "completion commands include meta and bundled commands" {
	run "$BATS_TEST_DIRNAME/../imgmod" completion commands

	[ "$status" -eq 0 ]
	_output_has_line help
	_output_has_line version
	_output_has_line chain
	_output_has_line completion
	_output_has_line newplugin
	_output_has_line socshare
}

@test "completion commands include executable XDG_DATA_HOME plugins" {
	mkdir -p "$XDG_DATA_HOME/imgmod/plugins"
	cat > "$XDG_DATA_HOME/imgmod/plugins/imgmod-localcomplete" << 'PLUGIN'
#!/bin/sh
:
PLUGIN
	chmod a+x "$XDG_DATA_HOME/imgmod/plugins/imgmod-localcomplete"

	run "$BATS_TEST_DIRNAME/../imgmod" completion commands

	[ "$status" -eq 0 ]
	_output_has_line localcomplete
}

@test "completion commands include executable XDG_DATA_DIRS plugins" {
	mkdir -p "$XDG_DIRS_TWO/imgmod/plugins"
	cat > "$XDG_DIRS_TWO/imgmod/plugins/imgmod-datacomplete" << 'PLUGIN'
#!/bin/sh
:
PLUGIN
	chmod a+x "$XDG_DIRS_TWO/imgmod/plugins/imgmod-datacomplete"

	run "$BATS_TEST_DIRNAME/../imgmod" completion commands

	[ "$status" -eq 0 ]
	_output_has_line datacomplete
}

@test "completion commands ignore non-executable plugins" {
	mkdir -p "$XDG_DATA_HOME/imgmod/plugins"
	cat > "$XDG_DATA_HOME/imgmod/plugins/imgmod-notcomplete" << 'PLUGIN'
#!/bin/sh
:
PLUGIN

	run "$BATS_TEST_DIRNAME/../imgmod" completion commands

	[ "$status" -eq 0 ]
	_output_lacks_line notcomplete
}

@test "completion commands ignore executable plugins without imgmod prefix" {
	mkdir -p "$XDG_DATA_HOME/imgmod/plugins"
	cat > "$XDG_DATA_HOME/imgmod/plugins/unprefixed" << 'PLUGIN'
#!/bin/sh
:
PLUGIN
	chmod a+x "$XDG_DATA_HOME/imgmod/plugins/unprefixed"

	run "$BATS_TEST_DIRNAME/../imgmod" completion commands

	[ "$status" -eq 0 ]
	_output_lacks_line unprefixed
}

@test "completion commands de-duplicate overridden plugin names" {
	mkdir -p "$XDG_DATA_HOME/imgmod/plugins"
	cat > "$XDG_DATA_HOME/imgmod/plugins/imgmod-socshare" << 'PLUGIN'
#!/bin/sh
:
PLUGIN
	chmod a+x "$XDG_DATA_HOME/imgmod/plugins/imgmod-socshare"

	run "$BATS_TEST_DIRNAME/../imgmod" completion commands

	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "$output" | grep -c '^socshare$')" -eq 1 ]
}

@test "completion options include top-level options" {
	run "$BATS_TEST_DIRNAME/../imgmod" completion options

	[ "$status" -eq 0 ]
	_output_has_line -h
	_output_has_line --help
	_output_has_line -v
	_output_has_line --version
	_output_has_line -n
	_output_has_line -o
}

@test "completion options include newplugin options" {
	run "$BATS_TEST_DIRNAME/../imgmod" completion options newplugin

	[ "$status" -eq 0 ]
	_output_has_line -h
	_output_has_line -v
	_output_has_line --version
	_output_has_line -t
}

@test "completion options include socshare options" {
	run "$BATS_TEST_DIRNAME/../imgmod" completion options socshare

	[ "$status" -eq 0 ]
	_output_has_line -h
	_output_has_line -v
	_output_has_line --version
	_output_has_line -f
}

@test "completion options include chain options" {
	run "$BATS_TEST_DIRNAME/../imgmod" completion options chain

	[ "$status" -eq 0 ]
	_output_has_line -h
	_output_has_line -v
	_output_has_line --version
}

@test "completion options include completion plugin options" {
	run "$BATS_TEST_DIRNAME/../imgmod" completion options completion

	[ "$status" -eq 0 ]
	_output_has_line -h
	_output_has_line --help
	_output_has_line -v
	_output_has_line --version
}

@test "completion prints bash completion script" {
	run "$BATS_TEST_DIRNAME/../imgmod" completion bash

	[ "$status" -eq 0 ]
	[[ "$output" == *"complete -F _imgmod imgmod"* ]]
	[[ "$output" == *"completion commands"* ]]
	[[ "$output" == *"completion options"* ]]
}

@test "completion prints zsh completion script" {
	run "$BATS_TEST_DIRNAME/../imgmod" completion zsh

	[ "$status" -eq 0 ]
	[[ "$output" == *"compdef _imgmod imgmod"* ]]
	[[ "$output" == *"completion commands"* ]]
	[[ "$output" == *"completion options"* ]]
}

@test "completion prints fish completion script" {
	run "$BATS_TEST_DIRNAME/../imgmod" completion fish

	[ "$status" -eq 0 ]
	[[ "$output" == *"complete -c imgmod"* ]]
	[[ "$output" == *"completion commands"* ]]
	[[ "$output" == *"completion options"* ]]
}

@test "old internal completion command fails" {
	run "$BATS_TEST_DIRNAME/../imgmod" __complete commands

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid command: __complete"* ]]
	[[ "$output" == *"Run imgmod -h for help."* ]]
	[[ "$output" != *"USAGE:"* ]]
}
