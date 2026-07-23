import { afterEach, describe, it } from 'node:test'
import assert from 'node:assert/strict'
import {
	captureConsole,
	cleanupProjects,
	createProject,
	importFresh,
} from './helpers.js'

afterEach(cleanupProjects)

describe('main', () => {
	it('prints help for the help command', async () => {
		const dir = await createProject('main-help')
		const { main } = await importFresh('./main.js', dir)

		const { logs } = await captureConsole(async () => {
			await main(['help'])
		})

		assert.match(logs.join('\n'), /^USAGE: comprose <command>/)
	})

	it('prints the version for the version command', async () => {
		const dir = await createProject('main-version')
		const { main } = await importFresh('./main.js', dir)

		const { logs } = await captureConsole(async () => {
			await main(['version'])
		})

		assert.deepEqual(logs, ['comprose 0.1.0'])
	})
})
