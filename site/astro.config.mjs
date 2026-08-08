import { defineConfig } from 'astro/config'
import compressor from 'astro-compressor'
import minifyHtml from 'astro-minify-html'

export default defineConfig({
	outDir: './deploy/public',
	site: 'https://remino.net/remutils/',
	trailingSlash: 'always',
	integrations: [
		minifyHtml({
			collapseWhitespace: true,
			minifyCSS: true,
			minifyJS: true,
			removeComments: true,
		}),
		compressor({
			fileExtensions: ['.css', '.js', '.html', '.xml', '.cjs', '.mjs', '.svg'],
		}),
	],
	build: {
		assets: 'remutils',
	},
	vite: {
		build: {
			assetsInlineLimit: 0,
		},
	},
})
