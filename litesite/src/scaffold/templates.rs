pub fn index_html(slug: &str) -> String {
    format!(
        r##"<!doctype html>
<html lang="en">
	<head>
		<meta charset="utf-8" />
		<title>{slug}</title>
		<meta name="viewport" content="width=device-width, initial-scale=1" />
		<meta
			name="description"
			content="A small-site boilerplate with a source-to-dist build, deploy, and preview workflow." />
		<meta name="robots" content="index,follow" />
		<meta name="theme-color" content="#17120d" />
		<link rel="canonical" href="https://example.com/" />
		<link rel="icon" href="/favicon.svg" type="image/svg+xml" />
		<meta property="og:site_name" content="{slug}" />
		<meta property="og:type" content="website" />
		<meta property="og:title" content="{slug}" />
		<meta
			property="og:description"
			content="A small-site boilerplate with a source-to-dist build, deploy, and preview workflow." />
		<meta property="og:url" content="https://example.com/" />
		<meta property="og:image" content="https://example.com/share.svg" />
		<meta property="og:image:alt" content="{slug} share image" />
		<meta property="og:image:type" content="image/svg+xml" />
		<meta property="og:image:width" content="1200" />
		<meta property="og:image:height" content="630" />
		<meta name="twitter:card" content="summary_large_image" />
		<meta name="twitter:title" content="{slug}" />
		<meta
			name="twitter:description"
			content="A small-site boilerplate with a source-to-dist build, deploy, and preview workflow." />
		<meta name="twitter:image" content="https://example.com/share.svg" />
		<link rel="stylesheet" href="/style.css" />
		<script src="/main.js" defer></script>
	</head>
	<body>
		<main>
			<p>Edit me.</p>
		</main>
	</body>
</html>
"##
    )
}

pub const EDITORCONFIG: &str = r#"root = true

[*]
end_of_line = lf
insert_final_newline = true
indent_size = 2
indent_style = tab

# shfmt
binary_next_line = true
function_next_line = false
keep_padding = false
never_split = true
shell_variant = bash
space_redirects = true
switch_case_indent = true

[*.md]
trim_trailing_whitespace = false
indent_size = 4
indent_style = space

[*.{yaml,yml}]
indent_style = space
"#;

pub const GITIGNORE: &str = r#"dist/
node_modules/
.DS_Store
.env
"#;

pub const ENV_EXAMPLE: &str = r#"RSDEPLOY_DEST=host:example.com/path/
RSDEPLOY_SRC=dist
RSDEPLOY_FILTER=.deploy-filter
LITESITE_BUILD_BROTLI=1
LITESITE_BUILD_GZIP=1
LITESITE_BUILD_ZSTD=1
LITESITE_BUILD_MINIFY=1
LITESITE_BUILD_INCLUDES=1
LITESITE_BUILD_AVIF_JPEG=1
LITESITE_BUILD_AVIF_WEBP=1
"#;

pub const JUSTFILE: &str = r###"set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default: serve

build:
    litesite build

clean:
    litesite clean

serve:
    litesite serve

deploy:
    litesite deploy

compress:
    litesite compress

media:
    litesite media

new slug="":
    litesite new '{{slug}}'

init slug="":
    litesite init '{{slug}}'

jpg *files:
    litesite jpg {{files}}

webp *files:
    litesite webp {{files}}
"###;

pub const README_TEMPLATE: &str = r###"# __SITE_SLUG__

Boilerplate and command wrapper for tiny sites that do not need a framework.

## Layout

- Source lives in `src/`
- Publishable output goes in `dist/`
- Public files in `src/public/` are copied to `dist/public/`

## Development

```bash
litesite
litesite build
litesite deploy
```

Edit site content and assets under src/.
The public site files live in src/public/.
"###;

pub const LICENSE_TEMPLATE_START: &str = r#"ISC License

Copyright (c) "#;

pub const LICENSE_TEMPLATE_END: &str = r#"

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
"#;

pub const STYLE_CSS: &str = r#"/* @import url('https://unpkg.com/@remino/dress.css'); */

* {
	box-sizing: border-box;
}

:root {
	color-scheme: dark;
}

body {
	align-content: center;
	background: #000;
	color: #fff;
	margin: 0 auto;
	width: max-content;
	min-height: 100%;
	max-width: min(30rem, 100%);
}

html {
	font-family: system-ui, sans-serif;
	font-size: clamp(16px, 2vmin, 24px);
	height: 100%;
}
"#;

pub const MAIN_JS: &str = r###";(function () {
	'use strict'

	const main = () => {
		document.documentElement.classList.add('js')
	}

	main()
})()
"###;

pub const FAVICON_SVG: &str = r##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" role="img" aria-label="LiteSite">
  <rect width="128" height="128" rx="28" fill="#17120d" />
  <path d="M34 32h22v64H34z" fill="#f4efe6" />
  <path d="M58 32h12l24 64H82L58 32Z" fill="#2f5dff" />
  <circle cx="94" cy="96" r="12" fill="#f4efe6" />
</svg>
"##;

pub const SHARE_SVG: &str = r##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 630" role="img" aria-label="LiteSite share image">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#f6f1ea" />
      <stop offset="100%" stop-color="#e7d6be" />
    </linearGradient>
    <linearGradient id="accent" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#2f5dff" />
      <stop offset="100%" stop-color="#1639b9" />
    </linearGradient>
  </defs>
  <rect width="1200" height="630" fill="url(#bg)" />
  <circle cx="1030" cy="120" r="150" fill="#2f5dff" fill-opacity="0.12" />
  <circle cx="160" cy="500" r="220" fill="#17120d" fill-opacity="0.06" />
  <rect x="80" y="80" width="1040" height="470" rx="42" fill="#ffffff" fill-opacity="0.68" stroke="#17120d" stroke-opacity="0.1" />
  <text x="140" y="210" fill="#1639b9" font-family="Inter, Arial, sans-serif" font-size="28" font-weight="700" letter-spacing="6">LITESITE</text>
  <text x="140" y="320" fill="#17120d" font-family="Georgia, serif" font-size="82" font-weight="700">Small sites,</text>
  <text x="140" y="410" fill="#17120d" font-family="Georgia, serif" font-size="82" font-weight="700">less ceremony.</text>
  <rect x="140" y="454" width="280" height="18" rx="9" fill="url(#accent)" />
</svg>
"##;
