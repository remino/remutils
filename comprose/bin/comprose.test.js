import { execFileSync } from 'node:child_process'
import {
	mkdir,
	mkdtemp,
	readFile,
	readdir,
	rm,
	writeFile,
} from 'node:fs/promises'
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
		env: {
			...process.env,
			...options.env,
		},
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
				'-c',
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
			'-c',
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

	it('supports custom template directory paths', async () => {
		const projectDir = await createProject()
		const imagePath = join(projectDir, 'source.png')
		const templateDir = join(projectDir, 'my-template')

		await writeFile(imagePath, 'not a real png, but new only copies images\n')
		await mkdir(join(templateDir, 'content/[collection]/[slug]'), {
			recursive: true,
		})
		await mkdir(join(templateDir, 'assets/[collection]/[slug]'), {
			recursive: true,
		})
		await writeFile(
			join(templateDir, 'content/[collection]/[slug]/entry.md.mustache'),
			'---\ntitle: {{{title}}}\n{{#hasImage}}image: {{{image}}}\n{{/hasImage}}---\n\n{{{body}}}'
		)
		await writeFile(
			join(templateDir, 'assets/[collection]/[slug]/.comprose-assets'),
			'assets\n'
		)

		runComprose(projectDir, [
			'new',
			'--template',
			'my-template',
			'-c',
			'journal',
			'-d',
			'2026-05-06',
			'-s',
			'custom-paths',
			'-i',
			imagePath,
		])

		const content = await readFile(
			join(projectDir, 'content/journal/custom-paths/entry.md'),
			'utf8'
		)
		const image = await readFile(
			join(projectDir, 'assets/journal/custom-paths/source.png'),
			'utf8'
		)

		assert.match(content, /^title: Custom Paths$/m)
		assert.match(content, /^image: source\.png$/m)
		assert.equal(image, 'not a real png, but new only copies images\n')
	})

	it('finds templates in parent .comprose/templates directories', async () => {
		const projectDir = await createProject()
		const nestedDir = join(projectDir, 'sites/example')
		const templateDir = join(projectDir, '.comprose/templates/local-blog')

		await mkdir(join(nestedDir), { recursive: true })
		await mkdir(join(templateDir, 'entries/[collection]/[slug]'), {
			recursive: true,
		})
		await writeFile(
			join(templateDir, 'entries/[collection]/[slug]/index.md.mustache'),
			'---\ntitle: {{{title}}}\n---\n\n{{{body}}}'
		)

		runComprose(nestedDir, [
			'new',
			'--template',
			'local-blog',
			'-c',
			'posts',
			'-t',
			'Parent Template',
		])

		const content = await readFile(
			join(nestedDir, 'entries/posts/parent-template/index.md'),
			'utf8'
		)

		assert.match(content, /^title: Parent Template$/m)
	})

	it('finds templates in parent .config/comprose/templates directories', async () => {
		const projectDir = await createProject()
		const nestedDir = join(projectDir, 'sites/example')
		const templateDir = join(
			projectDir,
			'.config/comprose/templates/project-config-blog'
		)

		await mkdir(join(nestedDir), { recursive: true })
		await mkdir(join(templateDir, 'pages/[collection]'), {
			recursive: true,
		})
		await writeFile(
			join(templateDir, 'pages/[collection]/[slug].md.mustache'),
			'---\ntitle: {{{title}}}\n---\n'
		)

		runComprose(nestedDir, [
			'new',
			'--template',
			'project-config-blog',
			'-c',
			'posts',
			'-t',
			'Parent Config Template',
		])

		const content = await readFile(
			join(nestedDir, 'pages/posts/parent-config-template.md'),
			'utf8'
		)

		assert.match(content, /^title: Parent Config Template$/m)
	})

	it('finds templates in XDG_CONFIG_HOME comprose/templates', async () => {
		const projectDir = await createProject()
		const configDir = await mkdtemp(join(tmpdir(), 'comprose-config-'))
		const templateDir = join(configDir, 'comprose/templates/config-blog')
		cleanupPaths.push(configDir)

		await mkdir(join(templateDir, 'entries/[collection]'), {
			recursive: true,
		})
		await writeFile(
			join(templateDir, 'entries/[collection]/[slug].md.mustache'),
			'---\ntitle: {{{title}}}\n---\n'
		)

		runComprose(
			projectDir,
			[
				'new',
				'--template',
				'config-blog',
				'-c',
				'posts',
				'-t',
				'Config Template',
			],
			{
				env: {
					XDG_CONFIG_HOME: configDir,
				},
			}
		)

		const content = await readFile(
			join(projectDir, 'entries/posts/config-template.md'),
			'utf8'
		)

		assert.match(content, /^title: Config Template$/m)
	})

	it('falls back to HOME .config comprose/templates', async () => {
		const projectDir = await createProject()
		const homeDir = await mkdtemp(join(tmpdir(), 'comprose-home-'))
		const templateDir = join(homeDir, '.config/comprose/templates/home-blog')
		cleanupPaths.push(homeDir)

		await mkdir(join(templateDir, 'notes/[slug]'), {
			recursive: true,
		})
		await writeFile(
			join(templateDir, 'notes/[slug]/index.md.mustache'),
			'---\ntitle: {{{title}}}\n---\n'
		)

		runComprose(
			projectDir,
			['new', '--template', 'home-blog', '-t', 'Home Template'],
			{
				env: {
					HOME: homeDir,
					XDG_CONFIG_HOME: '',
				},
			}
		)

		const content = await readFile(
			join(projectDir, 'notes/home-template/index.md'),
			'utf8'
		)

		assert.match(content, /^title: Home Template$/m)
	})

	it('supports explicitly selecting the default Astro content template', async () => {
		const projectDir = await createProject()

		runComprose(projectDir, [
			'new',
			'--template',
			'astro-content',
			'-c',
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
			'-c',
			'posts',
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
			'-c',
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

		runComprose(projectDir, ['import', '-c', 'journal', sourceDir])
		const error = runComproseExpectFailure(projectDir, [
			'import',
			'-c',
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
			'-c',
			'posts',
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
			'-c',
			'posts',
			sourceDir,
		]

		runComprose(projectDir, args)
		const error = runComproseExpectFailure(projectDir, args)

		assert.equal(error.status, 12)
		assert.match(String(error.stderr), /import would overwrite existing entry/)
	})
})
