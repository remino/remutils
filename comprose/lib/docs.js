// @ts-check

/**
 * Docs-site build helpers for the README landing page and JSDoc output.
 *
 * @module lib/docs
 */

import { copyFile, mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import { spawnSync } from 'node:child_process'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { marked } from 'marked'

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const defaultDocsRoot = resolve(packageRoot, '..', 'docs')
const dressCssFile = join(
	packageRoot,
	'node_modules',
	'@remino',
	'dress.css',
	'dist',
	'dress.css'
)
const jsdocThemeRoot = join(packageRoot, 'jsdoc-theme')

/**
 * Resolve the docs worktree root.
 *
 * `COMPROSE_DOCS_ROOT` exists so tests and one-off dry runs can target a
 * temporary directory without touching the real publish worktree.
 *
 * @returns {string}
 */
export const resolveDocsRoot = () =>
	resolve(process.env.COMPROSE_DOCS_ROOT || defaultDocsRoot)

/**
 * Resolve the published site root inside the docs worktree.
 *
 * @param {string} docsRoot
 * @returns {string}
 */
export const resolvePublishedSiteRoot = docsRoot => join(docsRoot, 'comprose')

/**
 * Resolve the generated API docs root inside the published site.
 *
 * @param {string} docsRoot
 * @returns {string}
 */
export const resolvePublishedApiRoot = docsRoot =>
	join(resolvePublishedSiteRoot(docsRoot), 'docs')

/**
 * Resolve the local JSDoc theme root.
 *
 * @returns {string}
 */
export const resolveJSDocThemeRoot = () => jsdocThemeRoot

/**
 * Ensure the configured docs path is a `docs` branch worktree.
 *
 * The check can be bypassed for tests via `COMPROSE_SKIP_WORKTREE_CHECK=1`.
 *
 * @param {string} docsRoot
 * @returns {void}
 */
export const assertDocsWorktree = docsRoot => {
	if (process.env.COMPROSE_SKIP_WORKTREE_CHECK === '1') {
		return
	}

	const insideWorktree = spawnSync(
		'git',
		['-C', docsRoot, 'rev-parse', '--is-inside-work-tree'],
		{ encoding: 'utf8' }
	)

	if (
		insideWorktree.error ||
		insideWorktree.status !== 0 ||
		insideWorktree.stdout.trim() !== 'true'
	) {
		throw new Error(
			[
				`docs worktree not found at ${docsRoot}`,
				'expected a local worktree checked out from the orphan docs branch',
			].join(': ')
		)
	}

	const branch = spawnSync(
		'git',
		['-C', docsRoot, 'branch', '--show-current'],
		{
			encoding: 'utf8',
		}
	)

	if (branch.error || branch.status !== 0) {
		throw new Error(`failed to inspect docs worktree branch at ${docsRoot}`)
	}

	if (branch.stdout.trim() !== 'docs') {
		throw new Error(
			`docs worktree at ${docsRoot} is on branch "${branch.stdout.trim() || '(detached)'}", expected "docs"`
		)
	}
}

/**
 * Build the docs landing page HTML from the README body.
 *
 * @param {string} markdown
 * @returns {string}
 */
export const renderLandingPage = markdown => {
	const bodyHtml = marked.parse(markdown)

	return `<!doctype html>
<html lang="en">
<head>
	<meta charset="utf-8" />
	<meta name="viewport" content="width=device-width, initial-scale=1" />
	<title>comprose</title>
	<link rel="stylesheet" href="./dress.css" />
</head>
<body>
	<a href="#main">Skip to content</a>
	<header>
		<h1>comprose</h1>
		<nav>
			<ul>
				<li><a href="./docs/">API documentation</a></li>
				<li><a href="https://www.npmjs.com/package/@remino/comprose">npm package</a></li>
			</ul>
		</nav>
	</header>
	<main id="main">
		<article>
${bodyHtml}
		</article>
	</main>
	<footer>
		<small>Generated from README and JSDoc.</small>
	</footer>
</body>
</html>
`
}

/**
 * Write the README-based landing page into the published site root.
 *
 * @param {string} docsRoot
 * @returns {Promise<void>}
 */
export const writeLandingPage = async docsRoot => {
	const readme = await readFile(join(packageRoot, 'README.md'), 'utf8')
	const siteRoot = resolvePublishedSiteRoot(docsRoot)
	await mkdir(siteRoot, { recursive: true })
	await writeFile(join(siteRoot, 'index.html'), renderLandingPage(readme))
}

/**
 * Copy the vendored `dress.css` bundle into the published site root.
 *
 * @param {string} docsRoot
 * @returns {Promise<void>}
 */
export const copyDressCss = async docsRoot => {
	const siteRoot = resolvePublishedSiteRoot(docsRoot)
	await mkdir(siteRoot, { recursive: true })
	await copyFile(dressCssFile, join(siteRoot, 'dress.css'))
}

/**
 * Recreate the published site subtree for a fresh build.
 *
 * @param {string} docsRoot
 * @returns {Promise<void>}
 */
export const preparePublishedSite = async docsRoot => {
	const siteRoot = resolvePublishedSiteRoot(docsRoot)
	await rm(siteRoot, { force: true, recursive: true })
	await mkdir(resolvePublishedApiRoot(docsRoot), { recursive: true })
	await mkdir(dirname(siteRoot), { recursive: true })
	await writeFile(join(docsRoot, '.nojekyll'), '')
}

/**
 * Build the JSDoc API site into the published docs subtree.
 *
 * @param {string} docsRoot
 * @returns {void}
 */
export const buildApiDocs = docsRoot => {
	const result = spawnSync(
		'jsdoc',
		[
			'-c',
			join(packageRoot, 'jsdoc.config.json'),
			'-d',
			resolvePublishedApiRoot(docsRoot),
			'-t',
			resolveJSDocThemeRoot(),
		],
		{
			encoding: 'utf8',
			stdio: 'inherit',
		}
	)

	if (result.error) {
		throw result.error
	}

	if (result.status !== 0) {
		throw new Error(`jsdoc exited with status ${result.status ?? 'unknown'}`)
	}
}
