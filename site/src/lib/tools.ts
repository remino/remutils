import { readdir, readFile, stat } from 'node:fs/promises'
import { join } from 'node:path'
import { marked } from 'marked'

const repositoryRoot = join(process.cwd(), '..')

export interface Tool {
	description: string
	html: string
	name: string
}

function descriptionFrom(markdown: string) {
	return markdown
		.split('\n')
		.slice(1)
		.find(line => line.trim() && !line.startsWith('<!--'))
		?.trim()
		.replace(/^\*|\*$/g, '')
}

export async function getTools(): Promise<Tool[]> {
	const entries = await readdir(repositoryRoot, { withFileTypes: true })
	const tools = await Promise.all(
		entries
			.filter(entry => entry.isDirectory() && !entry.name.startsWith('.'))
			.map(async entry => {
				const readmePath = join(repositoryRoot, entry.name, 'README.md')
				const executablePath = join(repositoryRoot, entry.name, entry.name)

				try {
					if (!(await stat(executablePath)).isFile()) {
						return undefined
					}

					const markdown = await readFile(readmePath, 'utf8')
					return {
						description: descriptionFrom(markdown) ?? '',
						html: await marked.parse(markdown),
						name: entry.name,
					}
				} catch {
					return undefined
				}
			})
	)

	return tools
		.filter((tool): tool is Tool => Boolean(tool))
		.sort((a, b) => a.name.localeCompare(b.name))
}
