import { readFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { fail, parseArgs, usage } from './cli.js'
import { EXIT_IMPORT_CONFLICT } from './constants.js'
import { createEntry } from './create.js'
import { importDirectory } from './import.js'
import { resolveConfig } from './templates.js'

export const main = async (argv = process.argv.slice(2)) => {
	let parsed
	try {
		parsed = parseArgs(argv)
	} catch (error) {
		fail(error instanceof Error ? error.message : String(error))
		return
	}

	if (
		!parsed.command ||
		parsed.command === 'help' ||
		parsed.command === '-h' ||
		parsed.command === '--help'
	) {
		usage()
		return
	}

	if (
		parsed.command === '-v' ||
		parsed.command === '--version' ||
		parsed.command === 'version'
	) {
		const packageJsonPath = resolve(
			dirname(fileURLToPath(import.meta.url)),
			'..',
			'package.json'
		)
		const packageJson = JSON.parse(await readFile(packageJsonPath, 'utf8'))
		console.log(`comprose ${packageJson.version}`)
		return
	}

	const config = await resolveConfig(parsed)

	if (parsed.command === 'import') {
		if (!parsed.sourceDir) {
			fail('missing directory path for import')
			usage()
			return
		}

		try {
			await importDirectory(
				config,
				parsed.sourceDir,
				{
					edit: parsed.edit,
					force: parsed.force,
					openFolder: parsed.openFolder,
				},
				{ fail }
			)
		} catch (error) {
			const exitCode =
				error instanceof Error && /overwrite existing entry/.test(error.message)
					? EXIT_IMPORT_CONFLICT
					: 1
			fail(error instanceof Error ? error.message : String(error), exitCode)
		}

		return
	}

	if (parsed.command !== 'new') {
		fail(`unknown command "${parsed.command}"`)
		usage()
		return
	}

	await createEntry(config, parsed, { fail, usage })
}
