#!/usr/bin/env bats

setup() {
	bats_require_minimum_version 1.5.0
	TOOL="$BATS_TEST_DIRNAME/../prj"
	LEGACY_TOOL="$BATS_TEST_DIRNAME/../mkprj"
	TMP_DIR="$(mktemp -d)"
	unset PROJECTS_DIR PROJECTS_DIRS PRJ_PROJECTS_DIR PRJ_PROJECTS_DIRS
	unset TEMPLATES_DIR MKPRJ_TEMPLATE_DIR PRJ_TEMPLATE_DIR PRJ_TEMPLATES_DIR
	export PRJ_PROJECTS_DIR="$TMP_DIR/projects"
	export PRJ_TEMPLATES_DIR="$TMP_DIR/templates"
	mkdir -p "$PRJ_PROJECTS_DIR" "$PRJ_TEMPLATES_DIR/blank"
	touch "$PRJ_TEMPLATES_DIR/blank/hello.txt"
}

teardown() {
	rm -rf "$TMP_DIR"
}

@test "shows help with no command, help, and -h" {
	run "$TOOL"
	[ "$status" -eq 0 ]
	[[ "$output" == *'USAGE: prj <command>'* ]]

	run "$TOOL" help
	[ "$status" -eq 0 ]
	[[ "$output" == *'COMMANDS:'* ]]

	run "$TOOL" -h
	[ "$status" -eq 0 ]

	run "$TOOL" h
	[ "$status" -eq 0 ]
}

@test "shows the same version through version and -v" {
	run "$TOOL" version
	[ "$status" -eq 0 ]
	[ "$output" = "$($TOOL -v)" ]

	run "$TOOL" v
	[ "$status" -eq 0 ]
	[ "$output" = "$($TOOL -v)" ]
}

@test "help command mirrors command -h" {
	local command expected

	for command in new list templates doctor info version; do
		expected="$("$TOOL" "$command" -h)"
		run "$TOOL" help "$command"
		[ "$status" -eq 0 ]
		[ "$output" = "$expected" ]
	done
}

@test "finds bundled templates through a Homebrew-style symlink" {
	local install_dir="$TMP_DIR/install"
	local cellar_dir="$install_dir/Cellar/prj"
	local today="$(date +%Y%m%d)"

	mkdir -p "$install_dir/bin" "$cellar_dir/bin" "$cellar_dir/libexec/prj"
	cp "$TOOL" "$cellar_dir/bin/prj"
	cp -R "$BATS_TEST_DIRNAME/../lib" "$BATS_TEST_DIRNAME/../templates" "$cellar_dir/libexec/prj"
	ln -s prj "$cellar_dir/bin/mkprj"
	ln -s '../Cellar/prj/bin/prj' "$install_dir/bin/prj"
	ln -s '../Cellar/prj/bin/mkprj' "$install_dir/bin/mkprj"

	run env -u PRJ_TEMPLATES_DIR PRJ_PROJECTS_DIR="$TMP_DIR/homebrew-projects" "$install_dir/bin/prj" new test
	[ "$status" -eq 0 ]
	[ -f "$TMP_DIR/homebrew-projects/$today test/$today test.md" ]
}

@test "new and its aliases create projects" {
	local today="$(date +%Y%m%d)"

	run "$TOOL" new first
	[ "$status" -eq 0 ]
	[ -d "$PRJ_PROJECTS_DIR/$today first" ]

	run "$TOOL" mk second
	[ "$status" -eq 0 ]
	[ -d "$PRJ_PROJECTS_DIR/$today second" ]

	run "$TOOL" make third
	[ "$status" -eq 0 ]
	[ -d "$PRJ_PROJECTS_DIR/$today third" ]

	run "$TOOL" n fourth
	[ "$status" -eq 0 ]
	[ -d "$PRJ_PROJECTS_DIR/$today fourth" ]
}

@test "mkprj runs new and warns once" {
	local today="$(date +%Y%m%d)"

	run --separate-stderr "$LEGACY_TOOL" legacy
	[ "$status" -eq 0 ]
	[ "$output" = "$PRJ_PROJECTS_DIR/$today legacy" ]
	[ "$stderr" = 'Warning: mkprj is deprecated; use prj new.' ]
}

@test "uses the first plural project root for creation" {
	local first="$TMP_DIR/first"
	local second="$TMP_DIR/second"
	local today="$(date +%Y%m%d)"

	run env -u PRJ_PROJECTS_DIR PRJ_PROJECTS_DIRS="$first:$second" "$TOOL" new plural
	[ "$status" -eq 0 ]
	[ "$output" = "$first/$today plural" ]
}

@test "list combines configured roots and prints sorted absolute paths" {
	local one="$TMP_DIR/one"
	local two="$TMP_DIR/two"
	mkdir -p "$one/zulu" "$one/alpha" "$two/bravo"

	run env PRJ_PROJECTS_DIR="$one" PRJ_PROJECTS_DIRS="$one:$two" "$TOOL" list
	[ "$status" -eq 0 ]
	[ "$output" = "$(realpath "$one")/alpha
$(realpath "$one")/zulu
$(realpath "$two")/bravo" ]
}

@test "list warns and continues past an invalid root" {
	local valid="$TMP_DIR/valid"
	mkdir -p "$valid/project"

	run --separate-stderr env PRJ_PROJECTS_DIRS="$TMP_DIR/missing:$valid" "$TOOL" list
	[ "$status" -eq 0 ]
	[ "$output" = "$(realpath "$valid")/project" ]
	[[ "$stderr" == *"Project root is not a directory: $TMP_DIR/missing"* ]]
}

@test "list aliases match list" {
	mkdir -p "$PRJ_PROJECTS_DIR/project"

	run "$TOOL" list
	local listed="$output"

	run "$TOOL" ls
	[ "$status" -eq 0 ]
	[ "$output" = "$listed" ]

	run "$TOOL" l
	[ "$status" -eq 0 ]
	[ "$output" = "$listed" ]
}

@test "templates lists effective template names once" {
	local project="$TMP_DIR/work"
	mkdir -p "$project/.prj/templates/blank" "$project/.prj/templates/research"

	pushd "$project" > /dev/null
	run "$TOOL" templates
	[ "$status" -eq 0 ]
	[ "$output" = $'default\nblank\nresearch' ]

	run "$TOOL" t
	[ "$status" -eq 0 ]
	[ "$output" = $'default\nblank\nresearch' ]
	popd > /dev/null
}

@test "canonical template paths take precedence" {
	local project="$TMP_DIR/work"
	mkdir -p "$project/.prj/templates/custom"
	touch "$project/.prj/templates/custom/canonical.txt"

	pushd "$project" > /dev/null
	run "$TOOL" new -t custom test
	popd > /dev/null

	[ "$status" -eq 0 ]
	[ -f "$PRJ_PROJECTS_DIR/$(date +%Y%m%d) test/canonical.txt" ]
}

@test "runs a prj setup script for a relative project path" {
	local template="$TMP_DIR/template"
	mkdir -p "$template/.prj"
	printf '#!/usr/bin/env bash\nprintf "%%s" "$PRJ_PROJECT_DIR:$PWD" > result\n' > "$template/.prj/setup"
	chmod +x "$template/.prj/setup"

	pushd "$TMP_DIR" > /dev/null
	run "$TOOL" new -t "$template" ./hello
	popd > /dev/null

	[ "$status" -eq 0 ]
	[ "$(< "$TMP_DIR/$(date +%Y%m%d) hello/result")" = "./$(date +%Y%m%d) hello:$TMP_DIR/$(date +%Y%m%d) hello" ]
}

@test "deprecated mkprj setup paths warn once" {
	local template="$TMP_DIR/template"
	mkdir -p "$template/.mkprj"
	printf '#!/usr/bin/env bash\ntouch legacy-setup\n' > "$template/.mkprj/setup"
	chmod +x "$template/.mkprj/setup"

	run --separate-stderr "$TOOL" new -t "$template" legacy
	[ "$status" -eq 0 ]
	[ -f "$PRJ_PROJECTS_DIR/$(date +%Y%m%d) legacy/legacy-setup" ]
	[ "$stderr" = 'Warning: .mkprj/setup is deprecated; use .prj/setup.' ]
}

@test "deprecated project and template settings warn once" {
	local legacy_root="$TMP_DIR/legacy-root"
	local legacy_templates="$TMP_DIR/legacy-templates"
	mkdir -p "$legacy_templates/old"
	touch "$legacy_templates/old/legacy.txt"

	run --separate-stderr env -u PRJ_PROJECTS_DIR -u PRJ_PROJECTS_DIRS -u PRJ_TEMPLATES_DIR PROJECTS_DIR="$legacy_root" TEMPLATES_DIR="$legacy_templates" "$TOOL" new -t old test
	[ "$status" -eq 0 ]
	[ -f "$legacy_root/$(date +%Y%m%d) test/legacy.txt" ]
	[ "$(printf '%s\n' "$stderr" | wc -l | tr -d ' ')" -eq 1 ]
	[[ "$stderr" == Warning:* ]]
}

@test "doctor reports configuration readiness" {
	run "$TOOL" doctor
	[ "$status" -eq 0 ]
	[[ "$output" == *'PASS: Mustache renderer:'* ]]
	[[ "$output" == *'PASS: Project root:'* ]]

	run "$TOOL" d
	[ "$status" -eq 0 ]
}

@test "info reports the current configuration" {
	run "$TOOL" info
	[ "$status" -eq 0 ]
	[[ "$output" == *"Project root: $PRJ_PROJECTS_DIR"* ]]
	[[ "$output" == *"Template directory: $PRJ_TEMPLATES_DIR"* ]]

	run "$TOOL" i
	[ "$status" -eq 0 ]
	[[ "$output" == *"Configured root: $PRJ_PROJECTS_DIR"* ]]
}

@test "rejects invalid project dates" {
	run --separate-stderr "$TOOL" new '2021-02-29 test'
	[ "$status" -eq 20 ]
	[ "$stderr" = 'Invalid project date: 20210229' ]
}
