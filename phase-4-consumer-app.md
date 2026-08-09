# Faza 4 — Iste'molchi ilova + Discovery + Premium obuna

## Maqsad

Iste'molchi kanalini bitta ilovaga yig'ish: **YPLACES-uslub retention + discovery/featured lead-gen + premium obuna (Yandex Plus modeli)**. Bu — eng kech dvigatel, faqat ekotizim likvid bo'lgach.

## Kirish sharti

Faza 1–3 ishlab turibdi: yetarlicha biznes + iste'molchi trafigi. Aks holda discovery/obuna sotib bo'lmaydi (imtiyoz beradigan joy yo'q).

## Scope

**IN:**
- Iste'molchi ilovasi (Telegram Mini-App + web PWA): profil, mening yozuvlarim, qayta bron
- **Retention (YPLACES-uslub):** foydalanuvchi ilgari borgan bizneslar kartochkasi + bir tugmа qayta yozilish
- **Discovery/featured:** biznes ko'rinish uchun to'laydi (top-joy); yangi mijoz uchun lead
- **Premium obuna:** platforma sotadi, imtiyoz BARCHA hamkor bizneslarда; platforma obunani ushlaydi
- Cashback/loyallik bir joyda (ko'p-biznesli)

**OUT:** to'liq open discovery marketplace (DIKIDI bilan to'g'ridan raqobat) — ehtiyotkorlik bilan.

## Muhim strategik qoidalar

- **Lead-gen faqat YANGI mijoz uchun** (discovery). Takroriy mijoz uchun "lead" deb pul olma — biznes haqli rad etadi.
- **Premium obuna: chegirma marjadan, narxdan emas; har soha marjasiga moslashtiriladi** (universal −20% xato).
- Chegirma **yangi/qaytgan mijozga** bog'lansin (birinchi tashrif, uzoq kelmagan, referral) — hozirgi sodiqni subsidiya qilmasin.
- Boshida **biznes imtiyozni o'zi ko'taradi, platforma obunani ushlaydi** — teng ketishi uchun ilova "men yangi mijoz olib keldim"ni **isbotlab** bersin (attribution).
- "Arzon qidiruvchi" tuzog'i: obunaga faqat ko'p xarid qiladiganlar yozilmasin — **eksklyuziv qiymat** (maxsus slot, oldindan bron, bepul qo'shimcha) marjani kamroq yeydi.

## Ma'lumotlar bazasi

- `consumer_users`: id, phone, name, tg_chat_id, created_at
- `consumer_favorites`: id, consumer_user_id, business_id
- `visit_history`: id, consumer_user_id, business_id, appointment_id, visited_at   (YPLACES kartochkasi uchun)
- `listings`: id, business_id, category, geo, is_featured, featured_until
- `featured_placements`: id, business_id, plan, price_tiyin, starts_at, ends_at, status
- `leads`: id, business_id, consumer_user_id, source, is_new_customer, fee_tiyin, status  (attribution)
- `premium_subscriptions`: id, consumer_user_id, plan, price_tiyin, status, renews_at
- `partner_benefits`: id, business_id, type(discount/exclusive/gift), value, conditions(json)
- `benefit_redemptions`: id, subscription_id, business_id, benefit_id, amount_tiyin, redeemed_at
- `settlements`: id, business_id, period, incentive_cost_tiyin, platform_share_tiyin, status

## API endpointlar (namuna)

```
GET    /v1/consumer/home                  (YPLACES: borgan joylar + tavsiya)
GET    /v1/consumer/discovery?category=&geo=
POST   /v1/consumer/rebook/{businessId}
CRUD   /v1/featured                        (biznes: top-joy sotib olish)
GET    /v1/leads?business=                 (attribution hisobot)
POST   /v1/premium/subscribe               (Payme/Click, obuna)
POST   /v1/premium/redeem                  (imtiyoz ishlatish)
GET    /v1/settlements?business=           (imtiyoz vs platforma ulushi)
```

## Frontend

- **apps/consumer:** to'liq ilova — home (borgan joylar), discovery/qidiruv, biznes profil, booking, premium obuna, cashback, uy-xizmat (Faza 3 bilan birlashadi).
- **apps/admin:** featured sotib olish, lead attribution hisoboti, imtiyoz sozlash, settlement.

## Monetizatsiya oqimi (premium obuna)

1. Iste'molchi obuna oladi (Payme/Click) → platforma ushlaydi.
2. Imtiyozni hamkor bizneslarda ishlatadi (redemption).
3. Settlement: imtiyoz xarajati (biznes yoki subsidiya) hisob-kitob qilinadi; platforma sof ulushi qoladi.

## Qabul mezonlari (DoD)

- [ ] Foydalanuvchi borgan bizneslarni ko'rib bir tugma bilan qayta yoziladi.
- [ ] Featured sotib olish + lead attribution ishlaydi (yangi mijoz aniqlanadi).
- [ ] Premium obuna sotiladi; imtiyoz redemption + settlement ishlaydi.
- [ ] Platforma sof marjasi (~40%) hisoblanadi va monitoring qilinadi.

## Risklar / eslatmalar

- **Ikki tomonlama likvidlik** — bu fazaning butun sharti. Yetarli biznes + foydalanuvchi bo'lmasa yoqma.
- Premium obuna past chastotali sohaga (tort/kelin ko'ylak) EMAS; yuqori chastotali (kafe/fitnes) + ko'p-biznesli qiymatga mos.
- Attribution to'g'ri bo'lmasa — biznes "chegirma zarar" deб chiqadi. Butun model attribution isbotiga tayanadi.
