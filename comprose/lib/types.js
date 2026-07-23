// @ts-check

/**
 * Shared JSDoc typedefs for `comprose`.
 *
 * This file exists so the rest of the codebase can use `import('./types.js').X`
 * without duplicating object-shape annotations across modules.
 */

/**
 * Parsed date information used by both `new` and `import`.
 *
 * @typedef {object} ParsedDate
 * @property {string} input Original user input.
 * @property {Date} parsed Parsed JavaScript date.
 * @property {string} fileDate `YYYY-MM-DD` date used in path segments.
 * @property {string} frontmatterDate ISO date string written to frontmatter.
 */

/**
 * Parsed CLI arguments.
 *
 * @typedef {object} ParsedArgs
 * @property {string | undefined} command Requested subcommand.
 * @property {string[]} slugParts Positional slug parts.
 * @property {string[]} titleParts Title fragments from `-t`.
 * @property {ParsedDate | undefined} date Parsed date option.
 * @property {'article' | 'note'} type Entry type.
 * @property {string[]} tags Tag arguments before normalization.
 * @property {string[]} imagePaths Image file paths to copy into the entry.
 * @property {boolean} edit Whether to open created text files in `$EDITOR`.
 * @property {boolean} openFolder Whether to open the asset folder in Finder.
 * @property {boolean} force Whether to overwrite an existing import.
 * @property {string | undefined} sourceDir Import source directory.
 * @property {string | undefined} template Template name or path.
 * @property {string | undefined} collection Normalized content collection.
 * @property {string | undefined} pubname Frontmatter pubname override.
 */

/**
 * Resolved template directory.
 *
 * @typedef {object} TemplateRef
 * @property {string} dir Absolute template directory path.
 * @property {string} name Built-in name or user-supplied template identifier.
 */

/**
 * Runtime configuration derived from the current project and CLI arguments.
 *
 * @typedef {object} ResolvedConfig
 * @property {string} collection Content collection name.
 * @property {string} project Back-compat alias for collection-oriented templates.
 * @property {string} pubname Frontmatter pubname value.
 * @property {TemplateRef} template Resolved template directory and name.
 */

/**
 * Individual file emitted from a template tree.
 *
 * @typedef {object} TemplateFilePlan
 * @property {string} outputPath Absolute path to write.
 * @property {string} outputRelativePath Template-relative rendered path.
 * @property {string} sourcePath Absolute template source path.
 * @property {boolean} template Whether the source should be rendered via Mustache.
 */

/**
 * Resolved output plan for a single entry scaffold.
 *
 * @typedef {object} TemplatePlan
 * @property {string | undefined} assetDir Absolute asset directory path.
 * @property {string | undefined} assetDirRelative Asset directory path relative to the repo root.
 * @property {string} contentDir Absolute content directory path.
 * @property {string} entryPath Absolute path to the main markdown entry file.
 * @property {TemplateFilePlan[]} files Files to render or copy.
 * @property {string} label Human-facing identifier printed to stdout.
 * @property {(fileName: string) => string} publicAssetPath Maps an asset file name to its published reference.
 * @property {string | undefined} stylePath Absolute stylesheet output path.
 * @property {string | undefined} styleValue Stylesheet frontmatter value.
 * @property {boolean} usesStyle Whether the template includes a stylesheet file.
 */

/**
 * Markdown metadata extracted from an imported source directory.
 *
 * @typedef {object} MarkdownMetadata
 * @property {string} body Markdown body without frontmatter or stripped title heading.
 * @property {string} catname Category name used by some templates.
 * @property {string} date Frontmatter date string.
 * @property {string | undefined} deck Optional deck text.
 * @property {string | undefined} description Optional description text.
 * @property {boolean | undefined} draft Draft flag.
 * @property {string | undefined} image Primary image reference.
 * @property {string | undefined} kicker Optional kicker text.
 * @property {string} markdownFileName Selected markdown file name.
 * @property {string} markdownPath Absolute selected markdown file path.
 * @property {string | undefined} original_date Original publication date.
 * @property {string | undefined} share Share image alias from legacy frontmatter.
 * @property {string | undefined} share_image Explicit share image reference.
 * @property {string} slug Derived entry slug.
 * @property {string | undefined} subtitle Optional subtitle text.
 * @property {string | undefined} summary Optional summary text.
 * @property {string | undefined} tags Optional raw tag string.
 * @property {string} title Resolved title.
 * @property {'article' | 'note'} type Entry type inferred from the source file.
 */

/**
 * Imported image asset that will be copied or converted into the destination.
 *
 * @typedef {object} ImageAsset
 * @property {string} inputPath Absolute source path.
 * @property {string} outputFileName Final file name in the destination asset directory.
 * @property {string} outputPath Absolute output path.
 * @property {string} publicPath Published path reference written into markdown/frontmatter.
 * @property {string} [sourceName] Original source file name.
 */

/**
 * Metadata values exposed to templates in addition to the common scaffold
 * fields.
 *
 * @typedef {object} TemplateMetadata
 * @property {string | undefined} [catname]
 * @property {string | undefined} [deck]
 * @property {string | undefined} [description]
 * @property {boolean | undefined} [draft]
 * @property {string | undefined} [kicker]
 * @property {string | undefined} [original_date]
 * @property {string | undefined} [share_image]
 * @property {string | undefined} [subtitle]
 * @property {string | undefined} [summary]
 */

/**
 * Mustache context exposed to template files.
 *
 * @typedef {object} TemplateContext
 * @property {string | undefined} assetDir
 * @property {string} body
 * @property {string} catname
 * @property {string} contentDir
 * @property {string} date
 * @property {string} dateString
 * @property {string | undefined} description
 * @property {boolean | undefined} draft
 * @property {string | undefined} deck
 * @property {string} entryPath
 * @property {string} frontmatterDate
 * @property {boolean} hasDeck
 * @property {boolean} hasDescription
 * @property {boolean} hasDraft
 * @property {boolean} hasImage
 * @property {boolean} hasKicker
 * @property {boolean} hasOriginalDate
 * @property {boolean} hasShareImage
 * @property {boolean} hasStyle
 * @property {boolean} hasSubtitle
 * @property {boolean} hasSummary
 * @property {boolean} hasTags
 * @property {string | undefined} image
 * @property {string | undefined} kicker
 * @property {string | undefined} original_date
 * @property {string} collection
 * @property {string} project
 * @property {string} pubname
 * @property {string} publicPrefix
 * @property {string | undefined} share_image
 * @property {string} slug
 * @property {string | undefined} style
 * @property {string | undefined} stylePath
 * @property {string} stylePrefix
 * @property {string | undefined} subtitle
 * @property {string | undefined} summary
 * @property {string} tags
 * @property {string} title
 * @property {'article' | 'note'} type
 */

export {}
