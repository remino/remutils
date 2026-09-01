#!/usr/bin/env bats

load helpers

@test "runs custom plugin from XDG_DATA_HOME" {
	mkdir -p "$XDG_DATA_HOME/vidmod/plugins"
	cat > "$XDG_DATA_HOME/vidmod/plugins/vidmod-custom" << 'PLUGIN'
#!/bin/sh
echo "custom:$*"
PLUGIN
	chmod a+x "$XDG_DATA_HOME/vidmod/plugins/vidmod-custom"

	run "$BATS_TEST_DIRNAME/../vidmod" custom one two

	[ "$status" -eq 0 ]
	[ "$output" = "custom:one two" ]
}

@test "runs custom plugin through hook runtime" {
	_write_hook_plugin hookruntime "
hookruntime_start() {
	_echo \"hook:\$*\"
}
"

	run "$BATS_TEST_DIRNAME/../vidmod" hookruntime one two

	[ "$status" -eq 0 ]
	[ "$output" = "hook:one two" ]
}

@test "XDG_DATA_HOME plugin overrides bundled plugin" {
	mkdir -p "$XDG_DATA_HOME/vidmod/plugins"
	cat > "$XDG_DATA_HOME/vidmod/plugins/vidmod-mp4" << 'PLUGIN'
#!/bin/sh
echo "local mp4:$*"
PLUGIN
	chmod a+x "$XDG_DATA_HOME/vidmod/plugins/vidmod-mp4"

	run "$BATS_TEST_DIRNAME/../vidmod" mp4 value

	[ "$status" -eq 0 ]
	[ "$output" = "local mp4:value" ]
}

@test "searches XDG_DATA_DIRS in order" {
	mkdir -p "$XDG_DIRS_ONE/vidmod/plugins"
	mkdir -p "$XDG_DIRS_TWO/vidmod/plugins"
	cat > "$XDG_DIRS_ONE/vidmod/plugins/vidmod-ordered" << 'PLUGIN'
#!/bin/sh
echo one
PLUGIN
	cat > "$XDG_DIRS_TWO/vidmod/plugins/vidmod-ordered" << 'PLUGIN'
#!/bin/sh
echo two
PLUGIN
	chmod a+x "$XDG_DIRS_ONE/vidmod/plugins/vidmod-ordered"
	chmod a+x "$XDG_DIRS_TWO/vidmod/plugins/vidmod-ordered"

	run "$BATS_TEST_DIRNAME/../vidmod" ordered

	[ "$status" -eq 0 ]
	[ "$output" = "one" ]
}
