# Faza 1.5 — Sayt + Bot generator (asosiy differensiator)

## Maqsad

Biznesga **10 daqiqada brendlangan mini-sayt + Telegram bot**ni qutida berish. Logo/nom/rang tanlaydi → sayt+bot tayyor; CRM'dagi xizmatlar ikkalasida ham ko'rinadi. **Bu narxni ko'taradigan qatlam** (Start→Standart).

## Kirish sharti

Faza 1 yadrosi (booking + CRM + prepayment) 20–50 biznesda ishlab turibdi.

## Scope

**IN:**
- Biznes tema sozlamasi: logo, nom, ranglar, subdomen (`{{slug}}.navbat.uz`)
- Multi-tenant sayt renderer (shablon) — CRM xizmatlaridan avtomatik to'ladi
- Telegram bot: biznes o'z tokenini ulaydi YOKI umumiy bot + deep-link fallback
- CRM ↔ sayt/bot sinxron (bir manba: xizmat/narx/bo'sh vaqt)
- Booking + depozit ham saytda, ham botda ishlaydi

**OUT:** AI-seller (Faza 2), murakkab CMS/sahifa konstruktor (keyin, kerak bo'lsa).

## Funksiyalar

- Admin "Onlayn borliq" bo'limida logo yuklaydi, ranglarni tanlaydi, subdomenni belgilaydi → preview → publish.
- Sayt sahifalari: bosh (brend + xizmatlar + booking CTA), xizmatlar, mutaxassislar, kontakt, booking.
- Bot: `/start` → xizmat tanlash → slot → depozit → tasdiq; eslatma botdan keladi.
- Token ulash: onboarding'da **platforma o'zi ulab beradi** (non-texnik biznes uchun), yoki BotFather qo'llanmasi.

## Ma'lumotlar bazasi (qo'shimcha)

- `business_sites`: id, business_id, subdomain, theme(json: colors, font), logo_url, is_published, seo(json)
- `site_pages`: id, site_id, type(home/services/staff/contact), content(json), sort
- `telegram_bots`: id, business_id, mode(shared/dedicated), bot_token_enc?, bot_username, webhook_secret, status
- `bot_sessions`: id, bot_id, tg_chat_id, state(json), updated_at

## API endpointlar (namuna)

```
CRUD   /v1/site                              (tema, subdomen, publish)
GET    /v1/site/preview
CRUD   /v1/site/pages
POST   /v1/telegram-bot/connect              (token ulash / validatsiya)
POST   /v1/telegram-bot/disconnect
POST   /v1/webhooks/telegram/{botId}         (per-bot webhook)
GET    /v1/public/{subdomain}/services       (sayt renderer uchun public API)
```

## Frontend

- **apps/admin:** "Onlayn borliq" — tema editor (logo/rang/subdomen), preview, publish; bot ulash sehri (wizard).
- **apps/consumer:** subdomen bo'yicha renderlanuvchi brendlangan sayt (SSR yoki prerender + hydrate). Booking oqimi Faza 1 ni qayta ishlatadi.

## Infra

- **Wildcard DNS** `*.navbat.uz` + Cloudflare; wildcard SSL.
- Subdomen → tenant resolver (middleware): subdomen bo'yicha `business_id` aniqlanadi.
- Telegram per-bot webhook routing: `/{botId}` → tegishli tenant.

## Multi-tenant xavfsizlik

- Har public so'rov faqat o'z tenant ma'lumotini ko'radi.
- `bot_token_enc` shifrlangan saqlanadi (KMS yoki app-level encryption).
- Rate limit per tenant (bot flood himoyasi).

## Qabul mezonlari (DoD)

- [ ] Biznes logo/nom/rang tanlab, subdomenда jonli brendlangan sayt oladi.
- [ ] CRM'ga qo'shilgan xizmat avtomatik saytda va botда ko'rinadi.
- [ ] Bot orqali booking + depozit to'liq ishlaydi.
- [ ] Token ulash non-texnik biznes uchun ham onboarding'da hal bo'ladi.
- [ ] Qo'llab-quvvatlash yuki o'lchanadi (bot/sayt tiketlari).

## Risklar / eslatmalar

- **"Sayt = trafik" DEB SOTMANG** — O'zbekistonda giperlokal SEO past. Pozitsiya: ishonch/landing + booking, asosiy kanal = bot.
- **Multi-tenant yuk** (tema, subdomen, token) qo'llab-quvvatlash tiketlarini oshiradi — narxga qo'shing.
- Token friksiyasi: umumiy bot + deep-link fallback doim bo'lsin.
