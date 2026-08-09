# Faza 3 — Uy-xizmat komissiya marketplace

## Maqsad

Ikkinchi daromad dvigateli: **uyga mutaxassis chaqirish** (hamshira/ukol, massajist, santexnik, elektrik, boshqalar) — **komissiya (15–25%)** asosida. Bu yerda komissiya ishlaydi, chunki har chaqiruv yangi moslashtirish + ishonch qiymati bor.

## Kirish sharti

Yadro + sayt/bot + iste'molchi kanali (bot/app) mavjud, likvidlik shakllana boshlagan (Faza 1–2 tugagan).

## Scope

**IN:**
- Provider (mutaxassis) profili + **vetting** (tekshirilgan, "verified" nishon)
- Xizmat turlari + narx oralig'i + hudud/borish
- Buyurtma (job) oqimi: so'rov → moslashtirish → tasdiq → bajarish → to'lov
- **Escrow**: ish tugaguncha to'lovni ushlab turish, keyin providerga payout (komissiya ushlab qolinadi)
- Ikki tomonlama reyting; kafolat/qayta chaqirish

**OUT:** o'z provider parkini "ishga olish" (marketplace, ishchi emas); murakkab logistika.

## Funksiyalar

- Provider ariza beradi → hujjat/tekshiruv → tasdiq → profil faol.
- Iste'molchi xizmat + vaqt + manzil tanlaydi → mos providerlar → tanlaydi/tasdiqlaydi → **escrow to'lov**.
- Provider ishni "bajarildi" belgilaydi → iste'molchi tasdiqlaydi → payout (komissiya ushlanadi).
- Nizo (dispute) oqimi: tasdiqlanmasa — qo'lda ko'rib chiqish.
- Reyting ikki tomonlama; past reyting provider ko'rinishini kamaytiradi.

## Ma'lumotlar bazasi

- `providers`: id, user_id, display_name, bio, status(pending/verified/suspended), rating_avg, jobs_done
- `provider_documents`: id, provider_id, type, file_url, verified_at
- `provider_services`: id, provider_id, category, title, price_min_tiyin, price_max_tiyin, areas(json)
- `provider_availability`: id, provider_id, weekday, start, end
- `service_requests`: id, consumer_user_id, category, address(json), scheduled_at, status, matched_provider_id?
- `jobs`: id, request_id, provider_id, price_tiyin, commission_tiyin, status(created/accepted/done/confirmed/disputed), completed_at
- `escrow_holds`: id, job_id, amount_tiyin, status(held/released/refunded), provider(payme/click), external_id
- `payouts`: id, provider_id, amount_tiyin, status, ref
- `ratings`: id, job_id, from(consumer/provider), stars, comment

## API endpointlar (namuna)

```
POST   /v1/providers/apply
CRUD   /v1/providers/{id}/services
POST   /v1/providers/{id}/verify         (superadmin)
POST   /v1/service-requests              (iste'molchi)
GET    /v1/service-requests/{id}/matches (mos providerlar)
POST   /v1/jobs                          (tasdiq → escrow hold)
PATCH  /v1/jobs/{id}                     (accepted/done/confirmed)
POST   /v1/jobs/{id}/release             (payout, komissiya ushlanadi)
POST   /v1/jobs/{id}/dispute
POST   /v1/ratings
```

## Frontend

- **apps/consumer:** uy-xizmat bo'limi — xizmat tanlash, manzil, provider ko'rish (reyting/verified), escrow to'lov, ish holati, reyting.
- **apps/admin yoki alohida provider app:** provider paneli — buyurtmalar, kalendar, payout tarixi.
- **apps/superadmin:** vetting navbati, dispute markazi, komissiya hisoboti.

## Ishonch va xavfsizlik (KRITIK)

- Ishonch #1 to'siq — begonani uyga kiritish. **Vetting + verified nishon + reyting + kafolat** majburiy.
- Escrow: pul ish tugaguncha ushlanadi → firibgarlik/sifatsizlikni kamaytiradi.
- Ayol iste'molchi/hamshira uchun xavfsizlik e'tibori (ayol provider filtri, h.k.).

## Qabul mezonlari (DoD)

- [ ] Provider vetting oqimi ishlaydi; faqat verified providerlar ko'rinadi.
- [ ] So'rov → moslashtirish → escrow to'lov → bajarish → payout to'liq ishlaydi.
- [ ] Komissiya escrow'dan avtomatik ushlanadi.
- [ ] Dispute va reyting ishlaydi.

## Risklar / eslatmalar

- **Supply eng qiyin qismi** — tekshirilgan provider yig'ish sekin. Bir vertikaldan boshla (masalan uyga hamshira/ukol yoki massaj).
- Bu alohida likvidlik muammosi — yadro bizneslardan trafik olib kelib start ber.
