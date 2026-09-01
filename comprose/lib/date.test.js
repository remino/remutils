import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { formatLocalIso, parseDateInput, toLocalDateString } from './date.js'

describe('date', () => {
	it('parses date-only input', () => {
		const now = new Date('2026-07-23T12:34:56+09:00')
		const parsed = parseDateInput('2026-05-06', now)

		assert.equal(parsed.fileDate, '2026-05-06')
		assert.match(parsed.frontmatterDate, /^2026-07-23T12:34:56\+09:00$/)
	})

	it('parses local datetime input without offset', () => {
		const now = new Date('2026-07-23T12:34:56+09:00')
		const parsed = parseDateInput('2026-05-06T08:30:00', now)

		assert.equal(parsed.fileDate, '2026-05-06')
		assert.equal(parsed.frontmatterDate, '2026-05-06T08:30:00+09:00')
	})

	it('formats local dates', () => {
		const date = new Date('2026-07-23T12:34:56+09:00')

		assert.equal(toLocalDateString(date), '2026-07-23')
		assert.equal(formatLocalIso(date, 540), '2026-07-23T12:34:56+09:00')
	})
})
