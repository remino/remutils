#!/usr/bin/env bats

setup() {
	bats_require_minimum_version 1.5.0

	TOOL="$BATS_TEST_DIRNAME/../mkprj"
	TMP_DIR="$(mktemp -d)"
	export PROJECTS_DIR="$TMP_DIR/projects"
	export TEMPLATES_DIR="$TMP_DIR/templates"
	mkdir -p "$PROJECTS_DIR" "$TEMPLATES_DIR/blank"
	touch "$TEMPLATES_DIR/blank/hello.txt"
}

teardown() {
	rm -rf "$TMP_DIR"
}

@test "shows version" {
	local version="$("$TOOL" -v)"

	run "$TOOL" -v

	[ "$status" -eq 0 ]
	[ "$output" = "$version" ]
}

@test "shows help" {
	local version="$("$TOOL" -v)"

	run "$TOOL" -h

	[ "$status" -eq 0 ]
	[[ "$output" == "$version"* ]]
}

@test "finds bundled templates through a Homebrew-style symlink" {
	local install_dir="$TMP_DIR/install"
	local cellar_dir="$install_dir/Cellar/mkprj"

	mkdir -p "$install_dir/bin" "$cellar_dir/bin" "$cellar_dir/libexec"
	cp "$TOOL" "$cellar_dir/bin/mkprj"
	cp -R "$BATS_TEST_DIRNAME/../lib" "$BATS_TEST_DIRNAME/../templates" "$cellar_dir/libexec"
	ln -s '../Cellar/mkprj/bin/mkprj' "$install_dir/bin/mkprj"

	run env PROJECTS_DIR="$TMP_DIR/projects" "$install_dir/bin/mkprj" test

	[ "$status" -eq 0 ]
	[ -f "$TMP_DIR/projects/$(date +%Y%m%d) test/$(date +%Y%m%d) test.md" ]
}

@test "creates a project with today's date" {
	local today="$(date +%Y%m%d)"

	run "$TOOL" test

	[ "$status" -eq 0 ]
	[ "$output" = "$PROJECTS_DIR/$today test" ]
	[ -d "$PROJECTS_DIR/$today test" ]
}

@test "normalizes an ISO date in a project path" {
	run "$TOOL" "$PROJECTS_DIR/2020-12-31 test"

	[ "$status" -eq 0 ]
	[ "$output" = "$PROJECTS_DIR/20201231 test" ]
	[ -d "$PROJECTS_DIR/20201231 test" ]
}

@test "copies a named template" {
	run "$TOOL" -t blank '20201231 test'

	[ "$status" -eq 0 ]
	[ -f "$PROJECTS_DIR/20201231 test/hello.txt" ]
}

@test "renders Mustache templates and bracketed paths" {
	local template="$TMP_DIR/custom-template"
	mkdir -p "$template/[client]"
	printf '# {{project_name}} for {{client}}\n' > "$template/[client]/[slug].md.mustache"

	run "$TOOL" -t "$template" --var client=Acme '20201231 Project Notes'

	[ "$status" -eq 0 ]
	[ -f "$PROJECTS_DIR/20201231 Project Notes/Acme/project-notes.md" ]
	[ "$(< "$PROJECTS_DIR/20201231 Project Notes/Acme/project-notes.md")" = '# Project Notes for Acme' ]
}

@test "renders Mustache templates whose source path contains spaces" {
	local template="$TMP_DIR/custom-template"
	mkdir -p "$template"
	printf '{{date}} {{name}}\n\nhey\n' > "$template/[project_date] [project_name].md.mustache"

	run "$TOOL" -t "$template" '20201231 Project Notes'

	[ "$status" -eq 0 ]
	[ "$(< "$PROJECTS_DIR/20201231 Project Notes/20201231 Project Notes.md")" = $'2020-12-31 Project Notes\n\nhey' ]
}

@test "uses the default template and runs its setup script" {
	local setup="$TEMPLATES_DIR/default/.mkprj/setup"
	mkdir -p "$(dirname "$setup")"
	printf '#!/usr/bin/env bash\nprintf "%%s" "$PROJECT_DATE:$PROJECT_NAME" > result\n' > "$setup"
	chmod +x "$setup"

	run "$TOOL" -t "$TEMPLATES_DIR/default" '20201231 test'

	[ "$status" -eq 0 ]
	[ "$(< "$PROJECTS_DIR/20201231 test/result")" = '2020-12-31:test' ]
}

@test "dry run does not create the project directory" {
	run "$TOOL" -n '20201231 test'

	[ "$status" -eq 0 ]
	[ "$output" = "$PROJECTS_DIR/20201231 test" ]
	[ ! -e "$PROJECTS_DIR/20201231 test" ]
}

@test "rejects an invalid calendar date" {
	run --separate-stderr "$TOOL" '2021-02-29 test'

	[ "$status" -eq 20 ]
	[ "$stderr" = 'Invalid project date: 20210229' ]
}

@test "rejects a missing project name" {
	run --separate-stderr "$TOOL"

	[ "$status" -eq 16 ]
	[ "$stderr" = 'Specify exactly one project name.' ]
}
