import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import {
	renderLandingPage,
	resolvePublishedApiRoot,
	resolvePublishedSiteRoot,
} from './docs.js'

describe('docs', () => {
	it('renders a landing page with a docs link and markdown content', () => {
		const html = renderLandingPage('# comprose\n\nCreate and import prose.')

		assert.match(html, /<link rel="stylesheet" href="\.\/dress\.css" \/>/)
		assert.match(html, /<header>/)
		assert.match(html, /<nav>/)
		assert.match(html, /<main id="main">/)
		assert.match(html, /<a href="\.\/docs\/">API documentation<\/a>/)
		assert.match(html, /<h1>comprose<\/h1>/)
		assert.match(html, /<p>Create and import prose\.<\/p>/)
	})

	it('resolves the published site and api paths under comprose', () => {
		assert.equal(
			resolvePublishedSiteRoot('/tmp/docs-worktree'),
			'/tmp/docs-worktree/comprose'
		)
		assert.equal(
			resolvePublishedApiRoot('/tmp/docs-worktree'),
			'/tmp/docs-worktree/comprose/docs'
		)
	})
})
