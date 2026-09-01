import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { mkdir, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import {
	collectReferencedImageFiles,
	resolveMarkdownMetadata,
	rewriteAssetReference,
	rewriteAssetReferences,
} from './markdown.js'
import { cleanupProjects, createProject } from './helpers.js'

describe('markdown', () => {
	it('rewrites inline and frontmatter asset references', () => {
		const assetMap = new Map([
			['image.jpg', '/journal/example/image.avif'],
			['image', '/journal/example/image.avif'],
		])

		assert.equal(
			rewriteAssetReference('image.jpg', assetMap),
			'/journal/example/image.avif'
		)
		assert.match(
			rewriteAssetReferences('![Alt](image.jpg)', assetMap),
			/\(\/journal\/example\/image\.avif\)/
		)
	})

	it('collects referenced image files from markdown and frontmatter', () => {
		const sourceFiles = new Map([
			['image.jpg', 'image.jpg'],
			['share.png', 'share.png'],
			['note.md', 'note.md'],
		])
		const body = '![Hero](image.jpg)\n\n[share]: share.png'

		assert.deepEqual(
			collectReferencedImageFiles(body, ['share.png'], sourceFiles),
			['share.png', 'image.jpg']
		)
	})

	it('reads markdown metadata from a source directory', async t => {
		t.after(cleanupProjects)
		const dir = await createProject('markdown')
		await mkdir(join(dir, 'source-entry'), { recursive: true })
		await writeFile(
			join(dir, 'source-entry', 'entry.md'),
			`---
title: Imported Entry
date: 2026-05-06T08:30:00+09:00
tags: notes, journal
---

Body
`
		)

		const metadata = await resolveMarkdownMetadata(join(dir, 'source-entry'))

		assert.equal(metadata.title, 'Imported Entry')
		assert.equal(metadata.slug, 'imported-entry')
		assert.equal(metadata.type, 'article')
		assert.match(metadata.body, /Body/)
	})
})
