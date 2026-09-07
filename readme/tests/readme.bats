#!/usr/bin/env bats

setup() {
	bats_require_minimum_version 1.5.0

	TOOL="$BATS_TEST_DIRNAME/../readme"
	TMP_DIR="$(mktemp -d)"
}

teardown() {
	rm -rf "$TMP_DIR"
}

@test "shows version" {
	run "$TOOL" -v

	[ "$status" -eq 0 ]
	[ "$output" = 'readme 0.1.0' ]
}

@test "shows help" {
	run "$TOOL" -h

	[ "$status" -eq 0 ]
	[[ "$output" == 'readme 0.1.0'* ]]
	[[ "$output" == *'USAGE: readme [-hlv] [<filename>]'* ]]
}

@test "lists the current directory README before child directories" {
	mkdir -p "$TMP_DIR/alpha" "$TMP_DIR/zulu"
	touch "$TMP_DIR/README.md" "$TMP_DIR/alpha/readme.txt" "$TMP_DIR/zulu/README"

	run bash -c 'cd "$1" && "$2" -l' -- "$TMP_DIR" "$TOOL"

	[ "$status" -eq 0 ]
	[ "$output" = $'./README.md\n./alpha/readme.txt\n./zulu/README' ]
}

@test "uses a filename argument to restrict the search" {
	mkdir -p "$TMP_DIR/child"
	touch "$TMP_DIR/README.md" "$TMP_DIR/child/README.txt"

	run bash -c 'cd "$1" && "$2" -l README.txt' -- "$TMP_DIR" "$TOOL"

	[ "$status" -eq 0 ]
	[ "$output" = './child/README.txt' ]
}

@test "opens the first README with glow when available" {
	mkdir -p "$TMP_DIR/bin"
	touch "$TMP_DIR/README.md" "$TMP_DIR/README.txt"
	printf '#!/usr/bin/env bash\nprintf "glow: %%s\\n" "$2"\n' > "$TMP_DIR/bin/glow"
	chmod +x "$TMP_DIR/bin/glow"

	run bash -c 'cd "$1" && PATH="$1/bin:$PATH" "$2"' -- "$TMP_DIR" "$TOOL"

	[ "$status" -eq 0 ]
	[ "$output" = 'glow: ./README.md' ]
}

@test "fails when no README exists" {
	run bash -c 'cd "$1" && "$2" -l >/dev/null && "$2"' -- "$TMP_DIR" "$TOOL"

	[ "$status" -eq 1 ]
	[ "$output" = 'readme: no matching README file found' ]
}
