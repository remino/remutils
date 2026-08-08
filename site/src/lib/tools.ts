import { readdir, readFile, stat } from 'node:fs/promises'
import { join } from 'node:path'
import { marked } from 'marked'
import { bundledLanguages, createHighlighter } from 'shiki'

const repositoryRoot = join(process.cwd(), '..')
const highlighter = await createHighlighter({
	langs: Object.keys(bundledLanguages),
	themes: ['github-dark'],
})
const renderer = new marked.Renderer()

renderer.code = ({ lang, text }) => {
	const language = lang?.split(/\s+/, 1)[0] || 'text'
	const supportedLanguage = highlighter.getLoadedLanguages().includes(language)

	return `<div class="code-block">${highlighter.codeToHtml(text, {
		lang: supportedLanguage ? language : 'text',
		theme: 'github-dark',
	})}</div>`
}

function renderMarkdown(markdown: string) {
	return marked.parse(markdown, { renderer })
}

function renderTableOfContents(markdown: string) {
	return renderMarkdown(markdown).replace(
		/<ul>[\s\S]*<\/ul>/,
		tableOfContents =>
			tableOfContents
				.replaceAll('<li><p>', '<li>')
				.replaceAll('</a></p>', '</a>')
	)
}

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
						html: await renderMarkdown(markdown),
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

export async function getRepositoryReadmeSections() {
	const markdown = await readFile(join(repositoryRoot, 'README.md'), 'utf8')
	const tocEnd = '<!-- mtoc-end -->'
	const markdownWithTools = markdown.replace(
		tocEnd,
		`- [Tools](#tools)\n\n${tocEnd}`
	)
	const [beforeTools, afterTools = ''] = markdownWithTools.split(tocEnd, 2)

	return {
		beforeTools: renderTableOfContents(`${beforeTools}${tocEnd}`),
		afterTools: renderMarkdown(afterTools),
	}
}

export async function getRepositoryLicence() {
	const licence = await readFile(join(repositoryRoot, 'LICENSE.txt'), 'utf8')
	return renderMarkdown(
		`# Licence\n\n${licence.replace(/^ISC License\n+/, '')}`
	)
}
