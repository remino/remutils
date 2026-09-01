import js from '@eslint/js'
import prettier from 'eslint-config-prettier'
import globals from 'globals'

export default [
	{
		ignores: ['docs/**', 'jsdoc-theme/**', 'node_modules/**'],
	},
	js.configs.recommended,
	{
		files: ['**/*.{js,mjs}'],
		languageOptions: {
			globals: { ...globals.node, console: 'readonly' },
			sourceType: 'module',
		},
	},
	prettier,
]
