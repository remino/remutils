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

export const frontmatterString = (source, key) => {
	const match = frontmatter(source).match(
		new RegExp(`^${key}:\\s*(.+?)\\s*$`, 'm')
	)

	return match ? unquoteYamlString(match[1]) : undefined
}

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

export const stripFrontmatter = source =>
	source.replace(/^---\n[\s\S]*?\n---(?:\n|$)/, '')

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
