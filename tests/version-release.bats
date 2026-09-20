#!/usr/bin/env bats

setup() {
	WORKDIR="$(mktemp -d)"
}

teardown() {
	rm -rf "$WORKDIR"
}

@test "version-release uploads Python distribution artifacts" {
	SCRIPT_DIR="$WORKDIR/demo"
	BIN_DIR="$WORKDIR/bin"
	mkdir -p "$SCRIPT_DIR" "$BIN_DIR"

	cat > "$SCRIPT_DIR/demo" << 'EOF'
#!/usr/bin/env bash
EOF
	chmod +x "$SCRIPT_DIR/demo"

	cat > "$SCRIPT_DIR/pyproject.toml" << 'EOF'
[project]
name = "demo"
version = "1.2.3"
EOF

	cat > "$SCRIPT_DIR/CHANGELOG.md" << 'EOF'
## v1.2.3

- Add Python packaging.
EOF

	cp ./bin/version ./bin/version-release ./bin/version-tarball "$BIN_DIR/"

	cat > "$BIN_DIR/gh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$1" = "release" ] && [ "$2" = "create" ]; then
	cat > /dev/null
	printf '%s\n' "$@" > "$GH_CREATE"
	exit 0
fi

if [ "$1" = "release" ] && [ "$2" = "upload" ]; then
	printf '%s\n' "$@" > "$GH_UPLOAD"
	exit 0
fi

exit 1
EOF
	chmod +x "$BIN_DIR/gh"

	cat > "$BIN_DIR/prettier" << 'EOF'
#!/usr/bin/env bash
cat
EOF
	chmod +x "$BIN_DIR/prettier"

	cat > "$BIN_DIR/python3" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$1" = "-m" ] && [ "$2" = "pip" ] && [ "$3" = "wheel" ]; then
	case "$8" in
		/*) ;;
		*) exit 1 ;;
	esac
	touch "$7/demo-1.2.3-py3-none-any.whl"
	exit 0
fi

exit 1
EOF
	chmod +x "$BIN_DIR/python3"

	git -C "$WORKDIR" init -q
	git -C "$WORKDIR" config user.email "test@example.com"
	git -C "$WORKDIR" config user.name "Test User"
	git -C "$WORKDIR" add demo
	git -C "$WORKDIR" commit -q -m "initial"
	git -C "$WORKDIR" tag "demo@1.2.3"

	pushd "$WORKDIR" > /dev/null
	GH_CREATE="$WORKDIR/create" GH_UPLOAD="$WORKDIR/upload" PATH="$BIN_DIR:$PATH" run "$BIN_DIR/version-release" demo
	popd > /dev/null

	[ "$status" -eq 0 ]
	[ "$(cat "$WORKDIR/create")" = "release
create
demo@1.2.3
--notes-file
-" ]
	UPLOAD="$(cat "$WORKDIR/upload")"
	[[ "$UPLOAD" == *"demo@1.2.3.tar.gz"* ]]
	[[ "$UPLOAD" == *"demo-1.2.3-py3-none-any.whl"* ]]
}
