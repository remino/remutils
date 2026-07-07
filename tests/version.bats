#!/usr/bin/env bats

teardown() {
	if [ -n "$VERSION_FILE" ]; then
		rm -f "$VERSION_FILE"
	fi
}

@test "shows version from file" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.2.3' > "$VERSION_FILE"

	run ./bin/version show "$VERSION_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "1.2.3" ]
}

@test "updates major version in file" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.1.1' > "$VERSION_FILE"

	run ./bin/version major "$VERSION_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "1.1.1 2.0.0 $VERSION_FILE" ]
}

@test "updates minor version in file" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.1.1' > "$VERSION_FILE"

	run ./bin/version minor "$VERSION_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "1.1.1 1.2.0 $VERSION_FILE" ]
}

@test "updates patch version in file" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.2.3' > "$VERSION_FILE"

	run ./bin/version patch "$VERSION_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "1.2.3 1.2.4 $VERSION_FILE" ]
}

@test "handles missing file" {
	VERSION_FILE="$(mktemp)"
	rm -f "$VERSION_FILE"

	run ./bin/version show "$VERSION_FILE"

	[ "$status" -eq 17 ]
	[ "$output" = "Missing file: $VERSION_FILE" ]
}

@test "handles missing version" {
	VERSION_FILE="$(mktemp)"
	echo 'NO_VERSION=1.2.3' > "$VERSION_FILE"

	run ./bin/version show "$VERSION_FILE"

	[ "$status" -eq 18 ]
	[ "$output" = "No VERSION found." ]
}

@test "handles invalid command" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.2.3' > "$VERSION_FILE"

	run ./bin/version invalid_cmd "$VERSION_FILE"

	[ "$status" -eq 16 ]
	[ "$output" = "Invalid command: invalid_cmd" ]
}

@test "shows usage when no arguments are provided" {
	run ./bin/version

	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE:"* ]]
}

@test "shows usage when insufficient arguments are provided" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.2.3' > "$VERSION_FILE"

	run ./bin/version show

	[ "$status" -eq 16 ]
	[[ "$output" == *"USAGE:"* ]]
}

@test "version file is updated correctly after major update" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.1.1' > "$VERSION_FILE"

	run ./bin/version major "$VERSION_FILE"

	[ "$status" -eq 0 ]

	UPDATED_VERSION="$(grep -m1 -E '^VERSION=(\d+\.){2}(\d+)$' "$VERSION_FILE" | cut -d = -f 2)"
	[ "$UPDATED_VERSION" = "2.0.0" ]
}

@test "version file is updated correctly after minor update" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.1.1' > "$VERSION_FILE"

	run ./bin/version minor "$VERSION_FILE"

	[ "$status" -eq 0 ]

	UPDATED_VERSION="$(grep -m1 -E '^VERSION=(\d+\.){2}(\d+)$' "$VERSION_FILE" | cut -d = -f 2)"
	[ "$UPDATED_VERSION" = "1.2.0" ]
}

@test "version file is updated correctly after patch update" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.2.3' > "$VERSION_FILE"

	run ./bin/version patch "$VERSION_FILE"

	[ "$status" -eq 0 ]

	UPDATED_VERSION="$(grep -m1 -E '^VERSION=(\d+\.){2}(\d+)$' "$VERSION_FILE" | cut -d = -f 2)"
	[ "$UPDATED_VERSION" = "1.2.4" ]
}

@test "updates changelog HEAD section when bumping a script directory" {
	WORKDIR="$(mktemp -d)"
	SCRIPT_DIR="$WORKDIR/demo"
	mkdir -p "$SCRIPT_DIR"

	cat > "$SCRIPT_DIR/demo" << 'EOF'
#!/usr/bin/env bash
VERSION="1.2.3"
EOF

	cat > "$SCRIPT_DIR/CHANGELOG.md" << 'EOF'
# Changelog

<!-- mtoc-start -->

- [HEAD](#head)
- [v1.2.3](#v123)

<!-- mtoc-end -->

## HEAD

- Add demo feature.

## v1.2.3

- Existing release.
EOF

	run ./bin/version patch "$SCRIPT_DIR/demo"

	[ "$status" -eq 0 ]
	[[ "$(cat "$SCRIPT_DIR/CHANGELOG.md")" == *"- [v1.2.4](#v124)"* ]]
	[[ "$(cat "$SCRIPT_DIR/CHANGELOG.md")" == *"## v1.2.4"* ]]
	[[ "$(cat "$SCRIPT_DIR/CHANGELOG.md")" == *"- Add demo feature."* ]]

	rm -rf "$WORKDIR"
}

@test "updates changelog Unreleased section when bumping a script directory" {
	WORKDIR="$(mktemp -d)"
	SCRIPT_DIR="$WORKDIR/demo"
	mkdir -p "$SCRIPT_DIR"

	cat > "$SCRIPT_DIR/demo" << 'EOF'
#!/usr/bin/env bash
VERSION="1.2.3"
EOF

	cat > "$SCRIPT_DIR/CHANGELOG.md" << 'EOF'
# Changelog

<!-- mtoc-start -->

- [Unreleased](#unreleased)

<!-- mtoc-end -->

## Unreleased

- Add demo feature.
EOF

	run ./bin/version minor "$SCRIPT_DIR/demo"

	[ "$status" -eq 0 ]
	[[ "$(cat "$SCRIPT_DIR/CHANGELOG.md")" == *"- [v1.3.0](#v130)"* ]]
	[[ "$(cat "$SCRIPT_DIR/CHANGELOG.md")" == *"## v1.3.0"* ]]

	rm -rf "$WORKDIR"
}

@test "updates manpage source version on the TH line" {
	WORKDIR="$(mktemp -d)"
	SCRIPT_DIR="$WORKDIR/demo"
	mkdir -p "$SCRIPT_DIR/man"

	cat > "$SCRIPT_DIR/demo" << 'EOF'
#!/usr/bin/env bash
VERSION="1.2.3"
EOF

	cat > "$SCRIPT_DIR/man/demo.1" << 'EOF'
.TH DEMO 1 "July 2026" "demo 1.0.0"
.SH NAME
demo \- demo
EOF

	run ./bin/version patch "$SCRIPT_DIR/demo"

	[ "$status" -eq 0 ]
	[ "$(sed -n '1p' "$SCRIPT_DIR/man/demo.1")" = '.TH DEMO 1 "July 2026" "demo 1.2.4"' ]

	rm -rf "$WORKDIR"
}

@test "version-commit stages package.json when present" {
	WORKDIR="$(mktemp -d)"
	SCRIPT_DIR="$WORKDIR/demo"
	BIN_DIR="$WORKDIR/bin"
	mkdir -p "$SCRIPT_DIR" "$BIN_DIR"

	cat > "$SCRIPT_DIR/demo" << 'EOF'
#!/usr/bin/env bash
VERSION="1.2.3"
EOF
	chmod +x "$SCRIPT_DIR/demo"

	cat > "$SCRIPT_DIR/package.json" << 'EOF'
{
  "name": "demo",
  "version": "1.2.3"
}
EOF

	cp ./bin/version "$BIN_DIR/version"
	cp ./bin/version-commit "$BIN_DIR/version-commit"

	git -C "$WORKDIR" init -q
	git -C "$WORKDIR" config user.email "test@example.com"
	git -C "$WORKDIR" config user.name "Test User"
	git -C "$WORKDIR" add .
	git -C "$WORKDIR" commit -q -m "initial"

	pushd "$WORKDIR" > /dev/null
	PATH="$BIN_DIR:$PATH" run "$BIN_DIR/version-commit" "$SCRIPT_DIR" patch
	popd > /dev/null

	[ "$status" -eq 0 ]
	[ -n "$(git -C "$WORKDIR" log -1 --format=%s)" ]
	[[ "$(git -C "$WORKDIR" ls-tree --name-only -r HEAD)" == *"demo"* ]]
	[[ "$(git -C "$WORKDIR" ls-tree --name-only -r HEAD)" == *"package.json"* ]]

	rm -rf "$WORKDIR"
}

@test "version-commit stages changelog and manpage changes" {
	WORKDIR="$(mktemp -d)"
	SCRIPT_DIR="$WORKDIR/demo"
	BIN_DIR="$WORKDIR/bin"
	mkdir -p "$SCRIPT_DIR/man" "$BIN_DIR"

	cat > "$SCRIPT_DIR/demo" << 'EOF'
#!/usr/bin/env bash
VERSION="1.2.3"
EOF
	chmod +x "$SCRIPT_DIR/demo"

	cat > "$SCRIPT_DIR/CHANGELOG.md" << 'EOF'
# Changelog

<!-- mtoc-start -->

- [HEAD](#head)

<!-- mtoc-end -->

## HEAD

- Add demo feature.
EOF

	cat > "$SCRIPT_DIR/man/demo.1" << 'EOF'
.TH DEMO 1 "July 2026" "demo 1.2.3"
EOF

	cp ./bin/version ./bin/version-commit "$BIN_DIR/"

	git -C "$WORKDIR" init -q
	git -C "$WORKDIR" config user.email "test@example.com"
	git -C "$WORKDIR" config user.name "Test User"
	git -C "$WORKDIR" add .
	git -C "$WORKDIR" commit -q -m "initial"

	pushd "$WORKDIR" > /dev/null
	PATH="$BIN_DIR:$PATH" run "$BIN_DIR/version-commit" "$SCRIPT_DIR" patch
	popd > /dev/null

	[ "$status" -eq 0 ]
	[[ "$(git -C "$WORKDIR" show --name-only --format= HEAD)" == *"CHANGELOG.md"* ]]
	[[ "$(git -C "$WORKDIR" show --name-only --format= HEAD)" == *"man/demo.1"* ]]
	[[ "$(git -C "$WORKDIR" show HEAD:demo/CHANGELOG.md)" == *"## v1.2.4"* ]]
	[ "$(git -C "$WORKDIR" show HEAD:demo/man/demo.1)" = '.TH DEMO 1 "July 2026" "demo 1.2.4"' ]

	rm -rf "$WORKDIR"
}

@test "version-commit updates package-lock.json when present" {
	WORKDIR="$(mktemp -d)"
	SCRIPT_DIR="$WORKDIR/demo"
	BIN_DIR="$WORKDIR/bin"
	mkdir -p "$SCRIPT_DIR" "$BIN_DIR"

	cat > "$SCRIPT_DIR/demo" << 'EOF'
#!/usr/bin/env bash
VERSION="1.2.3"
EOF
	chmod +x "$SCRIPT_DIR/demo"

	cat > "$SCRIPT_DIR/package.json" << 'EOF'
{
  "name": "demo",
  "version": "1.2.3"
}
EOF

	cat > "$SCRIPT_DIR/package-lock.json" << 'EOF'
{
  "name": "demo",
  "version": "1.2.3",
  "lockfileVersion": 3,
  "packages": {
    "": {
      "name": "demo",
      "version": "1.2.3"
    }
  }
}
EOF

	cp ./bin/version ./bin/version-commit "$BIN_DIR/"

	cat > "$BIN_DIR/npm" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "install" ]]; then
	package_dir="$PWD"
	version="$(node -e 'const fs=require("node:fs"); const pkg=JSON.parse(fs.readFileSync("package.json", "utf8")); process.stdout.write(pkg.version);')"
	node -e '
const fs = require("node:fs");
const file = "package-lock.json";
const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
pkg.version = process.argv[1];
if (pkg.packages && pkg.packages[""]) {
  pkg.packages[""].version = process.argv[1];
}
fs.writeFileSync(file, JSON.stringify(pkg, null, 2) + "\n");
' "$version"
	exit 0
fi

echo "unexpected npm invocation" >&2
exit 1
EOF
	chmod +x "$BIN_DIR/npm"

	git -C "$WORKDIR" init -q
	git -C "$WORKDIR" config user.email "test@example.com"
	git -C "$WORKDIR" config user.name "Test User"
	git -C "$WORKDIR" add .
	git -C "$WORKDIR" commit -q -m "initial"

	pushd "$WORKDIR" > /dev/null
	PATH="$BIN_DIR:$PATH" run "$BIN_DIR/version-commit" "$SCRIPT_DIR" patch
	popd > /dev/null

	[ "$status" -eq 0 ]
	[[ "$(git -C "$WORKDIR" show --name-only --format= HEAD)" == *"package-lock.json"* ]]
	[[ "$(cat "$SCRIPT_DIR/package-lock.json")" == *'"version": "1.2.4"'* ]]

	rm -rf "$WORKDIR"
}
