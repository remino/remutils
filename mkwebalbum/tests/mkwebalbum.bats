#!/usr/bin/env bats

setup() {
	SCRIPT="$BATS_TEST_DIRNAME/../mkwebalbum"
	TEST_ROOT="$(mktemp -d)"
	STUB_BIN="$TEST_ROOT/bin"
	mkdir -p "$STUB_BIN"
	export TEST_ROOT

	make_stub convert '
printf "%s\\n" "$@" >> "$TEST_ROOT/convert.args"
touch "${!#}"
'
	make_stub image_optim 'exit 0'
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

@test "shows help" {
	run "$SCRIPT" -h
	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE: mkwebalbum"* ]]
}

@test "shows version" {
	run "$SCRIPT" -v
	[ "$status" -eq 0 ]
	[[ "$output" =~ ^mkwebalbum' '[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "generates an album and previews image files" {
	album="$TEST_ROOT/album"
	mkdir -p "$album"
	touch "$album/photo.jpg" "$album/notes.txt"

	run bash -c 'cd "$1" && "$2" -t "My album"' _ "$album" "$SCRIPT"
	[ "$status" -eq 0 ]
	[ -f "$album/index.html" ]
	[ -f "$album/.preview/photo.jpg" ]
	[ -f "$album/.preview/.htaccess" ]
	[[ "$(cat "$album/index.html")" == *"<title>My album</title>"* ]]
	[[ "$(cat "$album/index.html")" == *"photo.jpg"* ]]
	[[ "$(cat "$album/index.html")" != *"notes.txt"* ]]
	grep -Fx -- 'photo.jpg' "$TEST_ROOT/convert.args"
}

@test "fails for a missing input directory" {
	run "$SCRIPT" /missing/album
	[ "$status" -eq 17 ]
	[[ "$output" == *"Input directory does not exist: /missing/album"* ]]
}
