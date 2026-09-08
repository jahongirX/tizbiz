# TizBiz SMS (Android)

TizBiz platformasi uchun **o'z brendimizdagi SMS-shlyuz ilovasi**. Telefon SIM-kartasi
orqali SMS yuboradi va TizBiz serverimiz bilan ishlaydi.

- **Server (default):** `https://gate.tizbiz.uz/api/mobile/v1`
- **Package (applicationId):** `uz.tizbiz.gateway`
- **Ilova nomi:** TizBiz SMS
- **Litsenziya:** Apache-2.0 (fork of [capcom6/android-sms-gateway](https://github.com/capcom6/android-sms-gateway) — qarang [NOTICE](NOTICE))

Bu ochiq kodli `android-sms-gateway` ilovasining rebrand qilingan nusxasi: nomi, ikonkasi,
ranglari va default server manzili TizBiz'ga moslashtirilgan. Ichki Kotlin paket nomi
(`me.capcom.smsgateway`) o'zgartirilmagan — bu foydalanuvchiga ko'rinmaydi va yuzlab
fayllarни keraksiz o'zgartirishdan saqlaydi; ilovaning commit qilinadigan identifikatori
`applicationId` = `uz.tizbiz.gateway`.

## Qurish (build) va sozlash

To'liq qo'llanma: **[TIZBIZ-SETUP.md](TIZBIZ-SETUP.md)** — u yerda:
- APK'ni GitHub Actions orqali qurish (lokal Android SDK shart emas),
- kerakli signing/Firebase kalitlari,
- to'liq mustaqil push uchun serverni `public` rejimga o'tkazish,
- ilovani telefonга o'rnatish va ulash bosqichlari.

## Nima o'zgardi (rebrand)

| Narsa | Eski | Yangi |
|---|---|---|
| Ilova nomi | SMSGate | TizBiz SMS |
| applicationId | me.capcom.smsgateway | uz.tizbiz.gateway |
| Default server | api.sms-gate.app/mobile/v1 | gate.tizbiz.uz/api/mobile/v1 |
| Ikonka | kulrang | TizBiz ko'k "TB" (adaptive) |
| Asosiy rang | binafsha | TizBiz ko'k `#2D7EEC` |
