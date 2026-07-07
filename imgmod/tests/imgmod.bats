#!/usr/bin/env bats

setup() {
	OUTPUT_DIR="$(mktemp -d)"
	INPUT_FILE="$OUTPUT_DIR/source.png"
	EXPLICIT_OUTPUT="$OUTPUT_DIR/share.webp"
	XDG_HOME="$OUTPUT_DIR/xdg-home"
	XDG_DIRS_ONE="$OUTPUT_DIR/xdg-dirs-one"
	XDG_DIRS_TWO="$OUTPUT_DIR/xdg-dirs-two"
	FAKE_BIN="$OUTPUT_DIR/fake-bin"
	OPTIM_LOG="$OUTPUT_DIR/image_optim.log"

	if ! command -v magick > /dev/null 2>&1; then
		skip "magick is required"
	fi

	magick -size 1600x900 xc:red "$INPUT_FILE"

	export XDG_DATA_HOME="$XDG_HOME"
	export XDG_DATA_DIRS="$XDG_DIRS_ONE:$XDG_DIRS_TWO"
}

teardown() {
	if [ -n "$OUTPUT_DIR" ]; then
		rm -rf "$OUTPUT_DIR"
	fi
}

@test "shows version" {
	local version
	version="$(grep -m1 VERSION "$BATS_TEST_DIRNAME/../imgmod" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')"

	run "$BATS_TEST_DIRNAME/../imgmod" -v

	[ "$status" -eq 0 ]
	[ "$output" = "imgmod $version" ]
}

@test "shows help" {
	run "$BATS_TEST_DIRNAME/../imgmod" -h

	[ "$status" -eq 0 ]
	[ "${output:0:7}" = "imgmod " ]
}

@test "shows help with long option" {
	run "$BATS_TEST_DIRNAME/../imgmod" --help

	[ "$status" -eq 0 ]
	[ "${output:0:7}" = "imgmod " ]
}

@test "shows version with long option" {
	local version
	version="$(grep -m1 VERSION "$BATS_TEST_DIRNAME/../imgmod" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')"

	run "$BATS_TEST_DIRNAME/../imgmod" --version

	[ "$status" -eq 0 ]
	[ "$output" = "imgmod $version" ]
}

@test "runs correctly through a symlink" {
	local link_dir="$OUTPUT_DIR/link-bin"
	local link="$link_dir/imgmod"

	mkdir -p "$link_dir"
	ln -s "$BATS_TEST_DIRNAME/../imgmod" "$link"

	run "$link" completion commands

	[ "$status" -eq 0 ]
	_output_has_line completion
	_output_has_line newplugin
	_output_has_line socshare
}

@test "shows socshare help" {
	run "$BATS_TEST_DIRNAME/../imgmod" socshare -h

	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE: imgmod socshare"* ]]
}

@test "shows socshare help with help command" {
	run "$BATS_TEST_DIRNAME/../imgmod" help socshare

	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE: imgmod socshare"* ]]
}

@test "shows direct socshare help with plugin context" {
	run "$BATS_TEST_DIRNAME/../plugins/imgmod-socshare" -h

	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE: imgmod socshare"* ]]
}

@test "shows newplugin help" {
	run "$BATS_TEST_DIRNAME/../imgmod" newplugin -h

	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE: imgmod newplugin"* ]]
}

@test "creates socshare image with automatic filename" {
	run "$BATS_TEST_DIRNAME/../imgmod" socshare "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$OUTPUT_DIR/source-pubshare.jpg" ]
	[ -f "$output" ]
	[ "$(magick identify -format '%wx%h' "$output")" = "1200x630" ]
	[ "$(magick identify -format '%m' "$output")" = "JPEG" ]
}

@test "runs bundled socshare directly" {
	run "$BATS_TEST_DIRNAME/../plugins/imgmod-socshare" "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$OUTPUT_DIR/source-pubshare.jpg" ]
	[ -f "$output" ]
	[ "$(magick identify -format '%wx%h' "$output")" = "1200x630" ]
	[ "$(magick identify -format '%m' "$output")" = "JPEG" ]
}

@test "creates socshare image with requested format" {
	run "$BATS_TEST_DIRNAME/../imgmod" socshare -f png "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$OUTPUT_DIR/source-pubshare.png" ]
	[ -f "$output" ]
	[ "$(magick identify -format '%wx%h' "$output")" = "1200x630" ]
	[ "$(magick identify -format '%m' "$output")" = "PNG" ]
}

@test "creates socshare image with explicit output" {
	run "$BATS_TEST_DIRNAME/../imgmod" socshare "$INPUT_FILE" "$EXPLICIT_OUTPUT"

	[ "$status" -eq 0 ]
	[ "$output" = "$EXPLICIT_OUTPUT" ]
	[ -f "$EXPLICIT_OUTPUT" ]
	[ "$(magick identify -format '%wx%h' "$EXPLICIT_OUTPUT")" = "1200x630" ]
	[ "$(magick identify -format '%m' "$EXPLICIT_OUTPUT")" = "WEBP" ]
}

@test "optimizes socshare output when -o is set" {
	_make_fake_image_optim

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../imgmod" -o socshare "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$OUTPUT_DIR/source-pubshare.jpg" ]
	[ -f "$output" ]
	[ "$(cat "$OPTIM_LOG")" = "$OUTPUT_DIR/source-pubshare.jpg" ]
}

@test "does not optimize socshare output without -o" {
	_make_fake_image_optim

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../imgmod" socshare "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$OUTPUT_DIR/source-pubshare.jpg" ]
	[ ! -e "$OPTIM_LOG" ]
}

@test "does not optimize directly-run socshare output" {
	_make_fake_image_optim

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../plugins/imgmod-socshare" "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$OUTPUT_DIR/source-pubshare.jpg" ]
	[ ! -e "$OPTIM_LOG" ]
}

@test "does not optimize newplugin output when -o is set" {
	_make_fake_image_optim

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../imgmod" -o newplugin notimage

	[ "$status" -eq 0 ]
	[ "$output" = "$XDG_DATA_HOME/imgmod/plugins/imgmod-notimage" ]
	[ -f "$output" ]
	[ ! -e "$OPTIM_LOG" ]
}

@test "fails when -o is set and image_optim is missing" {
	local safe_path="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

	run env PATH="$safe_path" "$BATS_TEST_DIRNAME/../imgmod" -o socshare "$INPUT_FILE"

	[ "$status" -eq 19 ]
	[[ "$output" == *"Required: image_optim"* ]]
	[ ! -e "$OUTPUT_DIR/source-pubshare.jpg" ]
}

@test "fails when image_optim fails" {
	_make_fake_image_optim 43

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../imgmod" -o socshare "$INPUT_FILE"

	[ "$status" -eq 43 ]
	[ "$output" = "$OUTPUT_DIR/source-pubshare.jpg" ]
	[ "$(cat "$OPTIM_LOG")" = "$OUTPUT_DIR/source-pubshare.jpg" ]
}

@test "does not optimize when plugin fails" {
	_make_fake_image_optim

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../imgmod" -o socshare "$OUTPUT_DIR/missing.png"

	[ "$status" -eq 17 ]
	[[ "$output" == *"No such file"* ]]
	[ ! -e "$OPTIM_LOG" ]
}

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

@test "fails when input is missing" {
	run "$BATS_TEST_DIRNAME/../imgmod" socshare "$OUTPUT_DIR/missing.png"

	[ "$status" -eq 17 ]
	[[ "$output" == *"No such file"* ]]
}

@test "fails for unknown command" {
	run "$BATS_TEST_DIRNAME/../imgmod" unknown

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid command: unknown"* ]]
	[[ "$output" == *"Run imgmod -h for help."* ]]
	[[ "$output" != *"USAGE:"* ]]
}

@test "fails for invalid wrapper option without showing full help" {
	run "$BATS_TEST_DIRNAME/../imgmod" -z

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid option: -z"* ]]
	[[ "$output" == *"Run imgmod -h for help."* ]]
	[[ "$output" != *"USAGE:"* ]]
}

@test "completion commands include meta and bundled commands" {
	run "$BATS_TEST_DIRNAME/../imgmod" completion commands

	[ "$status" -eq 0 ]
	_output_has_line help
	_output_has_line version
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
	_output_has_line -t
}

@test "completion options include socshare options" {
	run "$BATS_TEST_DIRNAME/../imgmod" completion options socshare

	[ "$status" -eq 0 ]
	_output_has_line -h
	_output_has_line -f
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

@test "completion files are bundled" {
	[ -f "$BATS_TEST_DIRNAME/../completions/bash/imgmod" ]
	[ -f "$BATS_TEST_DIRNAME/../completions/zsh/_imgmod" ]
	[ -f "$BATS_TEST_DIRNAME/../completions/fish/imgmod.fish" ]
}

@test "completion files use plugin command completion API" {
	grep -q "completion bash" "$BATS_TEST_DIRNAME/../completions/bash/imgmod"
	grep -q "completion zsh" "$BATS_TEST_DIRNAME/../completions/zsh/_imgmod"
	grep -q "completion fish" "$BATS_TEST_DIRNAME/../completions/fish/imgmod.fish"
	! grep -q "__complete" "$BATS_TEST_DIRNAME/../completions/bash/imgmod"
	! grep -q "__complete" "$BATS_TEST_DIRNAME/../completions/zsh/_imgmod"
	! grep -q "__complete" "$BATS_TEST_DIRNAME/../completions/fish/imgmod.fish"
}

@test "completion files do not hardcode plugin command names" {
	! grep -R -q "newplugin" "$BATS_TEST_DIRNAME/../completions"
	! grep -R -q "socshare" "$BATS_TEST_DIRNAME/../completions"
}

@test "homebrew formula installs shell completions" {
	grep -q "bash_completion.install" "$BATS_TEST_DIRNAME/../homebrew.rb.mustache"
	grep -q "zsh_completion.install" "$BATS_TEST_DIRNAME/../homebrew.rb.mustache"
	grep -q "fish_completion.install" "$BATS_TEST_DIRNAME/../homebrew.rb.mustache"
}

@test "manpages are bundled" {
	[ -f "$BATS_TEST_DIRNAME/../man/imgmod.1" ]
	[ -f "$BATS_TEST_DIRNAME/../man/imgmod-completion.1" ]
	[ -f "$BATS_TEST_DIRNAME/../man/imgmod-newplugin.1" ]
	[ -f "$BATS_TEST_DIRNAME/../man/imgmod-socshare.1" ]
}

@test "manpages document commands" {
	grep -q "^\\.TH IMGMOD " "$BATS_TEST_DIRNAME/../man/imgmod.1"
	grep -q "^\\.TH IMGMOD-COMPLETION " "$BATS_TEST_DIRNAME/../man/imgmod-completion.1"
	grep -q "^\\.TH IMGMOD-NEWPLUGIN " "$BATS_TEST_DIRNAME/../man/imgmod-newplugin.1"
	grep -q "^\\.TH IMGMOD-SOCSHARE " "$BATS_TEST_DIRNAME/../man/imgmod-socshare.1"
}

@test "homebrew formula installs manpages" {
	grep -q "man1.install" "$BATS_TEST_DIRNAME/../homebrew.rb.mustache"
}

@test "old pubshare command name fails" {
	run "$BATS_TEST_DIRNAME/../imgmod" pubshare

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid command: pubshare"* ]]
	[[ "$output" == *"Run imgmod -h for help."* ]]
	[[ "$output" != *"USAGE:"* ]]
}

@test "old pub-share command name fails" {
	run "$BATS_TEST_DIRNAME/../imgmod" pub-share

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid command: pub-share"* ]]
}

@test "old social-share command name fails" {
	run "$BATS_TEST_DIRNAME/../imgmod" social-share

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid command: social-share"* ]]
}

@test "old socialshare command name fails" {
	run "$BATS_TEST_DIRNAME/../imgmod" socialshare

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid command: socialshare"* ]]
}

@test "old new-plugin command name fails" {
	run "$BATS_TEST_DIRNAME/../imgmod" new-plugin

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid command: new-plugin"* ]]
}

@test "creates plugin from bare name in XDG_DATA_HOME" {
	local plugin="$XDG_DATA_HOME/imgmod/plugins/imgmod-watermark"

	run "$BATS_TEST_DIRNAME/../imgmod" newplugin watermark

	[ "$status" -eq 0 ]
	[ "$output" = "$plugin" ]
	[ -f "$plugin" ]
	[ -x "$plugin" ]
	[[ "$(sed -n '1,20p' "$plugin")" == *"imgmod watermark"* ]]
	[[ "$(sed -n '1,20p' "$plugin")" == *"VERSION='1.0.0'"* ]]
	[[ "$(cat "$plugin")" == *"watermark_start()"* ]]
	[[ "$(cat "$plugin")" == *"watermark_help()"* ]]
	[[ "$(cat "$plugin")" == *"imgmod_plugin_run \"\$@\""* ]]
	[[ "$(cat "$plugin")" != *"SCRIPT_NAME='imgmod'"* ]]
}

@test "creates plugin from custom template" {
	local plugin="$XDG_DATA_HOME/imgmod/plugins/imgmod-customtemplate"
	local template="$OUTPUT_DIR/custom.mustache"

	cat > "$template" << 'TEMPLATE'
#!/usr/bin/env bash
echo "{{plugin_name}} {{plugin_version}}"
TEMPLATE

	run "$BATS_TEST_DIRNAME/../imgmod" newplugin -t "$template" customtemplate

	[ "$status" -eq 0 ]
	[ "$output" = "$plugin" ]
	[ -f "$plugin" ]
	[ -x "$plugin" ]
	[ "$(cat "$plugin")" = $'#!/usr/bin/env bash\necho "customtemplate 1.0.0"' ]
}

@test "fails when custom template is missing" {
	local plugin="$XDG_DATA_HOME/imgmod/plugins/imgmod-missingtemplate"
	local template="$OUTPUT_DIR/missing.mustache"

	run "$BATS_TEST_DIRNAME/../imgmod" newplugin -t "$template" missingtemplate

	[ "$status" -eq 16 ]
	[[ "$output" == *"Template file not found"* ]]
	[ ! -e "$plugin" ]
}

@test "created bare-name plugin runs through imgmod" {
	run "$BATS_TEST_DIRNAME/../imgmod" newplugin watermark
	[ "$status" -eq 0 ]

	run "$BATS_TEST_DIRNAME/../imgmod" watermark

	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE: imgmod watermark"* ]]
}

@test "creates plugin from relative path exactly there" {
	local plugin="$OUTPUT_DIR/relative-plugin"

	(
		cd "$OUTPUT_DIR" || exit 1
		run "$BATS_TEST_DIRNAME/../imgmod" newplugin ./relative-plugin

		[ "$status" -eq 0 ]
		[ "$output" = "./relative-plugin" ]
		[ -f "$plugin" ]
		[ -x "$plugin" ]
	)
}

@test "creates plugin from absolute path exactly there" {
	local plugin="$OUTPUT_DIR/absolute-plugin"

	run "$BATS_TEST_DIRNAME/../imgmod" newplugin "$plugin"

	[ "$status" -eq 0 ]
	[ "$output" = "$plugin" ]
	[ -f "$plugin" ]
	[ -x "$plugin" ]
}

@test "does not overwrite existing plugin target" {
	local plugin="$XDG_DATA_HOME/imgmod/plugins/imgmod-watermark"

	mkdir -p "$(dirname "$plugin")"
	echo original > "$plugin"

	run "$BATS_TEST_DIRNAME/../imgmod" newplugin watermark

	[ "$status" -eq 16 ]
	[[ "$output" == *"File already exists"* ]]
	[ "$(cat "$plugin")" = "original" ]
}

@test "fails to create explicit path when parent is missing" {
	local plugin="$OUTPUT_DIR/missing/plugin"

	run "$BATS_TEST_DIRNAME/../imgmod" newplugin "$plugin"

	[ "$status" -eq 16 ]
	[[ "$output" == *"Directory does not exist"* ]]
	[ ! -e "$plugin" ]
}

@test "generated plugin direct execution without IMGMOD_LIB gives guidance" {
	local plugin="$OUTPUT_DIR/direct-plugin"

	run "$BATS_TEST_DIRNAME/../imgmod" newplugin "$plugin"
	[ "$status" -eq 0 ]

	run env -u IMGMOD_LIB "$plugin"

	[ "$status" -eq 16 ]
	[[ "$output" == *"Run this plugin through imgmod or set IMGMOD_LIB."* ]]
}

@test "creates plugin through -n alias" {
	local plugin="$XDG_DATA_HOME/imgmod/plugins/imgmod-aliasname"

	run "$BATS_TEST_DIRNAME/../imgmod" -n aliasname

	[ "$status" -eq 0 ]
	[ "$output" = "$plugin" ]
	[ -f "$plugin" ]
	[ -x "$plugin" ]
	[[ "$(sed -n '1,20p' "$plugin")" == *"imgmod aliasname"* ]]
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

_make_fake_image_optim() {
	local exit_code="${1:-0}"

	mkdir -p "$FAKE_BIN"

	cat > "$FAKE_BIN/image_optim" << PLUGIN
#!/bin/sh
printf '%s\n' "\$*" >> "\$IMGMOD_OPTIM_LOG"
exit $exit_code
PLUGIN
	chmod a+x "$FAKE_BIN/image_optim"
}

_write_custom_plugin() {
	local name=$1
	local body=$2
	local plugin="$XDG_DATA_HOME/imgmod/plugins/imgmod-$name"

	mkdir -p "$(dirname "$plugin")"

	cat > "$plugin" << PLUGIN
#!/usr/bin/env bash
. "\$IMGMOD_LIB"
$body
PLUGIN
	chmod a+x "$plugin"
}

_write_hook_plugin() {
	local name=$1
	local body=$2
	local plugin="$XDG_DATA_HOME/imgmod/plugins/imgmod-$name"

	mkdir -p "$(dirname "$plugin")"

	cat > "$plugin" << PLUGIN
#!/usr/bin/env bash
. "\$IMGMOD_LIB"
$body
imgmod_plugin_run "\$@"
PLUGIN
	chmod a+x "$plugin"
}

_output_has_line() {
	local expected=$1

	[[ "$output" == *$'\n'"$expected"$'\n'* ]] \
		|| [[ "$output" == "$expected"$'\n'* ]] \
		|| [[ "$output" == *$'\n'"$expected" ]] \
		|| [[ "$output" == "$expected" ]]
}

_output_lacks_line() {
	local unexpected=$1

	! _output_has_line "$unexpected"
}
