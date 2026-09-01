#!/usr/bin/env bats

setup() {
	SCRIPT="$BATS_TEST_DIRNAME/../vid2gif"
	TEST_ROOT="$(mktemp -d)"
	STUB_BIN="$TEST_ROOT/bin"
	mkdir -p "$STUB_BIN"
	export TEST_ROOT

	make_stub ffmpeg '
printf "%s\\n" "$@" >> "$TEST_ROOT/ffmpeg.args"
touch "${!#}"
'
	make_stub magick '
printf "%s\\n" "$@" >> "$TEST_ROOT/magick.args"
'
	make_stub image_optim '
printf "%s\\n" "$@" >> "$TEST_ROOT/image_optim.args"
exit 0
'
	PATH="$STUB_BIN:$PATH"
	export PATH
}

teardown() {
	rm -rf "$TEST_ROOT"
}

make_stub() {
	local name=$1
	local body=$2

	printf '#!/usr/bin/env bash\nset -euo pipefail\n%s\n' "$body" > "$STUB_BIN/$name"
	chmod +x "$STUB_BIN/$name"
}

@test "shows usage with no arguments" {
	run "$SCRIPT"
	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE: vid2gif"* ]]
}

@test "shows version" {
	run "$SCRIPT" --version
	[ "$status" -eq 0 ]
	[[ "$output" =~ ^vid2gif' '[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "fails when input is missing" {
	run "$SCRIPT" missing.mp4
	[ "$status" -eq 17 ]
	[[ "$output" == *"Missing or not a file: missing.mp4"* ]]
}

@test "converts directly without a command" {
	input="$TEST_ROOT/input.mp4"
	target="$TEST_ROOT/output.gif"
	touch "$input"

	run "$SCRIPT" -s 2 -d 4 -r 15 -w 480 "$input" "$target"
	[ "$status" -eq 0 ]
	[ -f "$target" ]
	[[ "$output" == *"$input => $target"* ]]
	grep -Fx -- '-ss' "$TEST_ROOT/ffmpeg.args"
	grep -Fx -- '2' "$TEST_ROOT/ffmpeg.args"
	grep -Fx -- 'fps=15,scale=480:-1:flags=lanczos,palettegen' "$TEST_ROOT/ffmpeg.args"
	[ "$(head -n 1 "$TEST_ROOT/magick.args")" = 'mogrify' ]
}

@test "dry run prints commands without creating output" {
	input="$TEST_ROOT/input.mp4"
	target="$TEST_ROOT/output.gif"
	touch "$input"

	run "$SCRIPT" --dry-run "$input" "$target"
	[ "$status" -eq 0 ]
	[ ! -e "$target" ]
	[[ "$output" == *"+ ffmpeg"* ]]
}

@test "accepts -H for output height" {
	input="$TEST_ROOT/input.mp4"
	target="$TEST_ROOT/output.gif"
	touch "$input"

	run "$SCRIPT" --dry-run --verbose -H 360 "$input" "$target"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ffmpeg filters: fps=10,scale=720:360:flags=lanczos"* ]]
}

@test "accepts legacy -t height alias" {
	input="$TEST_ROOT/input.mp4"
	target="$TEST_ROOT/output.gif"
	touch "$input"

	run "$SCRIPT" --dry-run --verbose -t 360 "$input" "$target"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ffmpeg filters: fps=10,scale=720:360:flags=lanczos"* ]]
}

@test "does not optimize with --no-optim" {
	input="$TEST_ROOT/input.mp4"
	target="$TEST_ROOT/output.gif"
	touch "$input"

	run "$SCRIPT" --no-optim "$input" "$target"
	[ "$status" -eq 0 ]
	[ ! -e "$TEST_ROOT/image_optim.args" ]
}

@test "does not optimize with +O" {
	input="$TEST_ROOT/input.mp4"
	target="$TEST_ROOT/output.gif"
	touch "$input"

	run "$SCRIPT" +O "$input" "$target"
	[ "$status" -eq 0 ]
	[ ! -e "$TEST_ROOT/image_optim.args" ]
}

@test "forces optimization with --optim" {
	input="$TEST_ROOT/input.mp4"
	target="$TEST_ROOT/output.gif"
	touch "$input"

	run "$SCRIPT" --optim "$input" "$target"
	[ "$status" -eq 0 ]
	[ "$(cat "$TEST_ROOT/image_optim.args")" = "$target" ]
}

@test "does not overwrite a file without permission" {
	input="$TEST_ROOT/input.mp4"
	target="$TEST_ROOT/output.gif"
	touch "$input" "$target"

	run "$SCRIPT" "$input" "$target"
	[ "$status" -eq 16 ]
	[[ "$output" == *"Output already exists (use --overwrite)"* ]]
}

@test "overwrites a file with --overwrite" {
	input="$TEST_ROOT/input.mp4"
	target="$TEST_ROOT/output.gif"
	touch "$input" "$target"

	run "$SCRIPT" --overwrite "$input" "$target"
	[ "$status" -eq 0 ]
	[ -f "$target" ]
}
