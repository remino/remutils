// @ts-check

/**
 * Minimal frontmatter extraction helpers.
 *
 * @module lib/frontmatter
 */

/**
 * Return the raw YAML frontmatter block from a Markdown source string.
 *
 * @param {string} source
 * @returns {string}
 */
export const frontmatter = source => {
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

/**
 * Read a scalar frontmatter value by key.
 *
 * @param {string} source
 * @param {string} key
 * @returns {string | undefined}
 */
export const frontmatterString = (source, key) => {
	const match = frontmatter(source).match(
		new RegExp(`^${key}:\\s*(.+?)\\s*$`, 'm')
	)

	return match ? unquoteYamlString(match[1]) : undefined
}

/**
 * Read a boolean-like frontmatter value.
 *
 * Only canonical `true` and `false` values are accepted so callers can
 * distinguish missing data from loosely formatted user content.
 *
 * @param {string} source
 * @param {string} key
 * @returns {boolean | undefined}
 */
export const frontmatterBoolean = (source, key) => {
	const value = frontmatterString(source, key)

	if (value === undefined) {
		return undefined
	}

	if (/^(true|false)$/i.test(value)) {
		return value.toLowerCase() === 'true'
	}

	return undefined
}

/**
 * Remove the first YAML frontmatter block from a Markdown source string.
 *
 * @param {string} source
 * @returns {string}
 */
export const stripFrontmatter = source =>
	source.replace(/^---\n[\s\S]*?\n---(?:\n|$)/, '')

/**
 * Strip the first top-level ATX heading from a Markdown document.
 *
 * This is used during import so title-only source files become clean body
 * content without duplicating the title into template frontmatter.
 *
 * @param {string} source
 * @returns {{ body: string, title: string | undefined }}
 */
export const stripFirstHeading = source => {
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
