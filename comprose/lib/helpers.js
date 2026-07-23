import { mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const cleanupPaths = []
const libDir = dirname(fileURLToPath(import.meta.url))

export const createProject = async (name = 'site') => {
	const dir = await mkdtemp(join(tmpdir(), `comprose-${name}-`))
	cleanupPaths.push(dir)
	return dir
}

export const cleanupProjects = async () => {
	while (cleanupPaths.length > 0) {
		await rm(cleanupPaths.pop(), { force: true, recursive: true })
	}
}

export const importFresh = async (relativePath, cwd) => {
	const absolutePath = resolve(libDir, relativePath)
	const previousCwd = process.cwd()

	process.chdir(cwd)
	try {
		return await import(
			`${pathToFileURL(absolutePath).href}?t=${Date.now()}-${Math.random()}`
		)
	} finally {
		process.chdir(previousCwd)
	}
}

export const captureConsole = async callback => {
	const logs = []
	const errors = []
	const originalLog = console.log
	const originalError = console.error

	console.log = (...args) => {
		logs.push(args.join(' '))
	}
	console.error = (...args) => {
		errors.push(args.join(' '))
	}

	try {
		await callback({ errors, logs })
	} finally {
		console.log = originalLog
		console.error = originalError
	}

	return { errors, logs }
}

export const withStdinTty = async callback => {
	const originalDescriptor = Object.getOwnPropertyDescriptor(
		process.stdin,
		'isTTY'
	)

	Object.defineProperty(process.stdin, 'isTTY', {
		configurable: true,
		value: true,
	})

	try {
		return await callback()
	} finally {
		if (originalDescriptor) {
			Object.defineProperty(process.stdin, 'isTTY', originalDescriptor)
		}
	}
}
