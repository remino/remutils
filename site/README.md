# remutils site

Astro 7 site for the remutils documentation. Tool pages are generated directly
from the top-level tool `README.md` files, so their documentation remains
canonical in each tool directory. Each tool is published at its first-class
path, such as `/mkx/`; `/remutils/` remains the collection home.

```sh
npm install
npm run dev
npm run build
npm run deploy:dryrun
npm run deploy
```

The build uses an EJS template to write `deploy/nginx/remutils.conf`, which
permanently redirects the legacy `/remutils/<tool>/` paths to their
corresponding first-class paths.

Set `RSDEPLOY_DEST` in a local `.env` to deploy the generated `deploy/public/`
directory. From the repository root, `just serve` starts the Astro development
server.

The site shares the `remino.net` navigation assets at `/nav/` and its font
assets at `/fonts/`, as does remarqueeble. During local development, Astro
proxies both paths from the sibling `remino.net` build.
