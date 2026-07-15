#!/usr/bin/env node

import {
	access,
	copyFile,
	mkdir,
	readFile,
	readdir,
	rm,
	writeFile,
} from 'node:fs/promises'
import { spawnSync } from 'node:child_process'
import { basename, dirname, extname, join, resolve } from 'node:path'
import { once } from 'node:events'
import { fileURLToPath } from 'node:url'
import sharp from 'sharp'

const repoRoot = process.cwd()
const defaultSlugTitleFiles = new Set(['entry', 'note', 'article', 'post'])
const EXIT_IMPORT_CONFLICT = 12
const supportedImageExtensions = new Set([
	'.avif',
	'.gif',
	'.heic',
	'.heif',
	'.jpeg',
	'.jpg',
	'.png',
	'.webp',
])

const usage = () => {
	console.log(`Usage:
  comprose help
  comprose new [options] [-s <slug>] [-t <title>]
  comprose import [options] <path>

Commands:
  help    Show this usage screen.
  new     Create a new content entry scaffold.
  import  Import a directory into a new content entry.

Content options:
  -s <slug>       Entry slug.
  -t <title>      Entry title.
  -d <iso-8601>   Date in ISO 8601 (date only, date-time, or date-time with offset).
  -k, --type, --kind <kind>
                  Entry type: article or note. Defaults to article.
  -g <tag>        Tag to add to frontmatter. Repeatable.
  -i <path>       Image file to copy into the entry public folder. Repeatable.
  -e              Open created text files in $EDITOR after scaffolding.
  -o              Open the public folder in Finder after scaffolding.
  -f              Reimport and replace an existing generated entry.

Project options:
  -p, --project <name>
                  Content section name. Defaults to the current directory name.
  --pubname <name>
                  Frontmatter pubname. Defaults to package.json name when it looks like reverse DNS, otherwise the project name.
  --content-root <path>
                  Content root. Defaults to src/content/<project>.
  --styles-root <path>
                  Styles root. Defaults to src/styles/<project>.
  --public-root <path>
                  Public asset root. Defaults to public/<project>.
  --images-root <path>
                  Alias for --public-root.
  --public-prefix <path>
                  Public URL prefix. Defaults to /<project>.
  --images-prefix <path>
                  Alias for --public-prefix.
  --style-prefix <path>
                  Style frontmatter prefix. Defaults to <project>.

stdin            Seed the entry body from piped input.

One of -s or -t is required for new entries.

Examples:
  comprose new -p journal --pubname example-journal -s my-new-entry
  comprose new -p notes --pubname field-notes -t "My New Entry"
  comprose new -p journal -d 2026-05-06T14:30+09:00 -k note -g terminal
  comprose import -p journal --pubname example-journal /tmp/source-entry
  comprose import -p notes --pubname field-notes /tmp/source-entry -f
`)
}

const fail = (message, exitCode = 1) => {
	console.error(`error: ${message}`)
	process.exitCode = exitCode
}

const parseArgs = argv => {
	const args = {
		command: undefined,
		slugParts: [],
		titleParts: [],
		date: undefined,
		type: 'article',
		tags: [],
		imagePaths: [],
		edit: false,
		openFolder: false,
		force: false,
		sourceDir: undefined,
		project: undefined,
		pubname: undefined,
		contentRoot: undefined,
		stylesRoot: undefined,
		publicRoot: undefined,
		publicPrefix: undefined,
		stylePrefix: undefined,
	}

	if (argv.length === 0) {
		return args
	}

	args.command = argv[0]

	for (let index = 1; index < argv.length; index += 1) {
		const token = argv[index]
		const nextValue = option => {
			const value = argv[++index]
			if (!value) {
				throw new Error(`missing value for ${option}`)
			}
			return value
		}

		if (token === '-s') {
			args.slugParts.push(nextValue(token))
			continue
		}

		if (token === '-t') {
			args.titleParts.push(nextValue(token))
			continue
		}

		if (token === '-d') {
			args.date = parseDateInput(nextValue(token))
			continue
		}

		if (token === '-k' || token === '--type' || token === '--kind') {
			const value = nextValue(token)
			const normalizedType = value.trim().toLowerCase()
			if (!['article', 'note'].includes(normalizedType)) {
				throw new Error(`invalid entry type "${value}"`)
			}

			args.type = normalizedType
			continue
		}

		if (token === '-g') {
			args.tags.push(nextValue(token))
			continue
		}

		if (token === '-i') {
			args.imagePaths.push(nextValue(token))
			continue
		}

		if (token === '-e') {
			args.edit = true
			continue
		}

		if (token === '-o') {
			args.openFolder = true
			continue
		}

		if (token === '-f') {
			args.force = true
			continue
		}

		if (token === '-p' || token === '--project') {
			args.project = normalizeProject(nextValue(token))
			continue
		}

		if (token === '--pubname') {
			args.pubname = nextValue(token).trim()
			continue
		}

		if (token === '--content-root') {
			args.contentRoot = nextValue(token)
			continue
		}

		if (token === '--styles-root') {
			args.stylesRoot = nextValue(token)
			continue
		}

		if (token === '--public-root' || token === '--images-root') {
			args.publicRoot = nextValue(token)
			continue
		}

		if (token === '--public-prefix' || token === '--images-prefix') {
			args.publicPrefix = normalizePublicPrefix(nextValue(token))
			continue
		}

		if (token === '--style-prefix') {
			args.stylePrefix = nextValue(token).replace(/^\/+|\/+$/g, '')
			continue
		}

		if (token.startsWith('-')) {
			throw new Error(`unknown option "${token}"`)
		}

		if (args.command === 'import') {
			if (args.sourceDir) {
				throw new Error('import accepts only one directory path')
			}

			args.sourceDir = token
			continue
		}

		args.slugParts.push(token)
	}

	return args
}

const dateOnlyPattern = /^(\d{4})-(\d{2})-(\d{2})$/
const dateTimePattern =
	/^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?(Z|[+-]\d{2}:\d{2})?$/

const getCurrentOffset = date => -date.getTimezoneOffset()

const formatOffset = offsetMinutes => {
	const sign = offsetMinutes >= 0 ? '+' : '-'
	const absoluteMinutes = Math.abs(offsetMinutes)
	const hours = String(Math.floor(absoluteMinutes / 60)).padStart(2, '0')
	const minutes = String(absoluteMinutes % 60).padStart(2, '0')

	return `${sign}${hours}:${minutes}`
}

const formatLocalIso = (date, offsetMinutes = getCurrentOffset(date)) => {
	const localDate = new Date(date.getTime() + offsetMinutes * 60_000)
	const year = localDate.getUTCFullYear()
	const month = String(localDate.getUTCMonth() + 1).padStart(2, '0')
	const day = String(localDate.getUTCDate()).padStart(2, '0')
	const hours = String(localDate.getUTCHours()).padStart(2, '0')
	const minutes = String(localDate.getUTCMinutes()).padStart(2, '0')
	const seconds = String(localDate.getUTCSeconds()).padStart(2, '0')

	return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}${formatOffset(offsetMinutes)}`
}

const parseDateInput = (value, now = new Date()) => {
	const trimmed = value.trim()
	const dateOnlyMatch = trimmed.match(dateOnlyPattern)
	const dateTimeMatch = trimmed.match(dateTimePattern)

	if (!dateOnlyMatch && !dateTimeMatch) {
		throw new Error(`invalid ISO 8601 date "${value}"`)
	}

	if (dateOnlyMatch) {
		const parsed = new Date(now)
		const offsetMinutes = getCurrentOffset(now)

		return {
			input: trimmed,
			parsed,
			fileDate: trimmed,
			frontmatterDate: formatLocalIso(parsed, offsetMinutes),
		}
	}

	const fileDate = `${dateTimeMatch[1]}-${dateTimeMatch[2]}-${dateTimeMatch[3]}`
	const hasOffset = Boolean(dateTimeMatch[8])
	const year = Number(dateTimeMatch[1])
	const month = Number(dateTimeMatch[2])
	const day = Number(dateTimeMatch[3])
	const hours = Number(dateTimeMatch[4])
	const minutes = Number(dateTimeMatch[5])
	const seconds = Number(dateTimeMatch[6] ?? '0')
	const milliseconds = Number((dateTimeMatch[7] ?? '0').padEnd(3, '0'))
	const offsetMinutes = getCurrentOffset(now)
	const parsed = hasOffset
		? new Date(trimmed)
		: new Date(
				Date.UTC(year, month - 1, day, hours, minutes, seconds, milliseconds) -
					offsetMinutes * 60_000
			)

	if (Number.isNaN(parsed.valueOf())) {
		throw new Error(`invalid ISO 8601 date "${value}"`)
	}

	return {
		input: trimmed,
		parsed,
		fileDate,
		frontmatterDate: hasOffset
			? trimmed
			: formatLocalIso(parsed, offsetMinutes),
	}
}

const stripDiacritics = value =>
	value.normalize('NFKD').replace(/[\u0300-\u036f]/g, '')

const normalizeSlug = value =>
	stripDiacritics(value)
		.replace(/[_\s]+/g, '-')
		.replace(/[^a-zA-Z0-9-]+/g, '-')
		.replace(/-+/g, '-')
		.replace(/^-|-$/g, '')
		.toLowerCase()

const normalizeProject = value => {
	const project = normalizeSlug(value)
	if (!project) {
		throw new Error(`project "${value}" normalised to an empty value`)
	}

	return project
}

const normalizePublicPrefix = value => {
	const trimmed = value.trim().replace(/\/+$/g, '')

	if (!trimmed || trimmed === '/') {
		return ''
	}

	return trimmed.startsWith('/') ? trimmed : `/${trimmed}`
}

const humanizeSlug = slug =>
	slug
		.split('-')
		.filter(Boolean)
		.map(part => part.charAt(0).toUpperCase() + part.slice(1))
		.join(' ')

const pad2 = value => String(value).padStart(2, '0')

const toLocalDateString = date =>
	`${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`

const isMarkdownFile = name => {
	const lowerName = name.toLowerCase()

	return lowerName.endsWith('.md') || lowerName.endsWith('.markdown')
}

const isSupportedImageFile = name =>
	supportedImageExtensions.has(extname(name).toLowerCase())

const quoteShellArg = value => `'${value.replace(/'/g, `'\\''`)}'`

const normalizeTagList = values => [
	...new Set(
		values
			.flatMap(value => value.split(','))
			.map(value => value.trim())
			.filter(Boolean)
	),
]

const uniqueAssetName = (name, existingNames) => {
	if (!existingNames.has(name)) {
		existingNames.add(name)
		return name
	}

	const extension = extname(name)
	const stem = name.slice(0, name.length - extension.length)
	let index = 2
	let candidate = `${stem}-${index}${extension}`

	while (existingNames.has(candidate)) {
		index += 1
		candidate = `${stem}-${index}${extension}`
	}

	existingNames.add(candidate)
	return candidate
}

const uniqueName = (name, existingNames) => {
	if (existingNames.has(name)) {
		throw new Error(`duplicate output asset name "${name}"`)
	}

	existingNames.add(name)
	return name
}

const frontmatter = source => {
	const match = source.match(/^---\n([\s\S]*?)\n---(?:\n|$)/)

	return match?.[1] ?? ''
}

const unquoteYamlString = value => {
	if (value.startsWith("'") && value.endsWith("'")) {
		return value.slice(1, -1).replace(/''/g, "'")
	}

	if (value.startsWith('"') && value.endsWith('"')) {
		return value.slice(1, -1).replace(/\\"/g, '"')
	}

	return value
}

const frontmatterString = (source, key) => {
	const match = frontmatter(source).match(
		new RegExp(`^${key}:\\s*(.+?)\\s*$`, 'm')
	)

	return match ? unquoteYamlString(match[1]) : undefined
}

const frontmatterBoolean = (source, key) => {
	const value = frontmatterString(source, key)

	if (value === undefined) {
		return undefined
	}

	if (/^(true|false)$/i.test(value)) {
		return value.toLowerCase() === 'true'
	}

	return undefined
}

const stripFrontmatter = source =>
	source.replace(/^---\n[\s\S]*?\n---(?:\n|$)/, '')

const stripFirstHeading = source => {
	const lines = source.split('\n')
	let inCodeFence = false

	for (let index = 0; index < lines.length; index += 1) {
		const line = lines[index]
		const fenceMatch = line.match(/^\s*(`{3,}|~{3,})/)

		if (fenceMatch) {
			inCodeFence = !inCodeFence
			continue
		}

		if (inCodeFence) {
			continue
		}

		const headingMatch = line.match(/^\s*#\s+(.+?)\s*#*\s*$/)
		if (!headingMatch) {
			continue
		}

		const title = headingMatch[1].trim()
		const bodyLines = [...lines.slice(0, index), ...lines.slice(index + 1)]

		if (bodyLines[0]?.trim() === '') {
			bodyLines.shift()
		}

		if (bodyLines[0]?.trim() === '') {
			bodyLines.shift()
		}

		return {
			body: bodyLines.join('\n'),
			title,
		}
	}

	return {
		body: source,
		title: undefined,
	}
}

const normalizeAssetReference = value => {
	const stripped = value.split(/[?#]/, 1)[0]
	const fileName = basename(stripped)
	const stem = fileName.slice(0, fileName.length - extname(fileName).length)

	return {
		fileName: fileName.toLowerCase(),
		stem: stem.toLowerCase(),
	}
}

const splitAssetTarget = value => {
	const match = value.match(/^([^?#]*)([?#].*)?$/)

	return {
		path: match?.[1] ?? value,
		suffix: match?.[2] ?? '',
	}
}

const rewriteRelativeAssetTarget = (value, assetMap) => {
	if (
		/^[a-z]+:/i.test(value) ||
		value.startsWith('#') ||
		value.startsWith('/')
	) {
		return value
	}

	const { path, suffix } = splitAssetTarget(value)
	const reference = normalizeAssetReference(path)

	return (
		assetMap.get(reference.fileName) ??
		assetMap.get(reference.stem) ??
		`${path}${suffix}`
	)
}

const rewriteAssetReferences = (source, assetMap) => {
	const rewriteInlineTarget = (match, prefix, target, suffix) => {
		const replacement = rewriteRelativeAssetTarget(target, assetMap)

		return replacement !== target ? `${prefix}${replacement}${suffix}` : match
	}

	const rewriteDefinitionTarget = (match, prefix, target, suffix) => {
		const replacement = rewriteRelativeAssetTarget(target, assetMap)

		return replacement !== target ? `${prefix}${replacement}${suffix}` : match
	}

	return source
		.replace(/(!?\[[^\]]*?\]\()([^)\s]+)(\))/g, rewriteInlineTarget)
		.replace(/^(\s*\[[^\]]+\]:\s*)(\S+)(.*)$/gm, rewriteDefinitionTarget)
}

const rewriteAssetReference = (value, assetMap) => {
	if (
		/^[a-z]+:/i.test(value) ||
		value.startsWith('#') ||
		value.startsWith('/')
	) {
		return value
	}

	const { path, suffix } = splitAssetTarget(value)
	const reference = normalizeAssetReference(path)

	return (
		assetMap.get(reference.fileName) ??
		assetMap.get(reference.stem) ??
		`${path}${suffix}`
	)
}

const selectMarkdownFile = async dir => {
	const entries = await readdir(dir, { withFileTypes: true })
	const files = entries
		.filter(entry => entry.isFile() && isMarkdownFile(entry.name))
		.map(entry => entry.name)
		.sort((left, right) => left.localeCompare(right))

	for (const prioritizedName of [
		'entry.md',
		'post.md',
		'note.md',
		'article.md',
	]) {
		if (files.includes(prioritizedName)) {
			return prioritizedName
		}
	}

	return files[0]
}

const getEntryType = markdownFileName =>
	basename(markdownFileName).toLowerCase() === 'note.md' ? 'note' : 'article'

const buildSlug = ({
	frontmatterSlug,
	title,
	markdownStem,
	markdownFileName,
}) => {
	if (frontmatterSlug?.trim()) {
		return normalizeSlug(frontmatterSlug)
	}

	if (defaultSlugTitleFiles.has(markdownStem.toLowerCase())) {
		return normalizeSlug(title)
	}

	return normalizeSlug(
		markdownStem || basename(markdownFileName, extname(markdownFileName))
	)
}

const parseImportedDate = (value, now = new Date()) => {
	if (!value) {
		return formatLocalIso(now)
	}

	return value.trim()
}

const pathExists = async path => {
	try {
		await access(path)
		return true
	} catch {
		return false
	}
}

const collectReferencedAssetTargets = (body, frontmatterImage) => {
	const targets = []
	const pushTarget = target => {
		if (target) {
			targets.push(target)
		}
	}

	pushTarget(frontmatterImage)

	body.replace(/(!?\[[^\]]*?\]\()([^)\s]+)(\))/g, (match, prefix, target) => {
		pushTarget(target)
		return match
	})

	body.replace(/^(\s*\[[^\]]+\]:\s*)(\S+)(.*)$/gm, (match, prefix, target) => {
		pushTarget(target)
		return match
	})

	return targets
}

const collectReferencedImageFiles = (body, frontmatterImage, sourceFiles) => {
	const referencedFiles = []
	const seen = new Set()

	for (const target of collectReferencedAssetTargets(body, frontmatterImage)) {
		if (
			/^[a-z]+:/i.test(target) ||
			target.startsWith('#') ||
			target.startsWith('/')
		) {
			continue
		}

		const { path } = splitAssetTarget(target)
		const sourceName = sourceFiles.get(normalizeAssetReference(path).fileName)

		if (!sourceName || !isSupportedImageFile(sourceName)) {
			continue
		}

		const lowerName = sourceName.toLowerCase()
		if (seen.has(lowerName)) {
			continue
		}

		seen.add(lowerName)
		referencedFiles.push(sourceName)
	}

	return referencedFiles
}

const convertImageWithSharp = async (sourcePath, destinationPath) => {
	await sharp(sourcePath)
		.rotate()
		.resize({
			fit: 'inside',
			height: 1280,
			withoutEnlargement: true,
			width: 1280,
		})
		.avif({ quality: 82 })
		.toFile(destinationPath)
}

const convertImageWithMagick = (sourcePath, destinationPath) => {
	const result = spawnSync(
		'magick',
		[
			sourcePath,
			'-auto-orient',
			'-resize',
			'1280x1280>',
			'-strip',
			destinationPath,
		],
		{
			stdio: 'inherit',
		}
	)

	if (result.error) {
		throw result.error
	}

	if (result.status !== 0) {
		throw new Error(`magick exited with status ${result.status ?? 'unknown'}`)
	}
}

const runImageOptim = paths => {
	if (paths.length === 0) {
		return
	}

	const result = spawnSync('image_optim', paths, {
		stdio: 'inherit',
	})

	if (result.error) {
		if (result.error.code === 'ENOENT') {
			console.warn(
				'warning: image_optim not found; skipping PNG/GIF optimization'
			)
			return
		}

		throw result.error
	}

	if (result.status !== 0) {
		throw new Error(
			`image_optim exited with status ${result.status ?? 'unknown'}`
		)
	}
}

const openInEditor = files => {
	const editor = process.env.EDITOR?.trim()
	if (!editor) {
		throw new Error('EDITOR is not set')
	}

	const command = `${editor} ${files.map(quoteShellArg).join(' ')}`
	const result = spawnSync(command, {
		stdio: 'inherit',
		shell: true,
	})

	if (result.status !== 0) {
		throw new Error(
			`${editor} exited with status ${result.status ?? 'unknown'}`
		)
	}
}

const openInFinder = path => {
	const result = spawnSync('open', [path], {
		stdio: 'inherit',
	})

	if (result.status !== 0) {
		throw new Error(`Finder exited with status ${result.status ?? 'unknown'}`)
	}
}

const readStdin = async () => {
	if (process.stdin.isTTY) {
		return ''
	}

	process.stdin.setEncoding('utf8')

	let body = ''

	process.stdin.on('data', chunk => {
		body += chunk
	})

	await once(process.stdin, 'end')

	return body
}

const readPackageName = async () => {
	try {
		const source = await readFile(join(repoRoot, 'package.json'), 'utf8')
		const packageJson = JSON.parse(source)

		return typeof packageJson.name === 'string' ? packageJson.name : undefined
	} catch {
		return undefined
	}
}

const pubnameFromPackageName = packageName => {
	if (!packageName || packageName.startsWith('@')) {
		return undefined
	}

	const parts = packageName.split('.').filter(Boolean)
	if (parts.length < 3) {
		return undefined
	}

	return parts.slice(1).join('-')
}

const resolveConfig = async args => {
	const packageName = await readPackageName()
	const project = args.project ?? normalizeProject(basename(repoRoot))
	const pubname = args.pubname || pubnameFromPackageName(packageName) || project
	const publicPrefix = args.publicPrefix ?? normalizePublicPrefix(project)
	const stylePrefix = args.stylePrefix ?? project

	return {
		contentRoot: resolve(
			repoRoot,
			args.contentRoot ?? join('src', 'content', project)
		),
		project,
		pubname,
		publicPrefix,
		publicRoot: resolve(repoRoot, args.publicRoot ?? join('public', project)),
		stylePrefix,
		stylesRoot: resolve(
			repoRoot,
			args.stylesRoot ?? join('src', 'styles', project)
		),
	}
}

const resolveMarkdownMetadata = async sourceDir => {
	const markdownFileName = await selectMarkdownFile(sourceDir)
	if (!markdownFileName) {
		throw new Error('no markdown files found in import directory')
	}

	const markdownPath = join(sourceDir, markdownFileName)
	const source = await readFile(markdownPath, 'utf8')
	const frontmatterTitle = frontmatterString(source, 'title')
	const frontmatterSlug = frontmatterString(source, 'slug')
	const frontmatterDate = frontmatterString(source, 'date')
	const frontmatterKicker = frontmatterString(source, 'kicker')
	const frontmatterDeck = frontmatterString(source, 'deck')
	const frontmatterSubtitle = frontmatterString(source, 'subtitle')
	const frontmatterDescription = frontmatterString(source, 'description')
	const frontmatterSummary = frontmatterString(source, 'summary')
	const frontmatterTags = frontmatterString(source, 'tags')
	const frontmatterCatname = frontmatterString(source, 'catname')
	const frontmatterImage = frontmatterString(source, 'image')
	const frontmatterDraft = frontmatterBoolean(source, 'draft')
	const bodyWithoutFrontmatter = stripFrontmatter(source).trimStart()
	const titleFromBody = stripFirstHeading(bodyWithoutFrontmatter)
	const title =
		frontmatterTitle ??
		titleFromBody.title ??
		humanizeSlug(basename(markdownFileName, extname(markdownFileName)))
	const body = frontmatterTitle
		? bodyWithoutFrontmatter
		: titleFromBody.body.trimStart()
	const markdownStem = basename(markdownFileName, extname(markdownFileName))
	const slug = buildSlug({
		frontmatterSlug,
		markdownFileName,
		markdownStem,
		title,
	})

	return {
		body,
		catname: frontmatterCatname ?? 'tips',
		date: parseImportedDate(frontmatterDate),
		deck: frontmatterDeck,
		description: frontmatterDescription,
		draft: frontmatterDraft,
		image: frontmatterImage,
		kicker: frontmatterKicker,
		markdownFileName,
		markdownPath,
		slug,
		subtitle: frontmatterSubtitle,
		summary: frontmatterSummary,
		tags: frontmatterTags,
		title,
		type: getEntryType(markdownFileName),
	}
}

const publicAssetPath = (config, slug, fileName) =>
	`${config.publicPrefix}/${slug}/${fileName}`.replace(/\/+/g, '/')

const styleFrontmatterPath = (config, slug) =>
	[config.stylePrefix, `${slug}.css`].filter(Boolean).join('/')

const importDirectory = async (
	config,
	sourceDirInput,
	{ edit = false, openFolder = false, force = false } = {}
) => {
	const sourceDir = resolve(repoRoot, sourceDirInput)
	const sourceEntries = await readdir(sourceDir, { withFileTypes: true })
	const sourceFiles = new Map(
		sourceEntries
			.filter(entry => entry.isFile())
			.map(entry => [entry.name.toLowerCase(), entry.name])
	)
	const markdownMetadata = await resolveMarkdownMetadata(sourceDir)
	const imageFileNames = collectReferencedImageFiles(
		markdownMetadata.body,
		markdownMetadata.image,
		sourceFiles
	)
	const hasStyleCss = sourceFiles.has('style.css')
	const dateParts = markdownMetadata.date.match(/^(\d{4})-(\d{2})-(\d{2})/)
	const dateString = dateParts
		? `${dateParts[1]}-${dateParts[2]}-${dateParts[3]}`
		: toLocalDateString(new Date())
	const datedSlug = `${dateString}-${markdownMetadata.slug}`
	const contentDir = join(config.contentRoot, datedSlug)
	const publicDir = join(config.publicRoot, markdownMetadata.slug)
	const styleSourcePath = join(sourceDir, 'style.css')
	const stylePath = join(config.stylesRoot, `${markdownMetadata.slug}.css`)
	const contentPath = join(contentDir, 'index.md')
	const filesToEdit = [contentPath]
	const assetNames = new Set()
	const assetMap = new Map()
	const imageAssets = []
	const pngAndGifOutputs = []
	let numericImageIndex = 0

	const existingImportPath = (await pathExists(contentPath))
		? contentPath
		: (await pathExists(contentDir))
			? contentDir
			: (await pathExists(publicDir))
				? publicDir
				: (await pathExists(stylePath))
					? stylePath
					: undefined

	if (existingImportPath) {
		if (!force) {
			fail(
				`import would overwrite existing entry "${datedSlug}" at ${existingImportPath}`,
				EXIT_IMPORT_CONFLICT
			)
			return
		}

		await rm(contentDir, { force: true, recursive: true })
		await rm(publicDir, { force: true, recursive: true })
		await rm(stylePath, { force: true })
	}

	await mkdir(contentDir, { recursive: true })
	await mkdir(publicDir, { recursive: true })
	await mkdir(config.stylesRoot, { recursive: true })

	for (const fileName of imageFileNames) {
		const inputPath = join(sourceDir, fileName)
		const baseName = basename(fileName, extname(fileName))
		const extension = extname(fileName).toLowerCase()
		const isSpecialAsset =
			baseName.toLowerCase() === 'image' || baseName.toLowerCase() === 'share'
		const outputBaseName = isSpecialAsset ? baseName : pad2(numericImageIndex++)
		const outputExtension =
			extension === '.jpg' ||
			extension === '.jpeg' ||
			extension === '.webp' ||
			extension === '.heic' ||
			extension === '.heif'
				? '.avif'
				: extension
		const outputFileName = uniqueName(
			`${outputBaseName}${outputExtension}`,
			assetNames
		)
		const outputPath = join(publicDir, outputFileName)
		const publicPath = publicAssetPath(
			config,
			markdownMetadata.slug,
			outputFileName
		)

		assetMap.set(fileName.toLowerCase(), publicPath)
		assetMap.set(baseName.toLowerCase(), publicPath)
		imageAssets.push({
			inputPath,
			outputFileName,
			outputPath,
			publicPath,
			sourceName: fileName,
		})

		if (extension === '.heic' || extension === '.heif') {
			convertImageWithMagick(inputPath, outputPath)
		} else if (outputExtension === '.avif') {
			await convertImageWithSharp(inputPath, outputPath)
		} else {
			convertImageWithMagick(inputPath, outputPath)
			if (outputExtension === '.png' || outputExtension === '.gif') {
				pngAndGifOutputs.push(outputPath)
			}
		}
	}

	const imageFrontmatter = markdownMetadata.image
		? rewriteAssetReference(markdownMetadata.image, assetMap)
		: undefined
	const fallbackImageFrontmatter =
		imageFrontmatter ??
		assetMap.get('image') ??
		assetMap.get('share') ??
		imageAssets[0]?.publicPath
	const body = rewriteAssetReferences(markdownMetadata.body, assetMap)

	try {
		if (pngAndGifOutputs.length > 0) {
			runImageOptim(pngAndGifOutputs)
		}

		if (hasStyleCss) {
			await copyFile(styleSourcePath, stylePath)
			filesToEdit.push(stylePath)
		}

		const frontmatterLines = [
			'---',
			`pubname: ${config.pubname}`,
			`date: ${markdownMetadata.date}`,
			`title: ${markdownMetadata.title}`,
			`type: ${markdownMetadata.type}`,
			`catname: ${markdownMetadata.catname}`,
		]

		if (markdownMetadata.subtitle) {
			frontmatterLines.push(`subtitle: ${markdownMetadata.subtitle}`)
		}

		if (markdownMetadata.kicker) {
			frontmatterLines.push(`kicker: ${markdownMetadata.kicker}`)
		}

		if (markdownMetadata.deck) {
			frontmatterLines.push(`deck: ${markdownMetadata.deck}`)
		}

		if (markdownMetadata.description) {
			frontmatterLines.push(`description: ${markdownMetadata.description}`)
		}

		if (markdownMetadata.summary) {
			frontmatterLines.push(`summary: ${markdownMetadata.summary}`)
		}

		if (markdownMetadata.draft) {
			frontmatterLines.push('draft: true')
		}

		if (hasStyleCss) {
			frontmatterLines.push(
				`style: ${styleFrontmatterPath(config, markdownMetadata.slug)}`
			)
		}

		if (markdownMetadata.tags) {
			frontmatterLines.push(`tags: ${markdownMetadata.tags}`)
		}

		if (fallbackImageFrontmatter) {
			frontmatterLines.push(`image: ${fallbackImageFrontmatter}`)
		}

		frontmatterLines.push('---')

		await writeFile(contentPath, `${frontmatterLines.join('\n')}\n\n${body}`, {
			flag: 'wx',
		})
	} catch (error) {
		fail(
			error instanceof Error
				? error.message
				: `failed to create files for ${datedSlug}`
		)
		return
	}

	console.log(`Imported ${datedSlug}`)
	console.log(`  ${contentPath}`)
	if (hasStyleCss) {
		console.log(`  ${stylePath}`)
	}
	for (const imageAsset of imageAssets) {
		console.log(`  ${join(publicDir, imageAsset.outputFileName)}`)
	}
	console.log(`  ${publicDir}`)

	if (openFolder) {
		try {
			openInFinder(publicDir)
		} catch (error) {
			fail(error instanceof Error ? error.message : String(error))
		}
	}

	if (edit) {
		try {
			openInEditor(filesToEdit)
		} catch (error) {
			fail(error instanceof Error ? error.message : String(error))
		}
	}
}

const createEntry = async (config, parsed) => {
	const rawSlug = parsed.slugParts.join(' ').trim()
	const rawTitle = parsed.titleParts.join(' ').trim()
	const slugSource = rawSlug || rawTitle

	if (!slugSource) {
		fail('missing slug or title')
		usage()
		return
	}

	const slug = normalizeSlug(slugSource)
	if (!slug) {
		fail(`slug source "${slugSource}" normalised to an empty value`)
		return
	}

	const date = parsed.date?.parsed ?? new Date()
	const dateString = parsed.date?.fileDate ?? toLocalDateString(date)
	const datedSlug = `${dateString}-${slug}`
	const title = rawTitle || humanizeSlug(slug) || slug
	const contentDir = join(config.contentRoot, datedSlug)
	const publicDir = join(config.publicRoot, slug)
	const stylePath = join(config.stylesRoot, `${slug}.css`)
	const contentPath = join(contentDir, 'index.md')
	const filesToEdit = [contentPath, stylePath]
	const frontmatterDate = parsed.date?.frontmatterDate ?? formatLocalIso(date)
	const tags = normalizeTagList(parsed.tags)
	const assetNames = new Set()
	const imageAssets = parsed.imagePaths.map(imagePath => {
		const fileName = uniqueAssetName(basename(imagePath), assetNames)

		return {
			fileName,
			sourcePath: imagePath,
			publicPath: publicAssetPath(config, slug, fileName),
		}
	})
	const stdinBody = await readStdin()
	const body = stdinBody.trim() ? `${stdinBody.replace(/\s+$/u, '')}\n` : ''
	const imageFrontmatter = imageAssets[0]?.publicPath

	await mkdir(contentDir, { recursive: true })
	await mkdir(publicDir, { recursive: true })
	await mkdir(config.stylesRoot, { recursive: true })

	try {
		for (const imageAsset of imageAssets) {
			await copyFile(
				imageAsset.sourcePath,
				join(publicDir, imageAsset.fileName)
			)
		}

		const frontmatterLines = [
			'---',
			`pubname: ${config.pubname}`,
			`date: ${frontmatterDate}`,
			`title: ${title}`,
			`type: ${parsed.type}`,
			'catname: tips',
			`style: ${styleFrontmatterPath(config, slug)}`,
		]

		if (tags.length > 0) {
			frontmatterLines.push(`tags: ${tags.join(', ')}`)
		}

		if (imageFrontmatter) {
			frontmatterLines.push(`image: ${imageFrontmatter}`)
		}

		frontmatterLines.push('---')

		await writeFile(contentPath, `${frontmatterLines.join('\n')}\n\n${body}`, {
			flag: 'wx',
		})
		await writeFile(stylePath, `/* Add styles for ${slug}. */\n`, {
			flag: 'wx',
		})
	} catch (error) {
		fail(
			error instanceof Error
				? error.message
				: `failed to create files for ${datedSlug}`
		)
		return
	}

	console.log(`Created ${datedSlug}`)
	console.log(`  ${contentPath}`)
	console.log(`  ${stylePath}`)
	for (const imageAsset of imageAssets) {
		console.log(`  ${join(publicDir, imageAsset.fileName)}`)
	}
	console.log(`  ${publicDir}`)

	if (parsed.openFolder) {
		try {
			openInFinder(publicDir)
		} catch (error) {
			fail(error instanceof Error ? error.message : String(error))
		}
	}

	if (parsed.edit) {
		try {
			openInEditor(filesToEdit)
		} catch (error) {
			fail(error instanceof Error ? error.message : String(error))
		}
	}
}

const main = async () => {
	let parsed
	try {
		parsed = parseArgs(process.argv.slice(2))
	} catch (error) {
		fail(error instanceof Error ? error.message : String(error))
		return
	}

	if (
		!parsed.command ||
		parsed.command === 'help' ||
		parsed.command === '-h' ||
		parsed.command === '--help'
	) {
		usage()
		return
	}

	if (
		parsed.command === '-v' ||
		parsed.command === '--version' ||
		parsed.command === 'version'
	) {
		const packageJsonPath = resolve(
			dirname(fileURLToPath(import.meta.url)),
			'..',
			'package.json'
		)
		const packageJson = JSON.parse(await readFile(packageJsonPath, 'utf8'))
		console.log(`comprose ${packageJson.version}`)
		return
	}

	const config = await resolveConfig(parsed)

	if (parsed.command === 'import') {
		if (!parsed.sourceDir) {
			fail('missing directory path for import')
			usage()
			return
		}

		try {
			await importDirectory(config, parsed.sourceDir, {
				edit: parsed.edit,
				force: parsed.force,
				openFolder: parsed.openFolder,
			})
		} catch (error) {
			const exitCode =
				error instanceof Error && /overwrite existing entry/.test(error.message)
					? EXIT_IMPORT_CONFLICT
					: 1
			fail(error instanceof Error ? error.message : String(error), exitCode)
		}

		return
	}

	if (parsed.command !== 'new') {
		fail(`unknown command "${parsed.command}"`)
		usage()
		return
	}

	await createEntry(config, parsed)
}

await main()
