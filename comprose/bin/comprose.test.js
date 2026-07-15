import { execFileSync } from 'node:child_process'
import { mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { afterEach, describe, it } from 'node:test'
import assert from 'node:assert/strict'

const toolRoot = resolve(import.meta.dirname, '..')
const command = join(toolRoot, 'comprose')
const cleanupPaths = []

afterEach(async () => {
	while (cleanupPaths.length > 0) {
		await rm(cleanupPaths.pop(), { force: true, recursive: true })
	}
})

const createProject = async (name = 'site') => {
	const dir = await mkdtemp(join(tmpdir(), `comprose-${name}-`))
	cleanupPaths.push(dir)

	return dir
}

const runComprose = (cwd, args, options = {}) =>
	execFileSync(command, args, {
		cwd,
		encoding: 'utf8',
		...options,
	})

const runComproseExpectFailure = (cwd, args) => {
	try {
		runComprose(cwd, args)
	} catch (error) {
		return error
	}

	throw new Error('expected comprose to fail')
}

describe('comprose new', () => {
	it('creates a project-scoped article from title, tags, and stdin', async () => {
		const projectDir = await createProject()

		const output = runComprose(
			projectDir,
			[
				'new',
				'-p',
				'journal',
				'--pubname',
				'example-journal',
				'-d',
				'2026-05-06',
				'-t',
				'Hello Entry',
				'-g',
				'terminal, css',
				'-g',
				'css',
			],
			{
				input: 'Body from stdin.\n',
			}
		)

		assert.match(output, /Created 2026-05-06-hello-entry/)

		const content = await readFile(
			join(projectDir, 'src/content/journal/2026-05-06-hello-entry/index.md'),
			'utf8'
		)
		const style = await readFile(
			join(projectDir, 'src/styles/journal/hello-entry.css'),
			'utf8'
		)
		const publicFiles = await readdir(
			join(projectDir, 'public/journal/hello-entry')
		)

		assert.match(content, /^pubname: example-journal$/m)
		assert.match(content, /^title: Hello Entry$/m)
		assert.match(content, /^style: journal\/hello-entry\.css$/m)
		assert.match(content, /^tags: terminal, css$/m)
		assert.match(content, /Body from stdin\./)
		assert.match(style, /Add styles for hello-entry/)
		assert.deepEqual(publicFiles, [])
	})

	it('infers pubname from a reverse-DNS package name', async () => {
		const projectDir = await createProject()

		await writeFile(
			join(projectDir, 'package.json'),
			JSON.stringify({ name: 'com.example.notes' })
		)

		runComprose(projectDir, [
			'new',
			'-p',
			'notes',
			'-d',
			'2026-05-06',
			'-s',
			'inferred-entry',
		])

		const content = await readFile(
			join(projectDir, 'src/content/notes/2026-05-06-inferred-entry/index.md'),
			'utf8'
		)

		assert.match(content, /^pubname: example-notes$/m)
		assert.match(content, /^style: notes\/inferred-entry\.css$/m)
	})

	it('supports explicit style and image destinations', async () => {
		const projectDir = await createProject()
		const imagePath = join(projectDir, 'source.png')

		await writeFile(imagePath, 'not a real png, but new only copies images\n')

		runComprose(projectDir, [
			'new',
			'-p',
			'journal',
			'-d',
			'2026-05-06',
			'-s',
			'custom-paths',
			'--styles-root',
			'assets/css/journal',
			'--style-prefix',
			'assets/css/journal',
			'--images-root',
			'assets/img/journal',
			'--images-prefix',
			'/assets/img/journal',
			'-i',
			imagePath,
		])

		const content = await readFile(
			join(projectDir, 'src/content/journal/2026-05-06-custom-paths/index.md'),
			'utf8'
		)
		const style = await readFile(
			join(projectDir, 'assets/css/journal/custom-paths.css'),
			'utf8'
		)
		const image = await readFile(
			join(projectDir, 'assets/img/journal/custom-paths/source.png'),
			'utf8'
		)

		assert.match(content, /^style: assets\/css\/journal\/custom-paths\.css$/m)
		assert.match(
			content,
			/^image: \/assets\/img\/journal\/custom-paths\/source\.png$/m
		)
		assert.match(style, /Add styles for custom-paths/)
		assert.equal(image, 'not a real png, but new only copies images\n')
	})

	it('supports explicitly selecting the default Astro content template', async () => {
		const projectDir = await createProject()

		runComprose(projectDir, [
			'new',
			'--template',
			'astro-content',
			'-p',
			'journal',
			'-d',
			'2026-05-06',
			'-s',
			'explicit-template',
		])

		const content = await readFile(
			join(
				projectDir,
				'src/content/journal/2026-05-06-explicit-template/index.md'
			),
			'utf8'
		)

		assert.match(content, /^pubname: journal$/m)
		assert.match(content, /^style: journal\/explicit-template\.css$/m)
	})

	it('creates Middleman blog entries without Astro directories', async () => {
		const projectDir = await createProject()
		const imagePath = join(projectDir, 'source.avif')

		await writeFile(imagePath, 'fake avif payload\n')

		const output = runComprose(projectDir, [
			'new',
			'--template',
			'middleman-blog',
			'--content-root',
			'source/posts',
			'-d',
			'2026-05-06',
			'-t',
			'Middleman Entry',
			'-i',
			imagePath,
		])

		assert.match(output, /Created middleman-entry/)

		const content = await readFile(
			join(projectDir, 'source/posts/middleman-entry.html.md'),
			'utf8'
		)
		const image = await readFile(
			join(projectDir, 'source/posts/middleman-entry/source.avif'),
			'utf8'
		)

		assert.match(content, /^title: Middleman Entry$/m)
		assert.match(content, /^date: 2026-05-06$/m)
		assert.doesNotMatch(content, /^pubname:/m)
		assert.doesNotMatch(content, /^type:/m)
		assert.doesNotMatch(content, /^catname:/m)
		assert.equal(image, 'fake avif payload\n')

		await assert.rejects(
			readFile(
				join(
					projectDir,
					'src/content/posts/2026-05-06-middleman-entry/index.md'
				),
				'utf8'
			)
		)
	})
})

describe('comprose import', () => {
	it('imports markdown, style.css, and project-specific frontmatter fields', async () => {
		const projectDir = await createProject()
		const sourceDir = await mkdtemp(join(tmpdir(), 'comprose-source-'))
		cleanupPaths.push(sourceDir)

		await writeFile(
			join(sourceDir, 'note.md'),
			[
				'---',
				'date: 2026-05-28',
				'kicker: Dispatch',
				'deck: Short deck',
				'draft: true',
				'tags: travel, place',
				'---',
				'',
				'# Imported Note',
				'',
				'Body text.',
				'',
			].join('\n')
		)
		await writeFile(join(sourceDir, 'style.css'), 'article { color: red; }\n')

		const output = runComprose(projectDir, [
			'import',
			'-p',
			'notes',
			'--pubname',
			'field-notes',
			sourceDir,
		])

		assert.match(output, /Imported 2026-05-28-imported-note/)

		const content = await readFile(
			join(projectDir, 'src/content/notes/2026-05-28-imported-note/index.md'),
			'utf8'
		)
		const style = await readFile(
			join(projectDir, 'src/styles/notes/imported-note.css'),
			'utf8'
		)

		assert.match(content, /^pubname: field-notes$/m)
		assert.match(content, /^type: note$/m)
		assert.match(content, /^kicker: Dispatch$/m)
		assert.match(content, /^deck: Short deck$/m)
		assert.match(content, /^draft: true$/m)
		assert.match(content, /^style: notes\/imported-note\.css$/m)
		assert.doesNotMatch(content, /^# Imported Note$/m)
		assert.match(content, /Body text\./)
		assert.equal(style, 'article { color: red; }\n')
	})

	it('fails with exit code 12 rather than replacing an existing import', async () => {
		const projectDir = await createProject()
		const sourceDir = await mkdtemp(join(tmpdir(), 'comprose-source-'))
		cleanupPaths.push(sourceDir)

		await writeFile(
			join(sourceDir, 'post.md'),
			'---\ndate: 2026-05-28\n---\n\n# Conflict Entry\n\nBody.\n'
		)

		runComprose(projectDir, ['import', '-p', 'journal', sourceDir])
		const error = runComproseExpectFailure(projectDir, [
			'import',
			'-p',
			'journal',
			sourceDir,
		])

		assert.equal(error.status, 12)
		assert.match(String(error.stderr), /import would overwrite existing entry/)
	})

	it('imports Middleman blog entries and rewrites assets relatively', async () => {
		const projectDir = await createProject()
		const sourceDir = await mkdtemp(join(tmpdir(), 'comprose-source-'))
		cleanupPaths.push(sourceDir)

		await writeFile(
			join(sourceDir, 'post.md'),
			[
				'---',
				'date: 2026-05-28',
				'original_date: 2020-01-02',
				'share_image: share.avif',
				'---',
				'',
				'# Imported Middleman',
				'',
				'![Image](image.avif#?large)',
				'',
			].join('\n')
		)
		await writeFile(join(sourceDir, 'image.avif'), 'fake image\n')
		await writeFile(join(sourceDir, 'share.avif'), 'fake share\n')

		const output = runComprose(projectDir, [
			'import',
			'--template',
			'middleman-blog',
			'--content-root',
			'source/posts',
			sourceDir,
		])

		assert.match(output, /Imported imported-middleman/)

		const content = await readFile(
			join(projectDir, 'source/posts/imported-middleman.html.md'),
			'utf8'
		)
		const image = await readFile(
			join(projectDir, 'source/posts/imported-middleman/image.avif'),
			'utf8'
		)
		const share = await readFile(
			join(projectDir, 'source/posts/imported-middleman/share.avif'),
			'utf8'
		)

		assert.match(content, /^title: Imported Middleman$/m)
		assert.match(content, /^date: 2026-05-28$/m)
		assert.match(content, /^original_date: 2020-01-02$/m)
		assert.match(content, /^share_image: share.avif$/m)
		assert.match(content, /!\[Image\]\(image\.avif\)/)
		assert.doesNotMatch(content, /^# Imported Middleman$/m)
		assert.doesNotMatch(content, /^pubname:/m)
		assert.equal(image, 'fake image\n')
		assert.equal(share, 'fake share\n')
	})

	it('fails with exit code 12 for existing Middleman blog imports', async () => {
		const projectDir = await createProject()
		const sourceDir = await mkdtemp(join(tmpdir(), 'comprose-source-'))
		cleanupPaths.push(sourceDir)

		await writeFile(
			join(sourceDir, 'post.md'),
			'---\ndate: 2026-05-28\n---\n\n# Middleman Conflict\n\nBody.\n'
		)

		const args = [
			'import',
			'--template',
			'middleman-blog',
			'--content-root',
			'source/posts',
			sourceDir,
		]

		runComprose(projectDir, args)
		const error = runComproseExpectFailure(projectDir, args)

		assert.equal(error.status, 12)
		assert.match(String(error.stderr), /import would overwrite existing entry/)
	})
})
