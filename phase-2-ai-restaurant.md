# Faza 2 — AI-seller + Restoran zakaz

## Maqsad

Ikki premium dvigatel: (1) **AI-seller** — biznes ma'lumotidan 24/7 javob beruvchi savdo-yordamchi; (2) **Restoran zakaz** — dine-in/olib ketish (dostavkasiz, asset-light).

## Kirish sharti

Faza 1 + 1.5 ishlab turibdi (booking + sayt/bot 50+ bizneste).

---

## A qism — AI-seller (premium add-on)

### Nima yechadi

Mijoz botga soat 22:00 da "balayaj qancha?" yozadi — admin ertalab ko'radi, mijoz allaqachon boshqa joyga yozilgan. AI-seller 5 soniyada, o'zbek/rus tilida javob beradi, upsell qiladi, **booking + to'lovга** olib boradi.

### Qat'iy shartlar

- **Faqat o'sha biznesning REAL ma'lumotidan** javob bersin (CRM xizmat/narx + jonli bo'sh vaqt ustida RAG). Umumiy chatbot EMAS.
- Band slotni va'da qilmasin, noto'g'ri narx aytmasin — bu real biznes zarari.
- **"Odam bilan gaplashish" fallback** doim bo'lsin.
- Token narxini nazorat: arzon model + routing, kerak bo'lganda eskalatsiya; o'zbek tilini qaysi model yaxshi tutishini test qil.

### Ma'lumotlar bazasi

- `ai_configs`: id, business_id, enabled, persona(json), languages, escalation_phone, model_tier
- `ai_knowledge`: id, business_id, source(services/faq/custom), content, embedding_ref
- `ai_conversations`: id, business_id, tg_chat_id, client_id?, status
- `ai_messages`: id, conversation_id, role(user/assistant/tool), content, tokens, created_at

### API / oqim

```
CRUD   /v1/ai/config
POST   /v1/ai/knowledge/reindex
POST   /v1/ai/message            (bot webhook → AI → RAG → javob/booking)
POST   /v1/ai/escalate
```

Oqim: bot xabari → intent → RAG (biznes xizmat/narx + `availability`) → javob YOKI `POST /v1/appointments` → depozit.

### DoD

- [ ] AI faqat biznesning real narx/xizmat/bo'sh vaqtidan javob beradi.
- [ ] AI to'g'ridan booking + depozitga olib boradi.
- [ ] Eskalatsiya (odam) ishlaydi; token xarajati monitoring qilinadi.
- [ ] Premium tarif/add-on sifatida yoqiladi (feature-flag `ai_seller`).

---

## B qism — Restoran zakaz (dostavkasiz)

### Model

**Faqat zakaz avtomatlashtirish:** stolда QR → botда/saytда menu → zakaz → oshxonaga tushadi. **Yetkazish restoranning o'zida** (o'z kuryeri/olib ketish/stol). Uzum Tezkor bilan raqobatlashmaymiz. Monetizatsiya: kichik komissiya (~3–8%) yoki menu-SaaS.

### Ma'lumotlar bazasi

- `menus`: id, business_id, name, active
- `menu_categories`: id, menu_id, name, sort
- `menu_items`: id, menu_id, category_id, name, price_tiyin, description, photo_url, is_available
- `tables`: id, business_id, label, qr_token
- `orders`: id, business_id, table_id?, type(dinein/pickup), status, total_tiyin, commission_tiyin, source, created_at
- `order_items`: id, order_id, menu_item_id, qty, price_tiyin, note

### API / oqim

```
CRUD   /v1/menus  /v1/menu-items  /v1/tables
GET    /v1/public/{subdomain}/menu
POST   /v1/orders                 (QR/bot dan)
PATCH  /v1/orders/{id}            (status: qabul/tayyor/berildi)
GET    /v1/orders?status=         (oshxona ekran)
```

- Realtime (Centrifugo): yangi zakaz → oshxona ekraniga darhol.
- To'lov: joyida naqd YOKI Payme/Click (float shu yerdan).

### DoD

- [ ] QR skan → menu → zakaz → oshxona ekranida real-time paydo bo'ladi.
- [ ] Komissiya yoki menu-SaaS billing ishlaydi.
- [ ] Dostavka LOGIKASI YO'Q — faqat zakaz oqimi (ataylab).

## Umumiy risklar / eslatmalar

- AI: noto'g'ri javob = real zarar. Grounding va guardrail birinchi o'rinda.
- Restoran: dostavkani hech qachon o'z ustingga olma; komissiya shift pastroq (asset-light — bu yaxshi).
