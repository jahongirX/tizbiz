# Navbat platform

Booking + CRM/loyalty + AI platform for local service businesses (Surxondaryo/Termiz).
Telegram-native, multi-tenant. See [CLAUDE.md](CLAUDE.md) for context and the phase specs
(`phase-*.md`) for the roadmap.

## Application topology

The repo root is one Yii2 advanced app. Each **tier** is a top-level directory with its own
`web/` document root, mapped to a domain. The three web tiers serve a built Vue SPA
(`common/web/SpaController` serves `<tier>/web/app/index.html`, injecting `window.__NAVBAT__`).

| Tier | Domain | SPA (`apps/*`) | Role |
|---|---|---|---|
| `frontend/` | `navbat.uz` | `corporate` | Corporate seller / marketing page |
| `backend/` | `admin.navbat.uz` | `admin` | Business admin dashboard |
| `tenant/` | `{slug}.navbat.uz` | `booking` | Per-business consumer booking site |
| `api/` | `api.navbat.uz` | — | REST API (JSON, JWT, RBAC-by-role, CORS) |
| `console/` | — | — | Migrations & CLI (`migrate`, `seed`, `reminder`) |
| `common/` | — | — | Shared models, JWT, tenant scoping, REST base, envelope |

The tenant tier reads the business slug from the `Host` header (wildcard `*.navbat.uz`) and
injects it into the SPA. Reserved subdomains (`www`, `api`, `admin`, `app`) are not tenants.

## Status — Phase 1 (MVP core): complete & verified

- **API** — 7 modules under `api/modules/` (`auth, booking, crm, loyalty, billing, notify, site`)
  over 17 models. Multi-tenant isolation (auto query scoping by the JWT's business), JWT auth +
  per-tenant roles, `{data|errors}` envelope, atomic loyalty ledger, transactional booking
  (no double-book), availability with timezone math, Payme/Click deposit + webhooks, Telegram/SMS
  reminders. Verified: `scratchpad/e2e.py` → **15/15** (register→login→setup→availability→book→
  complete→auto-cashback→deposit); all 91 PHP files lint clean; CORS preflight OK.
- **Frontend** — 3 Vue 3 SPAs built into their tiers and served with bootstrap injection.
- Built with a multi-agent workflow + adversarial review (all critical/major findings fixed).

## Running

Requires PHP 8.1+, Node 20+, and MySQL 8 (SQLite works for local testing). Composer + pnpm deps installed.

### Backend

```bash
# Config is env-driven — no committed secrets.
export DB_DSN='mysql:host=127.0.0.1;dbname=navbat' DB_USER='root' DB_PASSWORD='' JWT_SECRET='change-me'
php yii migrate            # 17 Phase 1 migrations
php yii seed/demo          # optional demo tenant (login +998900000001 / secret123)

# Serve the API (dev). Point each domain/vhost at <tier>/web in production.
php -S 127.0.0.1:8899 -t api/web api/web/router.php
```

Local SQLite variant (no MySQL needed):
`DB_DSN="sqlite:$(pwd)/runtime/dev.sqlite" php yii migrate && … seed/demo && … -S … -t api/web`.

### Frontend

```bash
corepack pnpm install
corepack pnpm -r build            # builds apps/* into frontend|backend|tenant /web/app/
# dev with hot reload (calls the API at window.__NAVBAT__.apiBase, default http://127.0.0.1:8899):
corepack pnpm --filter @navbat/admin dev
```

Each web tier then serves its SPA (SPA history fallback via `web/.htaccess` in production).

## Conventions

Money in **tiyin** (1/100 so'm); times stored **UTC**, shown in `Asia/Tashkent`. Migrations only
(never hand DDL). Env vars: `DB_*`, `JWT_SECRET`, `API_BASE`, `ROOT_DOMAIN`, `APP_ORIGINS`,
`PAYME_*`, `CLICK_*`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_WEBHOOK_SECRET`, `SMS_*`.
