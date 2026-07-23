import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { readStdin, runImageOptim } from './system.js'
import { withStdinTty } from './helpers.js'

describe('system', () => {
	it('skips image optimization when no files are provided', () => {
		assert.equal(runImageOptim([]), undefined)
	})

	it('returns an empty string when stdin is a tty', async () => {
		await withStdinTty(async () => {
			assert.equal(await readStdin(), '')
		})
	})
})
