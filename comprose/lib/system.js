// @ts-check

import { spawnSync } from 'node:child_process'
import { once } from 'node:events'
import sharp from 'sharp'
import { quoteShellArg } from './text.js'

/**
 * Convert an image to AVIF via `sharp`, preserving orientation and bounding it
 * to a reasonable content size for the generated site.
 *
 * @param {string} sourcePath
 * @param {string} destinationPath
 * @returns {Promise<void>}
 */
export const convertImageWithSharp = async (sourcePath, destinationPath) => {
	await sharp(sourcePath)
		.rotate()
		.resize({
			fit: 'inside',
			height: 1280,
			withoutEnlargement: true,
			width: 1280,
		})
		.avif({ quality: 82 })
		.toFile(destinationPath)
}

/**
 * Convert or transform an image via ImageMagick.
 *
 * @param {string} sourcePath
 * @param {string} destinationPath
 * @returns {void}
 */
export const convertImageWithMagick = (sourcePath, destinationPath) => {
	const result = spawnSync(
		'magick',
		[
			sourcePath,
			'-auto-orient',
			'-resize',
			'1280x1280>',
			'-strip',
			destinationPath,
		],
		{
			stdio: 'inherit',
		}
	)

	if (result.error) {
		throw result.error
	}

	if (result.status !== 0) {
		throw new Error(`magick exited with status ${result.status ?? 'unknown'}`)
	}
}

/**
 * Optimize already-generated PNG and GIF files with `image_optim` when it is
 * available on the host machine.
 *
 * @param {string[]} paths
 * @returns {void}
 */
export const runImageOptim = paths => {
	if (paths.length === 0) {
		return
	}

	const result = spawnSync('image_optim', paths, {
		stdio: 'inherit',
	})

	if (result.error) {
		const error = /** @type {NodeJS.ErrnoException} */ (result.error)
		if (error.code === 'ENOENT') {
			console.warn(
				'warning: image_optim not found; skipping PNG/GIF optimization'
			)
			return
		}

		throw error
	}

	if (result.status !== 0) {
		throw new Error(
			`image_optim exited with status ${result.status ?? 'unknown'}`
		)
	}
}

/**
 * Open files in the configured editor.
 *
 * @param {string[]} files
 * @returns {void}
 */
export const openInEditor = files => {
	const editor = process.env.EDITOR?.trim()
	if (!editor) {
		throw new Error('EDITOR is not set')
	}

	const command = `${editor} ${files.map(quoteShellArg).join(' ')}`
	const result = spawnSync(command, {
		stdio: 'inherit',
		shell: true,
	})

	if (result.status !== 0) {
		throw new Error(
			`${editor} exited with status ${result.status ?? 'unknown'}`
		)
	}
}

/**
 * Reveal a path in Finder.
 *
 * @param {string} path
 * @returns {void}
 */
export const openInFinder = path => {
	const result = spawnSync('open', [path], {
		stdio: 'inherit',
	})

	if (result.status !== 0) {
		throw new Error(`Finder exited with status ${result.status ?? 'unknown'}`)
	}
}

/**
 * Read piped stdin content if present.
 *
 * @returns {Promise<string>}
 */
export const readStdin = async () => {
	if (process.stdin.isTTY) {
		return ''
	}

	process.stdin.setEncoding('utf8')

	let body = ''

	process.stdin.on('data', chunk => {
		body += chunk
	})

	await once(process.stdin, 'end')

	return body
}
