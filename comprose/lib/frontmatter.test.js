import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import {
	frontmatterBoolean,
	frontmatterString,
	stripFirstHeading,
	stripFrontmatter,
} from './frontmatter.js'

describe('frontmatter', () => {
	it('reads frontmatter strings and booleans', () => {
		const source = `---
title: Hello
draft: true
---

Body
`

		assert.equal(frontmatterString(source, 'title'), 'Hello')
		assert.equal(frontmatterBoolean(source, 'draft'), true)
	})

	it('strips frontmatter and first heading', () => {
		const source = `---
title: Hello
---

# Heading

Body
`

		const withoutFrontmatter = stripFrontmatter(source)
		const stripped = stripFirstHeading(withoutFrontmatter)

		assert.doesNotMatch(withoutFrontmatter, /^---/)
		assert.equal(stripped.title, 'Heading')
		assert.equal(stripped.body.trim(), 'Body')
	})
})
