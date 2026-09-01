#!/usr/bin/env node

import {
	assertDocsWorktree,
	buildApiDocs,
	copyDressCss,
	preparePublishedSite,
	resolveDocsRoot,
	resolvePublishedApiRoot,
	resolvePublishedSiteRoot,
	writeLandingPage,
} from '../lib/docs.js'

const main = async () => {
	const docsRoot = resolveDocsRoot()
	assertDocsWorktree(docsRoot)
	await preparePublishedSite(docsRoot)
	await copyDressCss(docsRoot)
	await writeLandingPage(docsRoot)
	buildApiDocs(docsRoot)

	console.log(`Built docs site:`)
	console.log(`  ${resolvePublishedSiteRoot(docsRoot)}`)
	console.log(`Built API docs:`)
	console.log(`  ${resolvePublishedApiRoot(docsRoot)}`)
}

await main()
