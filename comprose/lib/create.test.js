import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { afterEach, describe, it } from 'node:test'
import assert from 'node:assert/strict'
import {
	cleanupProjects,
	createProject,
	importFresh,
	withStdinTty,
} from './helpers.js'

afterEach(cleanupProjects)

describe('create', () => {
	it('creates files through the createEntry workflow', async () => {
		const dir = await createProject('create')
		const imagePath = join(dir, 'image.png')
		await writeFile(imagePath, 'png\n')

		const { resolveConfig } = await importFresh('./templates.js', dir)
		const { createEntry } = await importFresh('./create.js', dir)
		const config = await resolveConfig({
			collection: 'journal',
			pubname: 'example-journal',
		})
		const failures = []
		const usageCalls = []

		await withStdinTty(async () => {
			await createEntry(
				config,
				{
					date: {
						fileDate: '2026-07-23',
						frontmatterDate: '2026-07-23T10:00:00+09:00',
						parsed: new Date('2026-07-23T10:00:00+09:00'),
					},
					edit: false,
					imagePaths: [imagePath],
					openFolder: false,
					slugParts: ['hello-entry'],
					tags: ['terminal, css'],
					titleParts: ['Hello Entry'],
					type: 'article',
				},
				{
					fail: message => failures.push(message),
					usage: () => usageCalls.push('usage'),
				}
			)
		})

		assert.deepEqual(failures, [])
		assert.deepEqual(usageCalls, [])
		const content = await readFile(
			join(dir, 'src/content/journal/2026-07-23-hello-entry/index.md'),
			'utf8'
		)
		const style = await readFile(
			join(dir, 'src/styles/journal/hello-entry.css'),
			'utf8'
		)
		const image = await readFile(
			join(dir, 'public/journal/hello-entry/image.png')
		)

		assert.match(content, /^title: Hello Entry$/m)
		assert.match(content, /^pubname: example-journal$/m)
		assert.match(style, /hello-entry/)
		assert.equal(image.toString(), 'png\n')
	})
})
