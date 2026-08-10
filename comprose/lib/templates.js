// @ts-check
/** @import {ParsedArgs, ResolvedConfig, TemplateContext, TemplateMetadata, TemplatePlan, TemplateRef} from './types.js' */

/**
 * Template discovery, planning, and file emission.
 *
 * @module lib/templates
 */

import {
	access,
	copyFile,
	mkdir,
	readFile,
	readdir,
	rm,
	writeFile,
} from 'node:fs/promises'
import {
	basename,
	dirname,
	isAbsolute,
	join,
	relative,
	resolve,
} from 'node:path'
import Mustache from 'mustache'
import { assetMarkerName, repoRoot, toolRoot } from './constants.js'
import { normalizeProject, hasValue } from './text.js'

/**
 * Check whether a path exists.
 *
 * @param {string} path
 * @returns {Promise<boolean>}
 */
export const pathExists = async path => {
	try {
		await access(path)
		return true
	} catch {
		return false
	}
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

const findParentTemplateDir = async (templateName, templatePath) => {
	let dir = repoRoot

	while (true) {
		const candidate = join(dir, ...templatePath, templateName)
		if (await pathExists(candidate)) {
			return candidate
		}

		const parent = dirname(dir)
		if (parent === dir) {
			return undefined
		}

		dir = parent
	}
}

const findConfigTemplateDir = async templateName => {
	const configHome =
		process.env.XDG_CONFIG_HOME || join(process.env.HOME ?? '', '.config')
	if (!configHome) {
		return undefined
	}

	const candidate = join(configHome, 'comprose', 'templates', templateName)
	return (await pathExists(candidate)) ? candidate : undefined
}

/** @param {string} dir @returns {Promise<string[]>} */
const walkFiles = async dir => {
	const entries = await readdir(dir, { withFileTypes: true })
	const files = []

	for (const entry of entries) {
		const entryPath = join(dir, entry.name)

		if (entry.isDirectory()) {
			for (const childPath of await walkFiles(entryPath)) {
				files.push(join(entry.name, childPath))
			}
			continue
		}

		if (entry.isFile()) {
			files.push(entry.name)
		}
	}

	return files.sort((left, right) => left.localeCompare(right))
}

const renderPathVariables = (value, variables) =>
	value.replace(/\[([a-zA-Z0-9_]+)\]/g, (match, key) =>
		variables[key] === undefined ? match : String(variables[key])
	)

const outputPathFor = relativePath => {
	const outputPath = resolve(repoRoot, relativePath)
	const relativeToRoot = relative(repoRoot, outputPath)

	if (relativeToRoot.startsWith('..') || isAbsolute(relativeToRoot)) {
		throw new Error(`template output escapes repository root: ${relativePath}`)
	}

	return outputPath
}

const publicAssetPathFromTemplate = (assetDirRelative, fileName) => {
	if (!assetDirRelative) {
		return fileName
	}

	const normalized = assetDirRelative.replace(/\\/g, '/')
	if (normalized === 'public') {
		return `/${fileName}`
	}

	if (normalized.startsWith('public/')) {
		return `/${normalized.slice('public/'.length)}/${fileName}`.replace(
			/\/+/g,
			'/'
		)
	}

	return fileName
}

const styleValueFromTemplate = styleRelativePath => {
	if (!styleRelativePath) {
		return undefined
	}

	const normalized = styleRelativePath.replace(/\\/g, '/')
	if (normalized.startsWith('src/styles/')) {
		return normalized.slice('src/styles/'.length)
	}

	return normalized
}

/**
 * Resolve a template by local dot-directory lookup, user config lookup,
 * built-in name, or explicit relative/absolute path.
 *
 * @param {string | undefined} templateInput
 * @returns {Promise<TemplateRef>}
 */
export const resolveTemplate = async templateInput => {
	const templateName = templateInput ?? 'default'

	const parentTemplateDir = await findParentTemplateDir(templateName, [
		'.comprose',
		'templates',
	])
	if (parentTemplateDir) {
		return {
			dir: parentTemplateDir,
			name: templateName,
		}
	}

	const projectConfigTemplateDir = await findParentTemplateDir(templateName, [
		'.config',
		'comprose',
		'templates',
	])
	if (projectConfigTemplateDir) {
		return {
			dir: projectConfigTemplateDir,
			name: templateName,
		}
	}

	const configTemplateDir = await findConfigTemplateDir(templateName)
	if (configTemplateDir) {
		return {
			dir: configTemplateDir,
			name: templateName,
		}
	}

	const builtInDir = join(toolRoot, 'templates', templateName)
	if (await pathExists(builtInDir)) {
		return {
			dir: builtInDir,
			name: templateName,
		}
	}

	const customDir = resolve(repoRoot, templateName)
	if (!(await pathExists(customDir))) {
		throw new Error(`template not found: ${templateName}`)
	}

	return {
		dir: customDir,
		name: templateName,
	}
}

/**
 * Resolve the runtime configuration for the current project directory.
 *
 * @param {ParsedArgs} args
 * @returns {Promise<ResolvedConfig>}
 */
export const resolveConfig = async args => {
	const packageName = await readPackageName()
	const collection = args.collection ?? normalizeProject(basename(repoRoot))
	const pubname =
		args.pubname || pubnameFromPackageName(packageName) || collection
	const template = await resolveTemplate(args.template)

	return {
		collection,
		project: collection,
		pubname,
		template,
	}
}

/**
 * Build the concrete output plan for a rendered entry template.
 *
 * This walks the selected template tree, substitutes bracketed path variables,
 * and identifies the main markdown file, optional stylesheet, and optional
 * asset directory marker.
 *
 * @param {ResolvedConfig} config
 * @param {Record<string, string>} variables
 * @returns {Promise<TemplatePlan>}
 */
export const buildTemplatePlan = async (config, variables) => {
	const files = await walkFiles(config.template.dir)
	const renderedFiles = []
	let assetDir
	/** @type {string | undefined} */
	let assetDirRelative

	for (const file of files) {
		const renderedRelativePath = renderPathVariables(file, variables)

		if (basename(renderedRelativePath) === assetMarkerName) {
			assetDirRelative = dirname(renderedRelativePath)
			assetDir = outputPathFor(assetDirRelative)
			continue
		}

		const outputRelativePath = renderedRelativePath.endsWith('.mustache')
			? renderedRelativePath.slice(0, -'.mustache'.length)
			: renderedRelativePath

		renderedFiles.push({
			outputPath: outputPathFor(outputRelativePath),
			outputRelativePath,
			sourcePath: join(config.template.dir, file),
			template: renderedRelativePath.endsWith('.mustache'),
		})
	}

	const entryFile =
		renderedFiles.find(file => file.outputRelativePath.endsWith('.md')) ??
		renderedFiles.find(file => file.outputRelativePath.endsWith('.markdown'))
	const styleFile = renderedFiles.find(file =>
		file.outputRelativePath.endsWith('.css')
	)

	if (!entryFile) {
		throw new Error(
			`template has no Markdown entry file: ${config.template.name}`
		)
	}

	return {
		assetDir,
		assetDirRelative,
		contentDir: dirname(entryFile.outputPath),
		entryPath: entryFile.outputPath,
		files: renderedFiles,
		label:
			variables.datedSlug &&
			entryFile.outputRelativePath.includes(variables.datedSlug)
				? variables.datedSlug
				: variables.slug,
		publicAssetPath: fileName =>
			publicAssetPathFromTemplate(assetDirRelative, fileName),
		stylePath: styleFile?.outputPath,
		styleValue: styleValueFromTemplate(styleFile?.outputRelativePath),
		usesStyle: Boolean(styleFile),
	}
}

const optionalValue = value => (hasValue(value) ? String(value) : undefined)

/**
 * Build the Mustache context exposed to template files.
 *
 * @param {object} input
 * @param {string} input.body
 * @param {ResolvedConfig} input.config
 * @param {string} input.date
 * @param {string} [input.dateString]
 * @param {string} input.frontmatterDate
 * @param {string} [input.image]
 * @param {TemplateMetadata} [input.metadata]
 * @param {TemplatePlan} input.paths
 * @param {string} input.slug
 * @param {string} [input.style]
 * @param {string[] | string} [input.tags]
 * @param {string} input.title
 * @param {'article' | 'note'} [input.type]
 * @returns {TemplateContext}
 */
export const templateContext = ({
	body,
	config,
	date,
	dateString,
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
	/** @type {TemplateContext} */
	const context = {
		assetDir: paths.assetDir,
		body,
		catname: metadata.catname ?? 'tips',
		contentDir: paths.contentDir,
		date,
		dateString: dateString ?? date,
		deck: optionalValue(metadata.deck),
		description: optionalValue(metadata.description),
		draft: metadata.draft === true,
		entryPath: paths.entryPath,
		frontmatterDate,
		image: optionalValue(image),
		kicker: optionalValue(metadata.kicker),
		original_date: optionalValue(metadata.original_date),
		collection: config.collection,
		project: config.project,
		pubname: config.pubname,
		publicPrefix: `/${config.collection}`,
		share_image: optionalValue(metadata.share_image),
		slug,
		style: optionalValue(style),
		stylePath: paths.stylePath,
		stylePrefix: config.collection,
		subtitle: optionalValue(metadata.subtitle),
		summary: optionalValue(metadata.summary),
		tags: optionalValue(Array.isArray(tags) ? tags.join(', ') : tags),
		title,
		type,
	}
	return context
}

/**
 * Remove previously generated output for a scaffold or import target.
 *
 * @param {TemplatePlan} paths
 * @returns {Promise<void>}
 */
export const removeExistingOutput = async paths => {
	await rm(paths.entryPath, { force: true })
	if (paths.assetDir) {
		await rm(paths.assetDir, { force: true, recursive: true })
	}
	if (paths.stylePath) {
		await rm(paths.stylePath, { force: true })
	}
}

/**
 * Return the first existing output path for a template plan, if any.
 *
 * @param {TemplatePlan} paths
 * @returns {Promise<string | undefined>}
 */
export const existingOutputPath = async paths => {
	if (await pathExists(paths.entryPath)) {
		return paths.entryPath
	}

	if (paths.assetDir && (await pathExists(paths.assetDir))) {
		return paths.assetDir
	}

	if (paths.stylePath && (await pathExists(paths.stylePath))) {
		return paths.stylePath
	}

	return undefined
}

/**
 * Write all rendered and copied files described by a template plan.
 *
 * @param {TemplatePlan} paths
 * @param {TemplateContext} context
 * @param {object} [options]
 * @param {string[]} [options.skipOutputPaths]
 * @returns {Promise<string[]>}
 */
export const writeTemplateFiles = async (
	paths,
	context,
	{ skipOutputPaths = [] } = {}
) => {
	const written = []
	const skipped = new Set(skipOutputPaths)

	for (const file of paths.files) {
		if (skipped.has(file.outputPath)) {
			continue
		}

		await mkdir(dirname(file.outputPath), { recursive: true })

		if (file.template) {
			const template = await readFile(file.sourcePath, 'utf8')
			await writeFile(file.outputPath, Mustache.render(template, context), {
				flag: 'wx',
			})
		} else {
			await copyFile(file.sourcePath, file.outputPath)
		}

		written.push(file.outputPath)
	}

	return written
}
