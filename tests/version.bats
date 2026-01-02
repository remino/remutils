#!/usr/bin/env bats

teardown() {
	if [ -n "$VERSION_FILE" ]; then
		rm -f "$VERSION_FILE"
	fi
}

@test "shows version from file" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.2.3' >"$VERSION_FILE"

	run ./bin/version show "$VERSION_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "1.2.3" ]
}

@test "updates major version in file" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.2.3' >"$VERSION_FILE"

	run ./bin/version major "$VERSION_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "1.2.3 2.2.3 $VERSION_FILE" ]
}

@test "updates minor version in file" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.2.3' >"$VERSION_FILE"

	run ./bin/version minor "$VERSION_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "1.2.3 1.3.3 $VERSION_FILE" ]
}

@test "updates patch version in file" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.2.3' >"$VERSION_FILE"

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
	echo 'NO_VERSION=1.2.3' >"$VERSION_FILE"

	run ./bin/version show "$VERSION_FILE"

	[ "$status" -eq 18 ]
	[ "$output" = "No VERSION found." ]
}

@test "handles invalid command" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.2.3' >"$VERSION_FILE"

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
	echo 'VERSION=1.2.3' >"$VERSION_FILE"

	run ./bin/version show

	[ "$status" -eq 16 ]
	[[ "$output" == *"USAGE:"* ]]
}

@test "version file is updated correctly after major update" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.2.3' >"$VERSION_FILE"

	run ./bin/version major "$VERSION_FILE"

	[ "$status" -eq 0 ]

	UPDATED_VERSION="$(grep -m1 -E '^VERSION=(\d+\.){2}(\d+)$' "$VERSION_FILE" | cut -d = -f 2)"
	[ "$UPDATED_VERSION" = "2.2.3" ]
}

@test "version file is updated correctly after minor update" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.2.3' >"$VERSION_FILE"

	run ./bin/version minor "$VERSION_FILE"

	[ "$status" -eq 0 ]

	UPDATED_VERSION="$(grep -m1 -E '^VERSION=(\d+\.){2}(\d+)$' "$VERSION_FILE" | cut -d = -f 2)"
	[ "$UPDATED_VERSION" = "1.3.3" ]
}

@test "version file is updated correctly after patch update" {
	VERSION_FILE="$(mktemp)"
	echo 'VERSION=1.2.3' >"$VERSION_FILE"

	run ./bin/version patch "$VERSION_FILE"

	[ "$status" -eq 0 ]

	UPDATED_VERSION="$(grep -m1 -E '^VERSION=(\d+\.){2}(\d+)$' "$VERSION_FILE" | cut -d = -f 2)"
	[ "$UPDATED_VERSION" = "1.2.4" ]
}
