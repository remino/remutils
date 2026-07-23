import { extname } from 'node:path'

export const stripDiacritics = value =>
	value.normalize('NFKD').replace(/[\u0300-\u036f]/g, '')

export const normalizeSlug = value =>
	stripDiacritics(value)
		.replace(/[_\s]+/g, '-')
		.replace(/[^a-zA-Z0-9-]+/g, '-')
		.replace(/-+/g, '-')
		.replace(/^-|-$/g, '')
		.toLowerCase()

export const normalizeProject = value => {
	const collection = normalizeSlug(value)
	if (!collection) {
		throw new Error(`collection "${value}" normalised to an empty value`)
	}

	return collection
}

export const humanizeSlug = slug =>
	slug
		.split('-')
		.filter(Boolean)
		.map(part => part.charAt(0).toUpperCase() + part.slice(1))
		.join(' ')

export const pad2 = value => String(value).padStart(2, '0')

export const quoteShellArg = value => `'${value.replace(/'/g, `'\\''`)}'`

export const normalizeTagList = values => [
	...new Set(
		values
			.flatMap(value => value.split(','))
			.map(value => value.trim())
			.filter(Boolean)
	),
]

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

export const uniqueName = (name, existingNames) => {
	if (existingNames.has(name)) {
		throw new Error(`duplicate output asset name "${name}"`)
	}

	existingNames.add(name)
	return name
}

export const hasValue = value =>
	value !== undefined && value !== null && String(value).trim() !== ''
