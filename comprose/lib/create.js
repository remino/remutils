// @ts-check
/** @import {CliHandlers, ParsedArgs, ResolvedConfig} from './types.js' */

import { copyFile, mkdir } from 'node:fs/promises'
import { basename, join } from 'node:path'
import { assetMarkerName } from './constants.js'
import { formatLocalIso, toLocalDateString } from './date.js'
import {
	buildTemplatePlan,
	pathExists,
	templateContext,
	writeTemplateFiles,
} from './templates.js'
import {
	humanizeSlug,
	normalizeSlug,
	normalizeTagList,
	uniqueAssetName,
} from './text.js'
import { openInEditor, openInFinder, readStdin } from './system.js'

/**
 * Create a new entry scaffold from CLI input and a resolved template.
 *
 * This workflow is intentionally conservative: it only writes files described
 * by the selected template and mirrors the asset/style behavior that import
 * uses, so templates stay the single source of layout truth.
 *
 * @param {ResolvedConfig} config
 * @param {ParsedArgs} parsed
 * @param {CliHandlers} handlers
 */
export const createEntry = async (config, parsed, { fail, usage }) => {
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
	const paths = await buildTemplatePlan(config, {
		collection: config.collection,
		date: dateString,
		dateString,
		datedSlug,
		project: config.collection,
		slug,
	})
	const filesToEdit = [paths.entryPath]
	const frontmatterDate = parsed.date?.frontmatterDate ?? formatLocalIso(date)
	const tags = normalizeTagList(parsed.tags)
	const assetNames = new Set()
	const imageAssets = parsed.imagePaths.map(imagePath => {
		const fileName = uniqueAssetName(basename(imagePath), assetNames)

		return {
			fileName,
			outputPath: paths.assetDir ? join(paths.assetDir, fileName) : undefined,
			sourcePath: imagePath,
			publicPath: paths.publicAssetPath(fileName),
		}
	})
	const stdinBody = await readStdin()
	const body = stdinBody.trim() ? `${stdinBody.replace(/\s+$/u, '')}\n` : ''
	const imageFrontmatter = imageAssets[0]?.publicPath

	if (imageAssets.length > 0 && !paths.assetDir) {
		fail(`template has no ${assetMarkerName} marker for image assets`)
		return
	}

	if (paths.assetDir) {
		await mkdir(paths.assetDir, { recursive: true })
	}

	try {
		for (const imageAsset of imageAssets) {
			if (!imageAsset.outputPath) {
				throw new Error(
					`template has no ${assetMarkerName} marker for image assets`
				)
			}
			await copyFile(imageAsset.sourcePath, imageAsset.outputPath)
		}

		const context = templateContext({
			body,
			config,
			date: frontmatterDate,
			dateString,
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
		await writeTemplateFiles(paths, context)
		if (paths.stylePath && (await pathExists(paths.stylePath))) {
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
	if (paths.assetDir && (await pathExists(paths.assetDir))) {
		console.log(`  ${paths.assetDir}`)
	}

	if (parsed.openFolder) {
		try {
			if (paths.assetDir) {
				openInFinder(paths.assetDir)
			}
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
