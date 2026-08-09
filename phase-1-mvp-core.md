# Faza 1 — MVP yadro (Booking + Prepayment + CRM/Loyallik)

## Maqsad

Bitta wedge'da (xususiy tibbiyot + issiq loyallik mijozlari) ishlaydigan yadro loop: **biznes o'z mijozini yozadi → eslatma → oldindan to'lov → mijoz bazasi + cashback**. 20–50 biznesda isbotlash.

## Kirish sharti

Yo'q (birinchi faza). Yii2 advanced + Vue admin skeleton + auth.

## Scope

**IN:**
- Biznes ro'yxatdan o'tishi (tenant), xizmat/mutaxassis/ish vaqti sozlash
- Onlayn-yozuv (booking) — mutaxassis + slot
- Oldindan to'lov (Payme/Click) — ixtiyoriy, biznes yoqadi
- Eslatma (Telegram + SMS)
- Mijoz bazasi (CRM): ism, telefon, tug'ilgan kun, tarix, teglar
- Loyallik: cashback/ballar, sovg'a/aksiya, referral
- Biznes admin paneli (Vue) + iste'molchi yozuv sahifasi (oddiy, brendsiz)

**OUT (keyingi fazalarga):**
- Brendlangan sayt+bot generator (Faza 1.5)
- AI-seller, restoran, uy-xizmat, iste'molchi app

## Funksiyalar (user stories)

- Biznes egasi tenant yaratadi, tarif tanlaydi (Bepul/Start/Standart/Klinika).
- Admin xizmatlar, mutaxassislar, ish vaqti (working hours), dam olish kunlarini kiritadi.
- Mijoz yozuv sahifasidan xizmat+mutaxassis+slot tanlab yoziladi; kerak bo'lsa depozit to'laydi.
- Tizim yozuvdan oldin Telegram/SMS eslatma yuboradi.
- Admin yozuvlar jurnalini (kun/hafta) ko'radi, holatni o'zgartiradi (kutilmoqda/kelди/no-show/bekor).
- Mijoz bazasi avtomatik to'ldiriladi; cashback ballari xariddan yig'iladi.
- Referral: mijoz do'stini olib kelsa — ikkalasiga bonus.

## Ma'lumotlar bazasi (asosiy jadvallar)

- `businesses` (tenant): id, name, slug, phone, category, tariff, timezone, status
- `users`: id, phone, name, password_hash, status
- `business_user`: user_id, business_id, role
- `staff`: id, business_id, user_id?, name, specialization, is_active
- `service_categories`: id, business_id, name, sort
- `services`: id, business_id, category_id, name, duration_min, price_tiyin, deposit_tiyin?, is_active
- `working_hours`: id, staff_id, weekday, start, end
- `time_off`: id, staff_id, date, start?, end?, reason
- `clients`: id, business_id, name, phone, birthday?, notes, tags(json), created_at
- `appointments`: id, business_id, client_id, staff_id, service_id, starts_at, ends_at, status, source, deposit_tiyin, paid, created_at
- `transactions`: id, business_id, appointment_id?, provider(payme/click), amount_tiyin, type(deposit/refund), status, external_id, idempotency_key
- `loyalty_accounts`: id, business_id, client_id, points, cashback_tiyin
- `loyalty_rules`: id, business_id, earn_rate, gift_config(json), active
- `loyalty_transactions`: id, account_id, delta_points, delta_cashback_tiyin, reason, ref
- `referrals`: id, business_id, referrer_client_id, referred_client_id, bonus_status
- `notifications`: id, business_id, client_id?, channel(tg/sms), template, payload(json), status, sent_at
- `telegram_links`: id, client_id?, user_id?, tg_chat_id, verified_at

## API endpointlar (namuna)

```
POST   /v1/auth/login                       (JWT)
POST   /v1/businesses                        (tenant yaratish)
GET    /v1/businesses/{id}
CRUD   /v1/staff  /v1/services  /v1/service-categories
GET    /v1/staff/{id}/availability?date=     (bo'sh slotlar)
POST   /v1/appointments                      (idempotency-key)
PATCH  /v1/appointments/{id}                 (status)
GET    /v1/appointments?from=&to=&staff=
CRUD   /v1/clients                           (mijoz bazasi)
POST   /v1/payments/deposit                  (Payme/Click init)
POST   /v1/webhooks/payme  /v1/webhooks/click
GET    /v1/loyalty/{clientId}                (ballar/cashback)
POST   /v1/loyalty/redeem
POST   /v1/referrals
```

## Frontend (Vue)

- **apps/admin:** login, dashboard (bugungi yozuvlar), jadval (kalendar ko'rinishi), xizmat/mutaxassis/ish vaqti sozlamalari, mijozlar bazasi, loyallik sozlamalari, tarif.
- **apps/consumer (minimal):** biznes yozuv sahifasi (havola orqali) — xizmat/mutaxassis/slot → depozit → tasdiq. Telegram Mini-App wrapper.

## Integratsiyalar

- **Payme + Click:** deposit init + webhook (idempotent), refund.
- **Telegram Bot API:** eslatma + yozuv tasdig'i (platforma umumiy boti; per-biznes bot Faza 1.5 da).
- **SMS gateway:** eslatma (biznes tanlagan bo'lsa).
- **Centrifugo:** admin jadvalida real-time yozuv yangilanishi.

## Qabul mezonlari (Definition of Done)

- [ ] Biznes 10 daqiqada sozlanadi (xizmat+mutaxassis+ish vaqti) va yozuv qabul qiladi.
- [ ] Mijoz havoladan yozila oladi; depozit Payme va Click orqali o'tadi (test + prod).
- [ ] Eslatma Telegram va SMS orqali yetadi; no-show holati kuzatiladi.
- [ ] Mijoz bazasi va cashback avtomatik to'ladi; referral ishlaydi.
- [ ] Metrikalar: haftalik yozuv/biznes, no-show %, sinov→pullik konversiya o'lchanadi.

## Risklar / eslatmalar

- **Naqd madaniyati:** prepayment MAJBURIY emas — biznes yoqadi.
- **Leakage:** mijoz tarixi + eslatma + loyallik lock-in vazifasini bajaradi.
- Ortiqcha funksiya qo'shmang: ombor, ko'p filial, analitika chuqurligi — keyin.
