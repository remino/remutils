// @ts-check
/** @import {MarkdownMetadata} from './types.js' */

import { readFile, readdir } from 'node:fs/promises'
import { basename, extname, join } from 'node:path'
import { defaultSlugTitleFiles, supportedImageExtensions } from './constants.js'
import { formatLocalIso } from './date.js'
import {
	frontmatterBoolean,
	frontmatterString,
	stripFirstHeading,
	stripFrontmatter,
} from './frontmatter.js'
import { humanizeSlug, normalizeSlug } from './text.js'

const isMarkdownFile = name => {
	const lowerName = name.toLowerCase()

	return lowerName.endsWith('.md') || lowerName.endsWith('.markdown')
}

const isSupportedImageFile = name =>
	supportedImageExtensions.has(extname(name).toLowerCase())

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

/**
 * Rewrite markdown image and link references using a generated asset map.
 *
 * @param {string} source
 * @param {Map<string, string>} assetMap
 * @returns {string}
 */
export const rewriteAssetReferences = (source, assetMap) => {
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

/**
 * Rewrite a single asset-like frontmatter reference.
 *
 * @param {string} value
 * @param {Map<string, string>} assetMap
 * @returns {string}
 */
export const rewriteAssetReference = (value, assetMap) => {
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

/**
 * Return the set of image files from the source directory that are referenced
 * by the markdown body or relevant frontmatter fields.
 *
 * @param {string} body
 * @param {string | string[] | undefined} frontmatterImage
 * @param {Map<string, string>} sourceFiles
 * @returns {string[]}
 */
export const collectReferencedImageFiles = (
	body,
	frontmatterImage,
	sourceFiles
) => {
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

/**
 * Resolve import metadata from a source directory.
 *
 * This chooses the primary markdown file, derives the output slug and type,
 * and lifts frontmatter into a normalized shape that templates can consume.
 *
 * @param {string} sourceDir
 * @returns {Promise<MarkdownMetadata>}
 */
export const resolveMarkdownMetadata = async sourceDir => {
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
