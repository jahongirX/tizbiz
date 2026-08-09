# apps/ — Vue 3 SPAs

Each SPA is a pnpm workspace package that **builds into a Yii2 web tier's `web/`**. Until an
app is built, that tier serves the placeholder shell from `common/web/spa-shell.php`.

| App | Builds into | Domain | Purpose |
|---|---|---|---|
| `corporate` | `frontend/web/` | `navbat.uz` | Marketing / seller page |
| `admin` | `backend/web/` | `admin.navbat.uz` | Business admin dashboard |
| `booking` | `tenant/web/` | `{slug}.navbat.uz` | Consumer booking + Telegram Mini-App |
| `superadmin` | (own tier, later) | — | Platform administration |

Every app reads bootstrap data injected by the server into `window.__NAVBAT__`:

```js
window.__NAVBAT__ = { app: 'admin', apiBase: 'https://api.navbat.uz', tenantSlug: 'aziza' }
```

Vite `build.outDir` should target the matching tier's `web/`, and the dev server proxies
`/v1` to `apiBase`. Shared UI + the generated REST client live in `packages/`.

> Not scaffolded yet — created in the next step (needs `pnpm`, e.g. `corepack enable pnpm`).
