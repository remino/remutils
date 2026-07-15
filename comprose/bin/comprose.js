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
import Mustache from 'mustache'
import sharp from 'sharp'

const repoRoot = process.cwd()
const toolRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
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
  --template <name-or-path>
                  Template layout. Defaults to astro-content.
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
  comprose new --template astro-content -p journal --pubname example-journal -s my-new-entry
  comprose new --template middleman-blog --content-root source/posts -t "My New Entry"
  comprose new -p journal -d 2026-05-06T14:30+09:00 -k note -g terminal
  comprose import --template astro-content -p journal --pubname example-journal /tmp/source-entry
  comprose import --template middleman-blog --content-root source/posts /tmp/source-entry -f
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
		template: undefined,
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

		if (token === '--template') {
			args.template = nextValue(token)
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

	for (const target of [frontmatterImage].flat()) {
		pushTarget(target)
	}

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

const templateEntryPath = templateDir => join(templateDir, 'entry.md.mustache')

const resolveTemplate = async templateInput => {
	const templateName = templateInput ?? 'astro-content'
	const builtInDir = join(toolRoot, 'templates', templateName)

	if (await pathExists(templateEntryPath(builtInDir))) {
		return {
			dir: builtInDir,
			layout: templateName,
			name: templateName,
		}
	}

	const customDir = resolve(repoRoot, templateName)
	if (!(await pathExists(templateEntryPath(customDir)))) {
		throw new Error(`template not found: ${templateName}`)
	}

	let layout = 'astro-content'
	try {
		const layoutConfig = JSON.parse(
			await readFile(join(customDir, 'layout.json'), 'utf8')
		)
		if (
			layoutConfig.layout === 'astro-content' ||
			layoutConfig.layout === 'middleman-blog'
		) {
			layout = layoutConfig.layout
		}
	} catch {
		// Custom template directories default to the Astro content layout.
	}

	return {
		dir: customDir,
		layout,
		name: templateName,
	}
}

const resolveConfig = async args => {
	const packageName = await readPackageName()
	const project = args.project ?? normalizeProject(basename(repoRoot))
	const pubname = args.pubname || pubnameFromPackageName(packageName) || project
	const publicPrefix = args.publicPrefix ?? normalizePublicPrefix(project)
	const stylePrefix = args.stylePrefix ?? project
	const template = await resolveTemplate(args.template)

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
		template,
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
	const frontmatterOriginalDate = frontmatterString(source, 'original_date')
	const frontmatterKicker = frontmatterString(source, 'kicker')
	const frontmatterDeck = frontmatterString(source, 'deck')
	const frontmatterSubtitle = frontmatterString(source, 'subtitle')
	const frontmatterDescription = frontmatterString(source, 'description')
	const frontmatterSummary = frontmatterString(source, 'summary')
	const frontmatterTags = frontmatterString(source, 'tags')
	const frontmatterCatname = frontmatterString(source, 'catname')
	const frontmatterImage = frontmatterString(source, 'image')
	const frontmatterShare = frontmatterString(source, 'share')
	const frontmatterShareImage = frontmatterString(source, 'share_image')
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
		original_date: frontmatterOriginalDate,
		share: frontmatterShare,
		share_image: frontmatterShareImage,
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

const buildPaths = (config, { dateString, slug }) => {
	if (config.template.layout === 'middleman-blog') {
		const entryPath = join(config.contentRoot, `${slug}.html.md`)

		return {
			assetDir: join(config.contentRoot, slug),
			contentDir: config.contentRoot,
			entryPath,
			label: slug,
			publicAssetPath: fileName => fileName,
			stylePath: undefined,
			styleValue: undefined,
			usesStyle: false,
		}
	}

	const datedSlug = `${dateString}-${slug}`

	return {
		assetDir: join(config.publicRoot, slug),
		contentDir: join(config.contentRoot, datedSlug),
		entryPath: join(config.contentRoot, datedSlug, 'index.md'),
		label: datedSlug,
		publicAssetPath: fileName => publicAssetPath(config, slug, fileName),
		stylePath: join(config.stylesRoot, `${slug}.css`),
		styleValue: styleFrontmatterPath(config, slug),
		usesStyle: true,
	}
}

const loadTemplate = async (config, fileName) => {
	const templatePath = join(config.template.dir, fileName)

	if (!(await pathExists(templatePath))) {
		return undefined
	}

	return readFile(templatePath, 'utf8')
}

const hasValue = value =>
	value !== undefined && value !== null && String(value).trim() !== ''

const templateContext = ({
	body,
	config,
	date,
	frontmatterDate,
	image,
	metadata = {},
	paths,
	slug,
	style,
	tags = [],
	title,
	type = 'article',
}) => {
	const context = {
		assetDir: paths.assetDir,
		body,
		catname: metadata.catname ?? 'tips',
		contentDir: paths.contentDir,
		date,
		description: metadata.description,
		draft: metadata.draft,
		entryPath: paths.entryPath,
		frontmatterDate,
		image,
		kicker: metadata.kicker,
		original_date: metadata.original_date,
		project: config.project,
		pubname: config.pubname,
		publicPrefix: config.publicPrefix,
		share_image: metadata.share_image,
		slug,
		style,
		stylePath: paths.stylePath,
		stylePrefix: config.stylePrefix,
		subtitle: metadata.subtitle,
		summary: metadata.summary,
		tags: Array.isArray(tags) ? tags.join(', ') : tags,
		title,
		type,
	}

	context.deck = metadata.deck
	context.hasDeck = hasValue(context.deck)
	context.hasDescription = hasValue(context.description)
	context.hasDraft = context.draft === true
	context.hasImage = hasValue(context.image)
	context.hasKicker = hasValue(context.kicker)
	context.hasOriginalDate = hasValue(context.original_date)
	context.hasShareImage = hasValue(context.share_image)
	context.hasStyle = hasValue(context.style)
	context.hasSubtitle = hasValue(context.subtitle)
	context.hasSummary = hasValue(context.summary)
	context.hasTags = hasValue(context.tags)

	return context
}

const renderTemplate = async (config, fileName, context) => {
	const template = await loadTemplate(config, fileName)

	return template === undefined ? undefined : Mustache.render(template, context)
}

const writeRenderedEntry = async (config, context) => {
	const rendered = await renderTemplate(config, 'entry.md.mustache', context)
	if (rendered === undefined) {
		throw new Error(
			`template missing entry.md.mustache: ${config.template.name}`
		)
	}

	await writeFile(context.entryPath, rendered, { flag: 'wx' })
}

const writeRenderedStyle = async (config, context) => {
	const rendered = await renderTemplate(config, 'style.css.mustache', context)
	if (rendered === undefined || !context.stylePath) {
		return false
	}

	await writeFile(context.stylePath, rendered, { flag: 'wx' })
	return true
}

const removeExistingOutput = async paths => {
	await rm(paths.entryPath, { force: true })
	await rm(paths.assetDir, { force: true, recursive: true })
	if (paths.stylePath) {
		await rm(paths.stylePath, { force: true })
	}
}

const existingOutputPath = async paths => {
	if (await pathExists(paths.entryPath)) {
		return paths.entryPath
	}

	if (await pathExists(paths.assetDir)) {
		return paths.assetDir
	}

	if (paths.stylePath && (await pathExists(paths.stylePath))) {
		return paths.stylePath
	}

	return undefined
}

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
		[
			markdownMetadata.image,
			markdownMetadata.share_image,
			markdownMetadata.share,
		],
		sourceFiles
	)
	const hasStyleCss = sourceFiles.has('style.css')
	const dateParts = markdownMetadata.date.match(/^(\d{4})-(\d{2})-(\d{2})/)
	const dateString = dateParts
		? `${dateParts[1]}-${dateParts[2]}-${dateParts[3]}`
		: toLocalDateString(new Date())
	const paths = buildPaths(config, {
		dateString,
		slug: markdownMetadata.slug,
	})
	const styleSourcePath = join(sourceDir, 'style.css')
	const filesToEdit = [paths.entryPath]
	const assetNames = new Set()
	const assetMap = new Map()
	const imageAssets = []
	const pngAndGifOutputs = []
	let numericImageIndex = 0

	const existingImportPath = await existingOutputPath(paths)

	if (existingImportPath) {
		if (!force) {
			fail(
				`import would overwrite existing entry "${paths.label}" at ${existingImportPath}`,
				EXIT_IMPORT_CONFLICT
			)
			return
		}

		await removeExistingOutput(paths)
	}

	await mkdir(dirname(paths.entryPath), { recursive: true })
	if (
		imageFileNames.length > 0 ||
		openFolder ||
		config.template.layout !== 'middleman-blog'
	) {
		await mkdir(paths.assetDir, { recursive: true })
	}
	if (paths.stylePath && hasStyleCss) {
		await mkdir(dirname(paths.stylePath), { recursive: true })
	}

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
		const outputPath = join(paths.assetDir, outputFileName)
		const publicPath = paths.publicAssetPath(outputFileName)

		assetMap.set(fileName.toLowerCase(), publicPath)
		assetMap.set(baseName.toLowerCase(), publicPath)
		imageAssets.push({
			inputPath,
			outputFileName,
			outputPath,
			publicPath,
			sourceName: fileName,
		})

		if (extension === '.avif') {
			await copyFile(inputPath, outputPath)
		} else if (extension === '.heic' || extension === '.heif') {
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
	const shareImageFrontmatter = markdownMetadata.share_image
		? rewriteAssetReference(markdownMetadata.share_image, assetMap)
		: undefined
	const fallbackImageFrontmatter =
		imageFrontmatter ??
		assetMap.get('image') ??
		assetMap.get('share') ??
		imageAssets[0]?.publicPath
	const fallbackShareImageFrontmatter =
		shareImageFrontmatter ??
		(markdownMetadata.share
			? rewriteAssetReference(markdownMetadata.share, assetMap)
			: undefined)
	const body = rewriteAssetReferences(markdownMetadata.body, assetMap)

	try {
		if (pngAndGifOutputs.length > 0) {
			runImageOptim(pngAndGifOutputs)
		}

		if (hasStyleCss && paths.stylePath && paths.usesStyle) {
			await copyFile(styleSourcePath, paths.stylePath)
			filesToEdit.push(paths.stylePath)
		}

		const context = templateContext({
			body,
			config,
			date: markdownMetadata.date,
			frontmatterDate: markdownMetadata.date,
			image: fallbackImageFrontmatter,
			metadata: {
				...markdownMetadata,
				share_image: fallbackShareImageFrontmatter,
			},
			paths,
			slug: markdownMetadata.slug,
			style: hasStyleCss && paths.usesStyle ? paths.styleValue : undefined,
			tags: markdownMetadata.tags,
			title: markdownMetadata.title,
			type: markdownMetadata.type,
		})

		await writeRenderedEntry(config, context)
	} catch (error) {
		fail(
			error instanceof Error
				? error.message
				: `failed to create files for ${paths.label}`
		)
		return
	}

	console.log(`Imported ${paths.label}`)
	console.log(`  ${paths.entryPath}`)
	if (hasStyleCss && paths.stylePath && paths.usesStyle) {
		console.log(`  ${paths.stylePath}`)
	}
	for (const imageAsset of imageAssets) {
		console.log(`  ${join(paths.assetDir, imageAsset.outputFileName)}`)
	}
	if (await pathExists(paths.assetDir)) {
		console.log(`  ${paths.assetDir}`)
	}

	if (openFolder) {
		try {
			openInFinder(paths.assetDir)
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
	const title = rawTitle || humanizeSlug(slug) || slug
	const paths = buildPaths(config, { dateString, slug })
	const filesToEdit = [paths.entryPath]
	const frontmatterDate = parsed.date?.frontmatterDate ?? formatLocalIso(date)
	const tags = normalizeTagList(parsed.tags)
	const assetNames = new Set()
	const imageAssets = parsed.imagePaths.map(imagePath => {
		const fileName = uniqueAssetName(basename(imagePath), assetNames)

		return {
			fileName,
			outputPath: join(paths.assetDir, fileName),
			sourcePath: imagePath,
			publicPath: paths.publicAssetPath(fileName),
		}
	})
	const stdinBody = await readStdin()
	const body = stdinBody.trim() ? `${stdinBody.replace(/\s+$/u, '')}\n` : ''
	const imageFrontmatter = imageAssets[0]?.publicPath

	await mkdir(dirname(paths.entryPath), { recursive: true })
	if (
		imageAssets.length > 0 ||
		parsed.openFolder ||
		config.template.layout !== 'middleman-blog'
	) {
		await mkdir(paths.assetDir, { recursive: true })
	}
	if (paths.stylePath && paths.usesStyle) {
		await mkdir(dirname(paths.stylePath), { recursive: true })
	}

	try {
		for (const imageAsset of imageAssets) {
			await copyFile(imageAsset.sourcePath, imageAsset.outputPath)
		}

		const context = templateContext({
			body,
			config,
			date:
				config.template.layout === 'middleman-blog'
					? dateString
					: frontmatterDate,
			frontmatterDate,
			image: imageFrontmatter,
			metadata: { catname: 'tips' },
			paths,
			slug,
			style: paths.usesStyle ? paths.styleValue : undefined,
			tags,
			title,
			type: parsed.type,
		})
		await writeRenderedEntry(config, context)
		if (paths.usesStyle && (await writeRenderedStyle(config, context))) {
			filesToEdit.push(paths.stylePath)
		}
	} catch (error) {
		fail(
			error instanceof Error
				? error.message
				: `failed to create files for ${paths.label}`
		)
		return
	}

	console.log(`Created ${paths.label}`)
	console.log(`  ${paths.entryPath}`)
	if (paths.stylePath && (await pathExists(paths.stylePath))) {
		console.log(`  ${paths.stylePath}`)
	}
	for (const imageAsset of imageAssets) {
		console.log(`  ${imageAsset.outputPath}`)
	}
	if (await pathExists(paths.assetDir)) {
		console.log(`  ${paths.assetDir}`)
	}

	if (parsed.openFolder) {
		try {
			openInFinder(paths.assetDir)
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
