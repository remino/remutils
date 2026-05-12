#!/usr/bin/env bats

setup() {
	SCRIPT_DIR="$BATS_TEST_DIRNAME/.."
	SCRIPT="$SCRIPT_DIR/litesite"
	TEST_ROOT="$(mktemp -d)"
	SITE_ROOT="$TEST_ROOT/site"
	STUB_BIN="$TEST_ROOT/bin"
	mkdir -p "$STUB_BIN"
	export TEST_ROOT SITE_ROOT STUB_BIN
}

teardown() {
	rm -rf "$TEST_ROOT"
}

make_stub() {
	local name="$1"
	local body="$2"

	cat > "$STUB_BIN/$name" << EOF
#!/usr/bin/env bash
set -euo pipefail
$body
EOF
	chmod +x "$STUB_BIN/$name"
}

make_build_stubs() {
	PATH="$STUB_BIN:$PATH"
	export PATH

	make_stub npx '
while [[ $# -gt 0 ]]; do
	case "$1" in
		--yes)
			shift
			;;
		-p)
			shift 2
			;;
		html-minifier-terser|terser|lightningcss)
			cmd="$1"
			shift
			break
			;;
		*)
			shift
			;;
	esac
done

	case "${cmd:-}" in
	html-minifier-terser)
		input="${@: -1}"
		perl -0pe "s/<!--(?!\\!)[\\s\\S]*?-->//g" "$input"
		;;
	terser)
		input="$1"
		output=""
		shift
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--output)
					output="$2"
					shift 2
					;;
				*)
					shift
					;;
			esac
		done
		perl -0pe "s{/\*(?!\\!)(?:.|\\n)*?\*/}{}gs; s{//(?!\\!)[^\\n]*}{}g" "$input" > "$output"
		;;
	lightningcss)
		input=""
		output=""
		while [[ $# -gt 0 ]]; do
			case "$1" in
				-m)
					shift
					;;
				-o)
					output="$2"
					shift 2
					;;
				*)
					if [[ -z "$input" && -f "$1" ]]; then
						input="$1"
					fi
					shift
					;;
			esac
		done

		if [[ -n "$output" ]]; then
			cp "$input" "$output"
		else
			cat
		fi
		;;
	*)
		echo "unexpected npx command: ${cmd:-}" >&2
		exit 1
		;;
esac
'

	make_stub brotli '
input="${@: -1}"
cp "$input" "$input.br"
'

	make_stub gzip '
input="${@: -1}"
cp "$input" "$input.gz"
'

	make_stub zstd '
input="${@: -1}"
cp "$input" "$input.zst"
'

	make_stub magick '
input="$1"
output="${@: -1}"
cp "$input" "$output"
'

	make_stub ffmpeg '
echo "ffmpeg should not be called" >&2
exit 1
'

	make_stub rsdeploy '
printf "%s\n" "$@" > "$TEST_ROOT/rsdeploy.args"
'
}

make_serve_stub() {
	PATH="$STUB_BIN:$PATH"
	export PATH

	make_stub npx '
if [[ "${1:-}" == "--yes" && "${2:-}" == "live-server" ]]; then
	shift 2
	printf "Serving \"%s\" at http://127.0.0.1:8080\n" "$1"
	printf "Ready for changes\n"
	printf "Change detected %s/index.html\n" "$1"
	exit 0
fi

echo "unexpected npx invocation" >&2
exit 1
'
}

create_site() {
	run "$SCRIPT" init demo "$SITE_ROOT"
	[ "$status" -eq 0 ]
	[ -f "$SITE_ROOT/README.md" ]
	[ -f "$SITE_ROOT/justfile" ]
	[ -f "$SITE_ROOT/.gitignore" ]
	[ -f "$SITE_ROOT/.env" ]
	[ -f "$SITE_ROOT/src/public/index.html" ]
	printf 'avif' > "$SITE_ROOT/src/public/sample.avif"
}

make_minify_fixture() {
	cat > "$SITE_ROOT/src/public/index.html" << 'EOF'
<!doctype html>
<html lang="en">
	<head>
		<!--! keep html -->
		<!-- remove html -->
		<meta charset="utf-8" />
		<script src="/main.js" defer></script>
	</head>
	<body>
		<main>
			<p>Test.</p>
		</main>
	</body>
</html>
EOF

	cat > "$SITE_ROOT/src/public/main.js" << 'EOF'
/*! keep js */
// remove js
;(function () {
	'use strict'

	/* remove block */
	document.documentElement.classList.add('js')
	})()
EOF
}

make_include_fixture() {
	mkdir -p "$TEST_ROOT/includes"
	local abs_snippet="$TEST_ROOT/includes/snippet.html"

	cat > "$TEST_ROOT/includes/snippet.html" << 'EOF'
<section class="snippet">
	<p>Shared snippet.</p>
	<!--#include file="nested.html" -->
</section>
EOF

	cat > "$TEST_ROOT/includes/nested.html" << 'EOF'
<strong>Nested from outside the site root.</strong>
EOF

	cat > "$SITE_ROOT/src/public/index.html" << EOF
<!doctype html>
<html lang="en">
	<head>
		<meta charset="utf-8" />
		<title>demo</title>
	</head>
	<body>
		<main>
			<!--#include file="$abs_snippet" -->
		</main>
	</body>
</html>
EOF
}

@test "shows version" {
	run "$SCRIPT" -v

	[ "$status" -eq 0 ]
	expected_version="litesite $(sed -n 's/^VERSION="\([^"]*\)"/\1/p' "$SCRIPT" | head -n1)"
	[ "$output" = "$expected_version" ]
}

@test "shows help" {
	run "$SCRIPT" --help

	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE: litesite"* ]]
}

@test "no args shows usage" {
	run "$SCRIPT"

	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE: litesite"* ]]
}

@test "init scaffolds a site" {
	run "$SCRIPT" init demo "$SITE_ROOT"

	[ "$status" -eq 0 ]
	[ -f "$SITE_ROOT/README.md" ]
	[ -f "$SITE_ROOT/LICENSE.txt" ]
	[ -f "$SITE_ROOT/.deploy-filter" ]
	[ -f "$SITE_ROOT/src/public/index.html" ]
	[ -f "$SITE_ROOT/src/public/style.css" ]
	[ -f "$SITE_ROOT/src/public/main.js" ]
	[ -f "$SITE_ROOT/src/public/favicon.svg" ]
	[ -f "$SITE_ROOT/src/public/share.svg" ]
	[ -f "$SITE_ROOT/src/nginx/demo.conf" ]
	[[ "$(cat "$SITE_ROOT/README.md")" == *"# demo"* ]]
	[[ "$(cat "$SITE_ROOT/src/public/index.html")" == *"<title>demo</title>"* ]]
	[[ "$(cat "$SITE_ROOT/src/public/index.html")" == *"/style.css"* ]]
}

@test "new scaffolds in the current directory by default" {
	pushd "$TEST_ROOT" > /dev/null
	run "$SCRIPT" new demo
	popd > /dev/null

	[ "$status" -eq 0 ]
	[ -f "$TEST_ROOT/demo/README.md" ]
	[ -f "$TEST_ROOT/demo/src/nginx/demo.conf" ]
}

@test "jpg and webp stay as avif siblings" {
	create_site
	make_build_stubs

	run "$SCRIPT" -C "$SITE_ROOT" jpg "$SITE_ROOT/src/public/sample.avif"
	[ "$status" -eq 0 ]
	[ -f "$SITE_ROOT/src/public/sample.avif.jpg" ]

	run "$SCRIPT" -C "$SITE_ROOT" webp "$SITE_ROOT/src/public/sample.avif"
	[ "$status" -eq 0 ]
	[ -f "$SITE_ROOT/src/public/sample.avif.webp" ]
}

@test "serve rewrites absolute paths to relative" {
	create_site
	make_serve_stub
	ln -s "$SITE_ROOT" "$TEST_ROOT/site-link"

	run "$SCRIPT" -C "$TEST_ROOT/site-link" serve

	[ "$status" -eq 0 ]
	[[ "$output" == *'Serving "./src/public"'* ]]
	[[ "$output" == *'Change detected ./src/public/index.html'* ]]
	[[ "$output" != *"$TEST_ROOT/site-link"* ]]
}

@test "init without args is non-interactive" {
	run "$SCRIPT" init

	[ "$status" -eq 1 ]
	[[ "$output" == *"USAGE: litesite new <site_slug> [<dest_dir>]"* ]]
}

@test "build writes dist outputs with local stubs" {
	create_site
	make_build_stubs

	run "$SCRIPT" -C "$SITE_ROOT" build

	[ "$status" -eq 0 ]
	[ -f "$SITE_ROOT/dist/public/index.html" ]
	[ -f "$SITE_ROOT/dist/public/index.html.br" ]
	[ -f "$SITE_ROOT/dist/public/index.html.gz" ]
	[ -f "$SITE_ROOT/dist/public/index.html.zst" ]
	[ -f "$SITE_ROOT/dist/public/style.css" ]
	[ -f "$SITE_ROOT/dist/public/main.js" ]
	[ -f "$SITE_ROOT/dist/public/favicon.svg" ]
	[ -f "$SITE_ROOT/dist/public/share.svg" ]
	[ -f "$SITE_ROOT/dist/public/sample.avif" ]
	[ -f "$SITE_ROOT/dist/public/sample.avif.jpg" ]
	[ -f "$SITE_ROOT/dist/public/sample.avif.webp" ]
}

@test "compress regenerates compressed outputs" {
	create_site
	make_build_stubs

	run "$SCRIPT" -C "$SITE_ROOT" build
	[ "$status" -eq 0 ]
	rm "$SITE_ROOT/dist/public/index.html.br" "$SITE_ROOT/dist/public/index.html.gz" "$SITE_ROOT/dist/public/index.html.zst"

	run "$SCRIPT" -C "$SITE_ROOT" compress

	[ "$status" -eq 0 ]
	[ -f "$SITE_ROOT/dist/public/index.html.br" ]
	[ -f "$SITE_ROOT/dist/public/index.html.gz" ]
	[ -f "$SITE_ROOT/dist/public/index.html.zst" ]
}

@test "build can disable optional outputs" {
	create_site
	make_build_stubs

	run env LITESITE_BUILD_BROTLI=0 LITESITE_BUILD_GZIP=0 LITESITE_BUILD_ZSTD=0 LITESITE_BUILD_MINIFY=0 LITESITE_BUILD_AVIF_JPEG=0 LITESITE_BUILD_AVIF_WEBP=0 \
		"$SCRIPT" -C "$SITE_ROOT" build

	[ "$status" -eq 0 ]
	[ -f "$SITE_ROOT/dist/public/index.html" ]
	[ ! -e "$SITE_ROOT/dist/public/index.html.br" ]
	[ ! -e "$SITE_ROOT/dist/public/index.html.gz" ]
	[ ! -e "$SITE_ROOT/dist/public/index.html.zst" ]
	[ -f "$SITE_ROOT/dist/public/sample.avif" ]
	[ ! -e "$SITE_ROOT/dist/public/sample.avif.jpg" ]
	[ ! -e "$SITE_ROOT/dist/public/sample.avif.webp" ]
}

@test "build can disable minification" {
	create_site
	make_build_stubs
	make_minify_fixture

	run env LITESITE_BUILD_MINIFY=0 \
		"$SCRIPT" -C "$SITE_ROOT" build

	[ "$status" -eq 0 ]
	cmp "$SITE_ROOT/src/public/index.html" "$SITE_ROOT/dist/public/index.html"
	cmp "$SITE_ROOT/src/public/main.js" "$SITE_ROOT/dist/public/main.js"
}

@test "build expands html includes by default" {
	create_site
	make_build_stubs
	make_include_fixture

	run env LITESITE_BUILD_MINIFY=0 \
		"$SCRIPT" -C "$SITE_ROOT" build

	[ "$status" -eq 0 ]
	[[ "$(cat "$SITE_ROOT/dist/public/index.html")" == *"Shared snippet."* ]]
	[[ "$(cat "$SITE_ROOT/dist/public/index.html")" == *"Nested from outside the site root."* ]]
	[[ "$(cat "$SITE_ROOT/dist/public/index.html")" != *"#include file="* ]]
}

@test "build can disable html includes" {
	create_site
	make_build_stubs
	make_include_fixture

	run env LITESITE_BUILD_MINIFY=0 LITESITE_BUILD_INCLUDES=0 \
		"$SCRIPT" -C "$SITE_ROOT" build

	[ "$status" -eq 0 ]
	cmp "$SITE_ROOT/src/public/index.html" "$SITE_ROOT/dist/public/index.html"
}

@test "build preserves important comments when minifying" {
	create_site
	make_build_stubs
	make_minify_fixture

	run "$SCRIPT" -C "$SITE_ROOT" build

	[ "$status" -eq 0 ]
	[[ "$(cat "$SITE_ROOT/dist/public/index.html")" == *"<!--! keep html -->"* ]]
	[[ "$(cat "$SITE_ROOT/dist/public/index.html")" != *"remove html"* ]]
	[[ "$(cat "$SITE_ROOT/dist/public/main.js")" == *"/*! keep js */"* ]]
	[[ "$(cat "$SITE_ROOT/dist/public/main.js")" != *"remove js"* ]]
	[[ "$(cat "$SITE_ROOT/dist/public/main.js")" != *"remove block"* ]]
}

@test "deploy passes wet run flag to rsdeploy" {
	create_site
	make_build_stubs

	run "$SCRIPT" -C "$SITE_ROOT" deploy

	[ "$status" -eq 0 ]
	[ -f "$TEST_ROOT/rsdeploy.args" ]
	grep -Fx -- "-w" "$TEST_ROOT/rsdeploy.args"
	! grep -Fx -- "-n" "$TEST_ROOT/rsdeploy.args"
}

@test "deploy -n omits wet run flag" {
	create_site
	make_build_stubs

	run "$SCRIPT" -C "$SITE_ROOT" deploy -n

	[ "$status" -eq 0 ]
	[ -f "$TEST_ROOT/rsdeploy.args" ]
	! grep -Fx -- "-w" "$TEST_ROOT/rsdeploy.args"
}
