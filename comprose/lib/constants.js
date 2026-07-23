// @ts-check

import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export const repoRoot = process.cwd()
export const toolRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
export const defaultSlugTitleFiles = new Set([
	'entry',
	'note',
	'article',
	'post',
])
export const EXIT_IMPORT_CONFLICT = 12
export const assetMarkerName = '.comprose-assets'
export const supportedImageExtensions = new Set([
	'.avif',
	'.gif',
	'.heic',
	'.heif',
	'.jpeg',
	'.jpg',
	'.png',
	'.webp',
])
