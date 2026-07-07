#!/usr/bin/env bash

setup() {
	OUTPUT_DIR="$(mktemp -d)"
	INPUT_FILE="$OUTPUT_DIR/source.mov"
	XDG_HOME="$OUTPUT_DIR/xdg-home"
	XDG_DIRS_ONE="$OUTPUT_DIR/xdg-dirs-one"
	XDG_DIRS_TWO="$OUTPUT_DIR/xdg-dirs-two"
	FAKE_BIN="$OUTPUT_DIR/fake-bin"
	TOOL_LOG="$OUTPUT_DIR/tool.log"

	export XDG_DATA_HOME="$XDG_HOME"
	export XDG_DATA_DIRS="$XDG_DIRS_ONE:$XDG_DIRS_TWO"

	touch "$INPUT_FILE"
}

teardown() {
	if [ -n "$OUTPUT_DIR" ]; then
		rm -rf "$OUTPUT_DIR"
	fi
}

_make_fake_tool() {
	local name=$1
	local exit_code="${2:-0}"

	mkdir -p "$FAKE_BIN"

	cat > "$FAKE_BIN/$name" << TOOL
#!/bin/sh
printf '%s' "$name" >> "\$VIDMOD_TOOL_LOG"
for arg do
	printf ' <%s>' "\$arg" >> "\$VIDMOD_TOOL_LOG"
done
printf '\n' >> "\$VIDMOD_TOOL_LOG"
exit $exit_code
TOOL
	chmod a+x "$FAKE_BIN/$name"
}

_make_fake_video_tools() {
	_make_fake_tool ffmpeg
	_make_fake_tool butterflow
	_make_fake_tool vidcrossfade
}

_write_custom_plugin() {
	local name=$1
	local body=$2
	local plugin="$XDG_DATA_HOME/vidmod/plugins/vidmod-$name"

	mkdir -p "$(dirname "$plugin")"

	cat > "$plugin" << PLUGIN
#!/usr/bin/env bash
. "\$VIDMOD_LIB"
$body
PLUGIN
	chmod a+x "$plugin"
}

_write_hook_plugin() {
	local name=$1
	local body=$2
	local plugin="$XDG_DATA_HOME/vidmod/plugins/vidmod-$name"

	mkdir -p "$(dirname "$plugin")"

	cat > "$plugin" << PLUGIN
#!/usr/bin/env bash
. "\$VIDMOD_LIB"
$body
vidmod_plugin_run "\$@"
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

_script_version() {
	grep -m1 VERSION "$1" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+'
}
