import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { afterEach, describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { cleanupProjects, createProject, importFresh } from './helpers.js'

afterEach(cleanupProjects)

describe('import', () => {
	it('imports a source directory through the importDirectory workflow', async () => {
		const dir = await createProject('import')
		const sourceDir = join(dir, 'source-entry')
		await mkdir(sourceDir, { recursive: true })
		await writeFile(
			join(sourceDir, 'entry.md'),
			`---
title: Imported Entry
date: 2026-05-06T08:30:00+09:00
image: image.avif
---

Body with ![Hero](image.avif)
`
		)
		await writeFile(join(sourceDir, 'style.css'), 'body { color: red; }\n')
		await writeFile(join(sourceDir, 'image.avif'), 'fake image data\n')

		const { resolveConfig } = await importFresh('./templates.js', dir)
		const { importDirectory } = await importFresh('./import.js', dir)
		const config = await resolveConfig({
			collection: 'journal',
			template: 'middleman-blog',
		})
		const failures = []

		await importDirectory(
			config,
			'source-entry',
			{ edit: false, force: false, openFolder: false },
			{ fail: message => failures.push(message) }
		)

		assert.deepEqual(failures, [])
		const content = await readFile(
			join(dir, 'source/journal/imported-entry.html.md'),
			'utf8'
		)
		const image = await readFile(
			join(dir, 'source/journal/imported-entry/image.avif'),
			'utf8'
		)

		assert.match(content, /^title: Imported Entry$/m)
		assert.match(content, /Body with !\[Hero\]\(image\.avif\)/)
		assert.equal(image, 'fake image data\n')
	})
})
