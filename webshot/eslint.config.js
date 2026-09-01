import js from '@eslint/js';

export default [
	js.configs.recommended,
	{
		ignores: ['node_modules/**', 'coverage/**'],
	},
	{
		files: ['**/*.js'],
		languageOptions: {
			ecmaVersion: 'latest',
			sourceType: 'module',
			globals: {
				URL: 'readonly',
				console: 'readonly',
				process: 'readonly',
				setTimeout: 'readonly',
			},
		},
		rules: {
			'no-console': 'error',
		},
	},
	{
		files: ['tests/**/*.js'],
		languageOptions: {
			globals: {
				afterAll: 'readonly',
				afterEach: 'readonly',
				beforeAll: 'readonly',
				beforeEach: 'readonly',
				describe: 'readonly',
				expect: 'readonly',
				it: 'readonly',
			},
		},
	},
	{
		files: ['tests/fixtures/**/*.js'],
		languageOptions: {
			globals: {
				document: 'readonly',
			},
		},
	},
];
