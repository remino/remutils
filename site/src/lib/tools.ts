import { readdir, readFile, stat } from 'node:fs/promises'
import { join } from 'node:path'
import { marked } from 'marked'
import { gfmHeadingId } from 'marked-gfm-heading-id'
import remarkParse from 'remark-parse'
import remarkStringify from 'remark-stringify'
import remarkToc from 'remark-toc'
import { bundledLanguages, createHighlighter } from 'shiki'
import { unified } from 'unified'

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

marked.use(gfmHeadingId(), { renderer })

function renderMarkdown(markdown: string) {
	return marked.parse(markdown)
}

export interface Tool {
	description: string
	descriptionHtml: string
	html: string
	name: string
}

function descriptionFrom(markdown: string) {
	const lines = markdown.split('\n').slice(1)
	const firstLine = lines.findIndex(
		line => line.trim() && !line.startsWith('<!--')
	)

	if (firstLine === -1) return ''

	const paragraph = []

	for (const line of lines.slice(firstLine)) {
		if (!line.trim()) break
		paragraph.push(line)
	}

	return paragraph
		.join(' ')
		.trim()
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
					const description = descriptionFrom(markdown) ?? ''
					return {
						description,
						descriptionHtml: marked.parseInline(description),
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
	const [beforeTools = '', afterTools = ''] = markdown.split(
		/<!-- mtoc-start -->[\s\S]*?<!-- mtoc-end -->/,
		2
	)
	const homepageMarkdown = await unified()
		.use(remarkParse)
		.use(remarkToc)
		.use(remarkStringify)
		.process(
			`${beforeTools}## Table of Contents\n\n## Tools\n\n<!-- remutils-tools -->\n\n${afterTools}`
		)
	const [beforeToolList = '', afterToolList = ''] = String(
		homepageMarkdown
	).split('<!-- remutils-tools -->', 2)

	return {
		afterTools: renderMarkdown(afterToolList),
		beforeTools: renderMarkdown(beforeToolList.replace(/## Tools\n*$/, '')),
	}
}

export async function getRepositoryLicence() {
	const licence = await readFile(join(repositoryRoot, 'LICENSE.txt'), 'utf8')
	return renderMarkdown(
		`# Licence\n\n${licence.replace(/^ISC License\n+/, '')}`
	)
}
