# SMS va mijozga xabar — qanday ishlaydi

> Bu hujjat SMS bo'yicha yagona ma'lumotnoma: zanjir qanday ketadi, admin
> paneldan nima boshqariladi, ishga tushirish uchun nima kerak va nosozlikni
> qanday topish. Kalitlar bu yerda **yozilmaydi** — faqat env'da turadi.

## 1. Zanjir — xabar qayerdan qayerga boradi

```
Bron yaratildi / cron ishga tushdi
        ↓
Kanal tanlanadi:  mijozda tasdiqlangan Telegram bormi?
        ├─ ha  → Telegram (bepul)
        └─ yo'q → SMS
        ↓
notifications jadvaliga qator (status: queued)
        ↓
SmsSender → POST https://api.tizbiz.uz/v1/sms/api/send
            X-Api-Key: tzb_…
            {"to": "+998901234567", "text": "…"}
        ↓
sms.tizbiz.uz → ulangan Android telefon (Serverlar bo'limi, sms-gate.app)
        ↓
Telefon o'z SIM kartasidan SMS yuboradi
        ↓
notifications qatori: sent / failed + sent_at
```

Muhim: `sms.tizbiz.uz` operator emas — u xabarni **ulangan telefonga** beradi,
telefon esa oddiy SMS yuboradi. Shuning uchun operator tarifi bo'yicha ketadi.

## 2. Ikki xil xabar

| Turi | Qachon | Shablon matni |
|---|---|---|
| **Tasdiq** (`confirmation`) | Bron yaratilgan zahoti | `Navbatingiz tasdiqlandi: 24.08.2026 09:30 — Jalolbek.` |
| **Eslatma** (`reminder`) | Tashrifdan N soat oldin (cron) | `Eslatma: sizda 24.08.2026 09:30 da navbat bor (Klassik soch olish) — Jalolbek.` |

Matnlar: `api/modules/notify/services/NotificationService.php`.

## 3. Admin paneldan boshqarish

**Sozlamalar → Onlayn-yozuv → "Mijozga xabar"**

- **Yozilganda tasdiq** — yoqish/o'chirish
- **Tashrifdan oldin eslatma** — yoqish/o'chirish
- **Necha soat oldin** — 1..168 (standart 24)

Har biznes uchun alohida saqlanadi (`businesses.notify_confirmation`,
`notify_reminder`, `reminder_hours`).

**Sozlamalar → Xabarlar** — yuborilgan xabarlar jurnali: vaqt, mijoz, turi,
kanal, holat, yuborilgan vaqt. Kanal va holat bo'yicha filtr.
API: `GET /v1/notifications`.

## 4. Ishga tushirish

### Env (server tomonda)

```bash
export SMS_PROVIDER=tizbiz        # tizbiz | eskiz (standart: eskiz)
export SMS_TOKEN='tzb_…'          # kalit: sms.tizbiz.uz → API bo'limi
# SMS_ENDPOINT berilmasa: https://api.tizbiz.uz/v1/sms/api/send
```

`SMS_TOKEN` **API serverning** muhitida bo'lishi kerak (tasdiq xabari o'sha
yerdan ketadi) va **cron** muhitida ham (eslatma uchun).

### Cron

```
*/15 * * * *  php /path/yii reminder/send
*/5  * * * *  php /path/yii appointment/auto-complete
```

`reminder/send` har bir bronni bir marta eslatadi (takrorlanmaydi) va biznesning
o'z `reminder_hours` sozlamasini hisobga oladi.

### Tekshirish

```bash
php yii sms/status                      # provayder, endpoint, balans — SMS yubormaydi
php yii sms/send +9989XXXXXXXX "matn"   # haqiqiy SMS, avval tasdiq so'raydi
```

`sms/status` kalitni to'liq chiqarmaydi (`tzb_****…2c32`).

## 5. Nosozlikni topish

| Belgi | Sabab | Yechim |
|---|---|---|
| Jurnalda `failed` | `SMS_TOKEN` server muhitida yo'q | Env'ni qo'yib, API serverni qayta ishga tushiring |
| Jurnalda umuman qator yo'q | Sozlamada o'chirilgan, yoki mijozda telefon yo'q (walk-in) | Sozlamalar → Mijozga xabar; walk-in'da telefon ixtiyoriy |
| `sms/status` HTTP 401 | Kalit noto'g'ri yoki bekor qilingan | sms.tizbiz.uz → API → "Yangi kalit" |
| Balans `unlimited: false` va `remaining: 0` | Oylik limit tugagan | Limitni oshiring yoki keyingi oyni kuting |
| Xabar ketdi, lekin kelmadi | Ulangan telefon oflayn / SIM'da balans yo'q | sms.tizbiz.uz → Serverlar bo'limi |

Log: `api/runtime/logs/app.log`, `notify` kategoriyasi.

## 6. Kod qayerda

| Nima | Fayl |
|---|---|
| Shlyuzga so'rov | `api/modules/notify/services/SmsSender.php` |
| Navbat + dispatch + matnlar | `api/modules/notify/services/NotificationService.php` |
| Tasdiq xabari | `api/modules/booking/controllers/AppointmentController.php` (`sendConfirmation`) |
| Eslatma (cron) | `console/controllers/ReminderController.php` |
| Konsol tekshiruv | `console/controllers/SmsController.php` |
| Jurnal API | `api/modules/notify/controllers/NotificationController.php` |
| Admin sahifa | `apps/admin/src/views/Messages.vue` |
| Admin sozlama | `apps/admin/src/views/BookingSettings.vue` |

## 7. Xavfsizlik

- Kalit repoda **yo'q** va bo'lmasligi kerak — faqat env.
- `sms/status` kalitni maskalab chiqaradi.
- Kalit chatga/skrinshotga tushib qolsa — sms.tizbiz.uz → API → **Yangi kalit**,
  keyin env'ni yangilang.
