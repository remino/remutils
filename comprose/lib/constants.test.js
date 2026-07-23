import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import {
	EXIT_IMPORT_CONFLICT,
	assetMarkerName,
	defaultSlugTitleFiles,
	supportedImageExtensions,
} from './constants.js'

describe('constants', () => {
	it('defines the import conflict exit code and asset marker', () => {
		assert.equal(EXIT_IMPORT_CONFLICT, 12)
		assert.equal(assetMarkerName, '.comprose-assets')
	})

	it('includes expected default slug title files and image extensions', () => {
		assert(defaultSlugTitleFiles.has('entry'))
		assert(defaultSlugTitleFiles.has('post'))
		assert(supportedImageExtensions.has('.png'))
		assert(supportedImageExtensions.has('.avif'))
	})
})
