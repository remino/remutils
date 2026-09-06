import { defineConfig } from 'astro/config'
import nginxConfig from '@remino/astro-nginx-config'
import compressor from 'astro-compressor'
import minifyHtml from 'astro-minify-html'
import { getTools } from './src/lib/tools'

const tools = (await getTools()).map(tool => ({
	name: tool.name,
	regex: tool.name.replace(/[\\^$.*+?()[\]{}|]/g, '\\$&'),
}))

export default defineConfig({
	outDir: './deploy/public',
	site: 'https://remino.net/',
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
			zstd: false,
		}),
		nginxConfig({
			template: 'src/nginx/remutils.conf.ejs',
			output: 'nginx/remutils.conf',
			variables: { tools },
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
