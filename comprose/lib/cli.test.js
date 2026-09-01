import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { captureConsole } from './helpers.js'
import { parseArgs, usage } from './cli.js'

describe('cli', () => {
	it('parses new command options including collection aliases', () => {
		const parsed = parseArgs([
			'new',
			'-p',
			'Journal Entries',
			'--template',
			'middleman-blog',
			'-d',
			'2026-07-23',
			'-t',
			'Hello Entry',
			'-g',
			'terminal, css',
			'-i',
			'/tmp/image.png',
			'-e',
			'-o',
		])

		assert.equal(parsed.command, 'new')
		assert.equal(parsed.collection, 'journal-entries')
		assert.equal(parsed.template, 'middleman-blog')
		assert.equal(parsed.date.fileDate, '2026-07-23')
		assert.deepEqual(parsed.titleParts, ['Hello Entry'])
		assert.deepEqual(parsed.tags, ['terminal, css'])
		assert.deepEqual(parsed.imagePaths, ['/tmp/image.png'])
		assert.equal(parsed.edit, true)
		assert.equal(parsed.openFolder, true)
	})

	it('parses import source directories', () => {
		const parsed = parseArgs(['import', '-c', 'notes', 'source-entry'])

		assert.equal(parsed.command, 'import')
		assert.equal(parsed.collection, 'notes')
		assert.equal(parsed.sourceDir, 'source-entry')
	})

	it('prints the remutils usage screen', async () => {
		const { logs } = await captureConsole(async () => {
			usage()
		})

		assert.match(logs.join('\n'), /^USAGE: comprose <command>/)
		assert.match(logs.join('\n'), /\nCOMMANDS:\n/)
		assert.match(logs.join('\n'), /\nOPTIONS:\n/)
	})
})
