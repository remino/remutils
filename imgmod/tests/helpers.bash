#!/usr/bin/env bash

setup() {
	OUTPUT_DIR="$(mktemp -d)"
	INPUT_FILE="$OUTPUT_DIR/source.png"
	EXPLICIT_OUTPUT="$OUTPUT_DIR/share.webp"
	XDG_HOME="$OUTPUT_DIR/xdg-home"
	XDG_DIRS_ONE="$OUTPUT_DIR/xdg-dirs-one"
	XDG_DIRS_TWO="$OUTPUT_DIR/xdg-dirs-two"
	FAKE_BIN="$OUTPUT_DIR/fake-bin"
	OPTIM_LOG="$OUTPUT_DIR/image_optim.log"
	TOOL_LOG="$OUTPUT_DIR/tool.log"

	export XDG_DATA_HOME="$XDG_HOME"
	export XDG_DATA_DIRS="$XDG_DIRS_ONE:$XDG_DIRS_TWO"
}

teardown() {
	if [ -n "$OUTPUT_DIR" ]; then
		rm -rf "$OUTPUT_DIR"
	fi
}

_make_input_image() {
	if ! command -v magick > /dev/null 2>&1; then
		skip "magick is required"
	fi

	magick -size 1600x900 xc:red "$INPUT_FILE"
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

_make_fake_imgmod_tool() {
	local name=$1
	local exit_code="${2:-0}"

	mkdir -p "$FAKE_BIN"

	cat > "$FAKE_BIN/$name" << TOOL
#!/bin/sh
printf '%s' "$name" >> "\$IMGMOD_TOOL_LOG"
last=
for arg do
	printf ' <%s>' "\$arg" >> "\$IMGMOD_TOOL_LOG"
	last="\$arg"
done
printf '\n' >> "\$IMGMOD_TOOL_LOG"
if [ -n "\$last" ]; then
	: > "\${last#PNG8:}"
fi
exit $exit_code
TOOL
	chmod a+x "$FAKE_BIN/$name"
}

_make_fake_magick_with_identify() {
	mkdir -p "$FAKE_BIN"

	cat > "$FAKE_BIN/magick" << 'TOOL'
#!/bin/sh
printf '%s' magick >> "$IMGMOD_TOOL_LOG"
last=
for arg do
	printf ' <%s>' "$arg" >> "$IMGMOD_TOOL_LOG"
	last="$arg"
done
printf '\n' >> "$IMGMOD_TOOL_LOG"

if [ "$1" = identify ]; then
	case "$last" in
		*wide*) printf '800 200' ;;
		*tall*) printf '300 900' ;;
		*) printf '500 400' ;;
	esac
	exit 0
fi

if [ -n "$last" ]; then
	: > "${last#PNG8:}"
fi
TOOL
	chmod a+x "$FAKE_BIN/magick"
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

_script_version() {
	grep -m1 VERSION "$1" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+'
}

_assert_plugin_version() {
	local plugin_name=$1
	local plugin_script="$BATS_TEST_DIRNAME/../plugins/imgmod-$plugin_name"
	local version

	shift
	version="$(_script_version "$plugin_script")"

	run "$@"
	[ "$status" -eq 0 ]
	[ "$output" = "imgmod $plugin_name $version" ]
}
