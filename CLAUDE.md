# CLAUDE.md — TizBiz Platform (ishchi nom)

> Bu fayl loyihaning doimiy kontekstini saqlaydi. Har fazaning batafsil spesifikatsiyasi `docs/` papkasida.
> Ishchi nom "TizBiz" — yakuniy brend keyin belgilanadi.

## 1. Loyiha nima

Surxondaryo/Termiz xizmat bizneslari uchun **onlayn borliq + booking + CRM/loyallik + AI** platformasi. Telegram-native.

Asosiy pozitsiya: **"arzon YClients" EMAS.** Farqimiz — mahalliy bizneslarda sayti yo'q, shuning uchun biz **brendlangan mini-sayt + Telegram bot + booking**ni qutida beramiz. Bu YClients Rossiyada qilmagan narsa (u yerda bizneslarda sayt bor edi).

Ikki daromad mantig'i, aralashtirilmaydi:
- **Booking bizneslari** (barber, salon, klinika, stomatologiya, UZI, tort, kelin ko'ylak, repetitor) → **obuna (SaaS)**, komissiya emas.
- **Uy-xizmat** (hamshira, massaj, santexnik) → **komissiya** (yangi mijoz + ishonch qiymati bor).

## 2. Stek

- **Backend:** PHP 8.2, Yii2 (advanced template), REST API, RBAC
- **DB:** MySQL 8
- **Auth:** JWT + subdomen bo'yicha SSO
- **Realtime:** Centrifugo (booking/navbat yangilanishi, bildirishnomalar)
- **Frontend:** Vue 3 (Composition API) + Vite, Pinia, Vue Router
- **Monorepo:** pnpm workspaces (bir nechta Vue SPA: `admin`, `consumer`, `superadmin`)
- **To'lov:** Payme + Click (prepayment + float)
- **Xabar:** Telegram Bot API + SMS gateway
- **Deploy:** cPanel/VPS, Cloudflare (subdomen + SSL wildcard)

## 3. Monorepo tuzilishi

Repo ildizi = Yii2 advanced root. Har application = ildizdagi alohida tier; har web
tier `web/` dan Vue SPA'ni serve qiladi (build `apps/*` dan shu tierning `web/` iga tushadi).

```
/api                # Yii2 tier: REST API            -> api.tizbiz.uz
  /modules          # har biznes-domen alohida modul (booking, crm, billing, ...)
/frontend           # Yii2 tier: corporate seller page (SPA shell) -> tizbiz.uz
/backend            # Yii2 tier: biznes admin dashboard (SPA shell) -> admin.tizbiz.uz
/tenant             # Yii2 tier: per-biznes subdomain sayt (SPA shell) -> {slug}.tizbiz.uz
/console            # Yii2 tier: migratsiyalar + CLI komandalar
/common             # umumiy modellar, komponentlar (Jwt), web/SpaController + spa-shell
/apps
  /corporate        # Vue 3 SPA -> frontend/web
  /admin            # Vue 3 SPA -> backend/web
  /booking          # Vue 3 SPA (iste'molchi + Telegram Mini-App) -> tenant/web
  /superadmin       # Vue 3 SPA (platforma boshqaruvi) — keyin
/packages
  /ui               # umumiy Vue komponentlar, dizayn tokenlari
  /api-client       # generatsiya qilingan REST client
```

Eslatma: `tenant` hozircha bir monorepo ichida (umumiy `vendor`/`common`/`console`);
kerak bo'lsa keyin alohida standalone Yii2 (basic) app'ga ajratsa bo'ladi. Har web tier
subdomain'ni Host header'dan aniqlaydi (`common\web\SpaController`).

## 4. Arxitektura tamoyillari

- **Multi-tenant:** har biznes = tenant. Har so'rovda `tenant_id` kontekst. Ma'lumotlar tenant bo'yicha izolyatsiya (query scope + RBAC).
- **Subdomen:** brendlangan saytlar `{{business-slug}}.tizbiz.uz` da; wildcard DNS + Cloudflare.
- **API format:** REST, JSON, `data`/`meta`/`errors` konverti; xatolarda RFC-7807 uslubi.
- **Idempotentlik:** to'lov va booking yaratishda idempotency-key.
- **Migratsiyalar:** har schema o'zgarishi Yii2 migration bilan; hech qachon qo'lda DDL.
- **Feature-flag:** har faza dvigatelini flag ortida yoqamiz (`ai_seller`, `restaurant`, `home_services`, `consumer_premium`).

## 5. Rollar (RBAC)

`superadmin`, `business_owner`, `business_admin`, `staff` (masalan registratura/usta/shifokor), `consumer`, `provider` (uy-xizmat mutaxassisi). Rollar tenant doirasida amal qiladi (superadmin bundan mustasno).

## 6. Fazalar xaritasi (ketma-ketlik MUHIM)

| Faza | Dvigatel | Fayl |
|---|---|---|
| **1 — MVP yadro** | Booking + prepayment + CRM/loyallik + eslatma | `docs/phase-1-mvp-core.md` |
| **1.5 — Sayt+Bot** | Multi-tenant brendlangan mini-sayt + Telegram bot generator | `docs/phase-1.5-site-bot-generator.md` |
| **2 — AI + Restoran** | AI-seller (premium) + restoran zakaz (dostavkasiz) | `docs/phase-2-ai-restaurant.md` |
| **3 — Uy-xizmat** | Komissiya marketplace: vetting + escrow | `docs/phase-3-home-services.md` |
| **4 — Iste'molchi app** | YPLACES-uslub discovery + featured + premium obuna | `docs/phase-4-consumer-app.md` |

**Oltin qoida:** keyingi faza faqat oldingisi likvid (real ishlayotgan biznes/foydalanuvchi) bo'lgach yoqiladi. Hammasini birdan qurmang — YClients erta ortiqcha qurib deyarli o'lgan.

## 7. Umumiy konvensiyalar

- Kod izohlari va commit: inglizcha. UI matni: o'zbek (lotin) + rus (client-facing).
- Branch: `feat/`, `fix/`, `chore/`. PR kichik va faza doirasida.
- Har endpoint uchun request/response tiplari `packages/api-client` da.
- Pul: butun sonlarda **tiyin** (so'mning 1/100) saqlanadi; UI da formatlash.
- Vaqt: UTC saqlash, `Asia/Tashkent` da ko'rsatish.

## 8. Business glossariy

- **Tenant / biznes** — platformaga ulangan xizmat ko'rsatuvchi.
- **Prepayment / depozit** — no-show'ni to'xtatuvchi oldindan to'lov.
- **Float** — prepayment/zakaz ustidan olinadigan kichik platforma ustamasi.
- **AI-seller** — biznes ma'lumotidan javob beruvchi 24/7 savdo-yordamchi bot.
- **Provider** — uy-xizmat mutaxassisi (hamshira, massajist, usta).

## 9. Ish taqsimoti — bizning zona: barber vertikali

Bu repoda bir nechta odam ishlaydi. **Bizning javobgarlik zonamiz — barber vertikali
(`barber` / `salon` → `slot` engine).** O'sha vertikalga tegishli hamma narsaga biz javob
beramiz: backend, admin UI, booking sayti, migratsiya, seed, dizayn.

**Boshqa vertikallarga (cafe/restoran → `catalog` engine, medical va h.k.) tegilmaydi** —
ular boshqa branch egalarining ishi. Ularning fayllarini tuzatmaymiz, refactor qilmaymiz,
"yo'l-yo'lakay yaxshilamaymiz". Bug ko'rsak — aytamiz, lekin o'zimiz tuzatmaymiz.

Bizning zonamizdagi asosiy joylar:
- `common/engines/SlotEngine.php`, `common/engines/EngineFactory.php` (faqat `slot` qismi)
- `apps/booking/src/engines/slot/` — booking SPA'ning slot engine'i
- `apps/admin/src/lib/verticals.js` — `barber` yozuvi
- Barber uchun booking/CRM/loyallik API oqimlari (`api/modules/*` — barber ssenariysi)

**Umumiy (shared) kod** — `common/`, `api/modules/auth`, layout, tokenlar, router — barcha
vertikallarga tegadi. Bunday joyni o'zgartirish kerak bo'lsa: o'zgarish minimal va orqaga
mos (backward-compatible) bo'lsin, boshqa engine'lar xatti-harakati o'zgarmasin.

Branch: barcha ish `jalol` branch'ida; `main`ga merge — admin ishi.
