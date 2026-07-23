import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { basename, join } from 'node:path'
import { afterEach, describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { cleanupProjects, createProject, importFresh } from './helpers.js'

afterEach(cleanupProjects)

describe('templates', () => {
	it('resolves built-in and parent templates and builds a template plan', async () => {
		const dir = await createProject('template-parent')
		const nestedDir = join(dir, 'sites/example')
		const templateDir = join(dir, '.comprose/templates/local')
		await mkdir(join(nestedDir), { recursive: true })
		await mkdir(join(templateDir, 'content/[collection]/[slug]'), {
			recursive: true,
		})
		await mkdir(join(templateDir, 'assets/[collection]/[slug]'), {
			recursive: true,
		})
		await writeFile(
			join(templateDir, 'content/[collection]/[slug]/entry.md.mustache'),
			'---\ntitle: {{{title}}}\n---\n'
		)
		await writeFile(
			join(templateDir, 'assets/[collection]/[slug]/.comprose-assets'),
			'assets\n'
		)

		const {
			resolveTemplate,
			buildTemplatePlan,
			writeTemplateFiles,
			templateContext,
		} = await importFresh('./templates.js', nestedDir)

		const defaultTemplate = await resolveTemplate()
		assert.equal(defaultTemplate.name, 'default')
		assert.equal(basename(defaultTemplate.dir), 'default')

		const template = await resolveTemplate('local')
		const config = {
			collection: 'journal',
			project: 'journal',
			pubname: 'journal',
			template,
		}
		const paths = await buildTemplatePlan(config, {
			collection: 'journal',
			date: '2026-07-23',
			dateString: '2026-07-23',
			slug: 'entry',
		})

		assert.match(paths.entryPath, /content\/journal\/entry\/entry\.md$/)
		assert.match(paths.assetDir, /assets\/journal\/entry$/)

		await writeTemplateFiles(
			paths,
			templateContext({
				body: 'Body',
				config,
				date: '2026-07-23',
				frontmatterDate: '2026-07-23T00:00:00+09:00',
				paths,
				slug: 'entry',
				title: 'Entry',
			})
		)

		const content = await readFile(paths.entryPath, 'utf8')
		assert.match(content, /^title: Entry$/m)
	})
})
