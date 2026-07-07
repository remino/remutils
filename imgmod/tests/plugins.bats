#!/usr/bin/env bats

load helpers

@test "optimizes custom plugin output reported with public hook" {
	local output_file="$OUTPUT_DIR/public-hook.png"

	_make_fake_image_optim
	_write_custom_plugin publichook "
touch '$output_file'
imgmod_output '$output_file'
"

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../imgmod" -o publichook

	[ "$status" -eq 0 ]
	[ "$output" = "$output_file" ]
	[ "$(cat "$OPTIM_LOG")" = "$output_file" ]
}

@test "does not optimize custom plugin output printed without hook" {
	local output_file="$OUTPUT_DIR/stdout-only.png"

	_make_fake_image_optim
	_write_custom_plugin stdoutonly "
touch '$output_file'
echo '$output_file'
"

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../imgmod" -o stdoutonly

	[ "$status" -eq 0 ]
	[ "$output" = "$output_file" ]
	[ ! -e "$OPTIM_LOG" ]
}

@test "optimizes custom plugin output reported with compatibility hook" {
	local output_file="$OUTPUT_DIR/compat-hook.png"

	_make_fake_image_optim
	_write_custom_plugin compathook "
touch '$output_file'
_imgmod_output '$output_file'
"

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../imgmod" -o compathook

	[ "$status" -eq 0 ]
	[ "$output" = "$output_file" ]
	[ "$(cat "$OPTIM_LOG")" = "$output_file" ]
}

@test "runs custom plugin from XDG_DATA_HOME" {
	mkdir -p "$XDG_DATA_HOME/imgmod/plugins"
	cat > "$XDG_DATA_HOME/imgmod/plugins/imgmod-custom" << 'PLUGIN'
#!/bin/sh
echo "custom:$*"
PLUGIN
	chmod a+x "$XDG_DATA_HOME/imgmod/plugins/imgmod-custom"

	run "$BATS_TEST_DIRNAME/../imgmod" custom one two

	[ "$status" -eq 0 ]
	[ "$output" = "custom:one two" ]
}

@test "runs custom plugin using shared library helper" {
	mkdir -p "$XDG_DATA_HOME/imgmod/plugins"
	cat > "$XDG_DATA_HOME/imgmod/plugins/imgmod-helper" << PLUGIN
#!/usr/bin/env bash
IMGMOD_LIB="$BATS_TEST_DIRNAME/../lib/imgmod.sh"
. "\$IMGMOD_LIB"
_echo "helper:\$(_imgmod_output_format "")"
PLUGIN
	chmod a+x "$XDG_DATA_HOME/imgmod/plugins/imgmod-helper"

	run "$BATS_TEST_DIRNAME/../imgmod" helper

	[ "$status" -eq 0 ]
	[ "$output" = "helper:jpg" ]
}

@test "runs custom plugin through hook runtime" {
	_write_hook_plugin hookruntime "
hookruntime_start() {
	_echo \"hook:\$*\"
}
"

	run "$BATS_TEST_DIRNAME/../imgmod" hookruntime one two

	[ "$status" -eq 0 ]
	[ "$output" = "hook:one two" ]
}

@test "optim plugin optimizes an image in place" {
	_make_input_image
	_make_fake_image_optim

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../imgmod" optim "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$INPUT_FILE" ]
	[ "$(cat "$OPTIM_LOG")" = "$INPUT_FILE" ]
}

@test "optim plugin optimizes to an explicit output" {
	_make_input_image
	_make_fake_image_optim

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../imgmod" optim "$INPUT_FILE" "$EXPLICIT_OUTPUT"

	[ "$status" -eq 0 ]
	[ "$output" = "$EXPLICIT_OUTPUT" ]
	[ "$(cat "$OPTIM_LOG")" = "$EXPLICIT_OUTPUT" ]
}

@test "fails when hook runtime plugin has no start hook" {
	_write_hook_plugin nostart "
nostart_help() {
	_echo \"missing start\"
}
"

	run "$BATS_TEST_DIRNAME/../imgmod" nostart

	[ "$status" -eq 16 ]
	[ "$output" = "missing start" ]
}

@test "bundled plugins do not assign wrapper script name" {
	run bash -c "grep -R \"SCRIPT_NAME='imgmod'\" '$BATS_TEST_DIRNAME/../plugins'"

	[ "$status" -eq 1 ]
}

@test "bundled plugins do not define reserved imgmod hooks" {
	run bash -c "grep -R '^_imgmod_.*()' '$BATS_TEST_DIRNAME/../plugins'"

	[ "$status" -eq 1 ]
}

@test "XDG_DATA_HOME plugin overrides bundled plugin" {
	mkdir -p "$XDG_DATA_HOME/imgmod/plugins"
	cat > "$XDG_DATA_HOME/imgmod/plugins/imgmod-socshare" << 'PLUGIN'
#!/bin/sh
echo "local socshare:$*"
PLUGIN
	chmod a+x "$XDG_DATA_HOME/imgmod/plugins/imgmod-socshare"

	run "$BATS_TEST_DIRNAME/../imgmod" socshare value

	[ "$status" -eq 0 ]
	[ "$output" = "local socshare:value" ]
}

@test "searches XDG_DATA_DIRS in order" {
	mkdir -p "$XDG_DIRS_ONE/imgmod/plugins"
	mkdir -p "$XDG_DIRS_TWO/imgmod/plugins"
	cat > "$XDG_DIRS_ONE/imgmod/plugins/imgmod-ordered" << 'PLUGIN'
#!/bin/sh
echo one
PLUGIN
	cat > "$XDG_DIRS_TWO/imgmod/plugins/imgmod-ordered" << 'PLUGIN'
#!/bin/sh
echo two
PLUGIN
	chmod a+x "$XDG_DIRS_ONE/imgmod/plugins/imgmod-ordered"
	chmod a+x "$XDG_DIRS_TWO/imgmod/plugins/imgmod-ordered"

	run "$BATS_TEST_DIRNAME/../imgmod" ordered

	[ "$status" -eq 0 ]
	[ "$output" = "one" ]
}

@test "ignores non-executable plugin files" {
	mkdir -p "$XDG_DATA_HOME/imgmod/plugins"
	cat > "$XDG_DATA_HOME/imgmod/plugins/imgmod-notexec" << 'PLUGIN'
#!/bin/sh
echo "should not run"
PLUGIN

	run "$BATS_TEST_DIRNAME/../imgmod" notexec

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid command"* ]]
}
