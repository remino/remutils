import { parseDateInput } from './date.js'
import { normalizeProject } from './text.js'

export const usage = () => {
	console.log(`USAGE: comprose <command> [<options>] [<args>]

Create and import prose content entries.

COMMANDS:

	help                         Show this help screen.
	import <path>                Import a directory into a new content entry.
	new                          Create a new content entry scaffold.
	version                      Show script name and version number.

OPTIONS:

	-c, --collection <name>      Content collection name. Defaults to the current directory name.
	-d <iso-8601>                Date in ISO 8601 format.
	-e                           Open created text files in $EDITOR after scaffolding.
	-f                           Reimport and replace an existing generated entry.
	-g <tag>                     Tag to add to frontmatter. Can be repeated.
	-h, --help                   Show this help screen.
	-i <path>                    Image file to copy into the entry asset directory. Can be repeated.
	-k, --type, --kind <kind>    Entry type: article or note. Default: article.
	-o                           Open the asset directory after scaffolding.
	-s <slug>                    Entry slug.
	-t <title>                   Entry title.
	-v, --version                Show script name and version number.
	--pubname <name>             Frontmatter pubname.
	--template <name-or-path>    Template layout. Default: default.

STDIN:

	Piped input seeds the entry body for the new command.

EXAMPLES:

	comprose new -c journal -s my-new-entry
	comprose new --template middleman-blog -c posts -t "My New Entry"
	comprose import -c journal /tmp/source-entry
	comprose import --template middleman-blog -c posts /tmp/source-entry -f
`)
}

export const fail = (message, exitCode = 1) => {
	console.error(`error: ${message}`)
	process.exitCode = exitCode
}

export const parseArgs = argv => {
	const args = {
		command: undefined,
		slugParts: [],
		titleParts: [],
		date: undefined,
		type: 'article',
		tags: [],
		imagePaths: [],
		edit: false,
		openFolder: false,
		force: false,
		sourceDir: undefined,
		template: undefined,
		collection: undefined,
		pubname: undefined,
	}

	if (argv.length === 0) {
		return args
	}

	args.command = argv[0]

	for (let index = 1; index < argv.length; index += 1) {
		const token = argv[index]
		const nextValue = option => {
			const value = argv[++index]
			if (!value) {
				throw new Error(`missing value for ${option}`)
			}
			return value
		}

		if (token === '-s') {
			args.slugParts.push(nextValue(token))
			continue
		}

		if (token === '-t') {
			args.titleParts.push(nextValue(token))
			continue
		}

		if (token === '-d') {
			args.date = parseDateInput(nextValue(token))
			continue
		}

		if (token === '-k' || token === '--type' || token === '--kind') {
			const value = nextValue(token)
			const normalizedType = value.trim().toLowerCase()
			if (!['article', 'note'].includes(normalizedType)) {
				throw new Error(`invalid entry type "${value}"`)
			}

			args.type = normalizedType
			continue
		}

		if (token === '-g') {
			args.tags.push(nextValue(token))
			continue
		}

		if (token === '-i') {
			args.imagePaths.push(nextValue(token))
			continue
		}

		if (token === '-e') {
			args.edit = true
			continue
		}

		if (token === '-o') {
			args.openFolder = true
			continue
		}

		if (token === '-f') {
			args.force = true
			continue
		}

		if (token === '--template') {
			args.template = nextValue(token)
			continue
		}

		if (
			token === '-c' ||
			token === '--collection' ||
			token === '-p' ||
			token === '--project'
		) {
			args.collection = normalizeProject(nextValue(token))
			continue
		}

		if (token === '--pubname') {
			args.pubname = nextValue(token).trim()
			continue
		}

		if (token.startsWith('-')) {
			throw new Error(`unknown option "${token}"`)
		}

		if (args.command === 'import') {
			if (args.sourceDir) {
				throw new Error('import accepts only one directory path')
			}

			args.sourceDir = token
			continue
		}

		args.slugParts.push(token)
	}

	return args
}
