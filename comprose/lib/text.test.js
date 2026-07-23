import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import {
	hasValue,
	humanizeSlug,
	normalizeProject,
	normalizeSlug,
	normalizeTagList,
	quoteShellArg,
	uniqueAssetName,
	uniqueName,
} from './text.js'

describe('text', () => {
	it('normalizes slugs and projects', () => {
		assert.equal(normalizeSlug('Héllo_World!!'), 'hello-world')
		assert.equal(normalizeProject('Journal Entries'), 'journal-entries')
		assert.equal(humanizeSlug('hello-world'), 'Hello World')
	})

	it('normalizes tags and shell quoting', () => {
		assert.deepEqual(normalizeTagList(['terminal, css', 'css', 'notes']), [
			'terminal',
			'css',
			'notes',
		])
		assert.equal(quoteShellArg("a'b"), `'a'\\''b'`)
		assert.equal(hasValue(' value '), true)
		assert.equal(hasValue('  '), false)
	})

	it('deduplicates asset names and rejects duplicate unique names', () => {
		const names = new Set()

		assert.equal(uniqueAssetName('image.png', names), 'image.png')
		assert.equal(uniqueAssetName('image.png', names), 'image-2.png')
		assert.equal(uniqueName('share.avif', names), 'share.avif')
		assert.throws(
			() => uniqueName('share.avif', names),
			/duplicate output asset/
		)
	})
})
