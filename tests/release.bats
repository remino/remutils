#!/usr/bin/env bats

setup() {
	WORKDIR="$(mktemp -d)"
}

teardown() {
	rm -rf "$WORKDIR"
}

_write_demo_script() {
	SCRIPT_DIR="$WORKDIR/demo"
	mkdir -p "$SCRIPT_DIR"

	cat > "$SCRIPT_DIR/demo" << 'EOF'
#!/usr/bin/env bash
VERSION="1.0.0"
EOF
	chmod +x "$SCRIPT_DIR/demo"
}

_init_git_repo() {
	git -C "$WORKDIR" init -q
	git -C "$WORKDIR" config user.email "test@example.com"
	git -C "$WORKDIR" config user.name "Test User"
}

@test "release initial commits and tags script" {
	_write_demo_script
	_init_git_repo

	run ./bin/release "$SCRIPT_DIR" initial

	[ "$status" -eq 0 ]
	[ "$(git -C "$WORKDIR" log -1 --format=%s)" = "Add demo" ]
	[ "$(git -C "$WORKDIR" tag --list)" = "demo@1.0.0" ]
}

@test "release with --github publishes after initial release" {
	_write_demo_script
	_init_git_repo

	BIN_DIR="$WORKDIR/bin"
	mkdir -p "$BIN_DIR"
	cp ./bin/release ./bin/version "$BIN_DIR/"

	cat > "$BIN_DIR/version-release" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >"$RELEASE_MARKER"
EOF
	chmod +x "$BIN_DIR/version-release"

	RELEASE_MARKER="$WORKDIR/released" run "$BIN_DIR/release" "$SCRIPT_DIR" initial --github

	[ "$status" -eq 0 ]
	[ "$(cat "$WORKDIR/released")" = "$SCRIPT_DIR" ]
	[ "$(git -C "$WORKDIR" tag --list)" = "demo@1.0.0" ]
}

@test "release rejects invalid release type" {
	_write_demo_script
	_init_git_repo

	run ./bin/release "$SCRIPT_DIR" prerelease

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid release type: prerelease"* ]]
}
