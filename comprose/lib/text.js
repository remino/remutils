// @ts-check

/**
 * Text normalization helpers for slugs, tags, and asset names.
 *
 * @module lib/text
 */

import { extname } from 'node:path'

/**
 * Remove diacritics so generated slugs stay stable across filesystems and
 * templates.
 *
 * @param {string} value
 * @returns {string}
 */
export const stripDiacritics = value =>
	value.normalize('NFKD').replace(/[\u0300-\u036f]/g, '')

/**
 * Normalize arbitrary text into a filesystem- and URL-safe slug.
 *
 * @param {string} value
 * @returns {string}
 */
export const normalizeSlug = value =>
	stripDiacritics(value)
		.replace(/[_\s]+/g, '-')
		.replace(/[^a-zA-Z0-9-]+/g, '-')
		.replace(/-+/g, '-')
		.replace(/^-|-$/g, '')
		.toLowerCase()

/**
 * Normalize a collection or project name and fail if it becomes empty.
 *
 * @param {string} value
 * @returns {string}
 */
export const normalizeProject = value => {
	const collection = normalizeSlug(value)
	if (!collection) {
		throw new Error(`collection "${value}" normalised to an empty value`)
	}

	return collection
}

/**
 * Turn a slug into a title-cased label.
 *
 * @param {string} slug
 * @returns {string}
 */
export const humanizeSlug = slug =>
	slug
		.split('-')
		.filter(Boolean)
		.map(part => part.charAt(0).toUpperCase() + part.slice(1))
		.join(' ')

export const pad2 = value => String(value).padStart(2, '0')

/**
 * Quote a shell argument for use in a simple shell command string.
 *
 * @param {string} value
 * @returns {string}
 */
export const quoteShellArg = value => `'${value.replace(/'/g, `'\\''`)}'`

/**
 * Normalize repeated `-g` tag arguments into a unique list.
 *
 * @param {string[]} values
 * @returns {string[]}
 */
export const normalizeTagList = values => [
	...new Set(
		values
			.flatMap(value => value.split(','))
			.map(value => value.trim())
			.filter(Boolean)
	),
]

/**
 * Generate a unique asset filename by suffixing duplicates numerically.
 *
 * @param {string} name
 * @param {Set<string>} existingNames
 * @returns {string}
 */
export const uniqueAssetName = (name, existingNames) => {
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

/**
 * Claim a unique output name and throw if it already exists.
 *
 * @param {string} name
 * @param {Set<string>} existingNames
 * @returns {string}
 */
export const uniqueName = (name, existingNames) => {
	if (existingNames.has(name)) {
		throw new Error(`duplicate output asset name "${name}"`)
	}

	existingNames.add(name)
	return name
}

/**
 * Check whether a template value is present and non-empty.
 *
 * @param {unknown} value
 * @returns {boolean}
 */
export const hasValue = value =>
	value !== undefined && value !== null && String(value).trim() !== ''
