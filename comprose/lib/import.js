// @ts-check

import { copyFile, mkdir, readdir } from 'node:fs/promises'
import { basename, dirname, extname, join, resolve } from 'node:path'
import { assetMarkerName, EXIT_IMPORT_CONFLICT, repoRoot } from './constants.js'
import { toLocalDateString } from './date.js'
import {
	collectReferencedImageFiles,
	resolveMarkdownMetadata,
	rewriteAssetReference,
	rewriteAssetReferences,
} from './markdown.js'
import {
	buildTemplatePlan,
	existingOutputPath,
	pathExists,
	removeExistingOutput,
	templateContext,
	writeTemplateFiles,
} from './templates.js'
import { pad2, uniqueName } from './text.js'
import {
	convertImageWithMagick,
	convertImageWithSharp,
	openInEditor,
	openInFinder,
	runImageOptim,
} from './system.js'

/**
 * Import an existing prose directory into the destination project.
 *
 * The import flow is responsible for reconciling source markdown, assets, and
 * optional stylesheets with the selected template layout. It preserves the
 * source content where possible while rewriting image references to match the
 * generated output tree.
 *
 * @param {import('./types.js').ResolvedConfig} config
 * @param {string} sourceDirInput
 * @param {{ edit?: boolean, openFolder?: boolean, force?: boolean }} [options]
 * @param {{ fail: (message: string, exitCode?: number) => void }} [handlers]
 */
export const importDirectory = async (
	config,
	sourceDirInput,
	{ edit = false, openFolder = false, force = false } = {},
	{ fail } = { fail: () => {} }
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
	const datedSlug = `${dateString}-${markdownMetadata.slug}`
	const paths = await buildTemplatePlan(config, {
		collection: config.collection,
		dateString,
		date: dateString,
		datedSlug,
		project: config.collection,
		slug: markdownMetadata.slug,
	})
	const styleSourcePath = join(sourceDir, 'style.css')
	const filesToEdit = [paths.entryPath]
	const assetNames = new Set()
	const assetMap = new Map()
	/** @type {import('./types.js').ImageAsset[]} */
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

	if (imageFileNames.length > 0 && !paths.assetDir) {
		throw new Error(
			`template has no ${assetMarkerName} marker for imported assets`
		)
	}
	const assetDir = paths.assetDir

	if (paths.assetDir) {
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
		const outputPath = join(assetDir, outputFileName)
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
			dateString,
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

		await writeTemplateFiles(paths, context, {
			skipOutputPaths:
				hasStyleCss && paths.stylePath && paths.usesStyle
					? [paths.stylePath]
					: [],
		})
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
		console.log(`  ${join(assetDir, imageAsset.outputFileName)}`)
	}
	if (paths.assetDir && (await pathExists(paths.assetDir))) {
		console.log(`  ${paths.assetDir}`)
	}

	if (openFolder) {
		try {
			if (paths.assetDir) {
				openInFinder(paths.assetDir)
			}
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
