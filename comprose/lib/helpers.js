// @ts-check

import { mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

/** @type {string[]} */
const cleanupPaths = []
const libDir = dirname(fileURLToPath(import.meta.url))

/**
 * Create a temporary project directory for tests and remember it for cleanup.
 *
 * @param {string} [name='site']
 * @returns {Promise<string>}
 */
export const createProject = async (name = 'site') => {
	const dir = await mkdtemp(join(tmpdir(), `comprose-${name}-`))
	cleanupPaths.push(dir)
	return dir
}

/**
 * Remove all test directories created through `createProject()`.
 *
 * @returns {Promise<void>}
 */
export const cleanupProjects = async () => {
	while (cleanupPaths.length > 0) {
		await rm(cleanupPaths.pop(), { force: true, recursive: true })
	}
}

/**
 * Import a module with a fresh cache key while temporarily changing cwd.
 *
 * Some runtime modules capture `process.cwd()` at import time, so tests use
 * this helper to exercise them against isolated temporary projects.
 *
 * @param {string} relativePath
 * @param {string} cwd
 * @returns {Promise<Record<string, unknown>>}
 */
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

/**
 * Capture console output during a callback.
 *
 * @template T
 * @param {(capture: { logs: string[], errors: string[] }) => Promise<T> | T} callback
 * @returns {Promise<{ logs: string[], errors: string[] }>}
 */
export const captureConsole = async callback => {
	/** @type {string[]} */
	const logs = []
	/** @type {string[]} */
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

/**
 * Temporarily force stdin to look like a TTY for tests that should not try to
 * read piped input.
 *
 * @template T
 * @param {() => Promise<T> | T} callback
 * @returns {Promise<T>}
 */
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
