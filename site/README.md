# remutils site

Astro 7 site for the remutils documentation. Tool pages are generated directly
from the top-level tool `README.md` files, so their documentation remains
canonical in each tool directory.

```sh
npm install
npm run dev
npm run build
npm run deploy:dryrun
npm run deploy
```

Set `RSDEPLOY_DEST` in a local `.env` to deploy the generated `dist/` directory.
From the repository root, `just serve` starts the Astro development server.

The site shares the `remino.net` navigation assets at `/nav/` and its font
assets at `/fonts/`, as does remarqueeble.
