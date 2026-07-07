#!/usr/bin/env bats

load helpers

@test "shows newplugin plugin version" {
	_assert_plugin_version newplugin "$BATS_TEST_DIRNAME/../imgmod" newplugin -v
}

@test "shows directly-run newplugin plugin version" {
	_assert_plugin_version newplugin "$BATS_TEST_DIRNAME/../plugins/imgmod-newplugin" -v
}

@test "shows newplugin plugin version with long option" {
	_assert_plugin_version newplugin "$BATS_TEST_DIRNAME/../imgmod" newplugin --version
}

@test "shows newplugin help" {
	run "$BATS_TEST_DIRNAME/../imgmod" newplugin -h

	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE: imgmod newplugin"* ]]
}

@test "does not optimize newplugin output when -o is set" {
	_make_fake_image_optim

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../imgmod" -o newplugin notimage

	[ "$status" -eq 0 ]
	[ "$output" = "$XDG_DATA_HOME/imgmod/plugins/imgmod-notimage" ]
	[ -f "$output" ]
	[ ! -e "$OPTIM_LOG" ]
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

