# TizBiz SMS — qurish va sozlash qo'llanmasi

Bu ilova ochiq kodli `android-sms-gateway` (capcom6, Apache-2.0) ilovasining TizBiz
brendiga moslashtirilган nusxasi. Nomi, ikonkasi, ranglari va **default server manzili**
(`https://gate.tizbiz.uz/api/mobile/v1`) o'zgartirilган.

> **Muhim:** dev-mashinada Android SDK / JDK yo'q, shuning uchun APK **GitHub Actions**'da
> quriladi (lokal build shart emas). Signing kaliti allaqachon yaratilган va
> `contabo-access.md` faylда saqlanган.

---

## 1. APK olish — 3 qadam

### Qadam 1 — GitHub secrets qo'yish (bir marta)
Repo → **Settings → Secrets and variables → Actions → New repository secret**. Qiymatlar
`contabo-access.md`даги "TizBiz SMS (Android app)" bo'limида:

| Secret nomi | Qiymat |
|---|---|
| `SIGNING_KEY_STORE_BASE64` | keystore.jks base64 (contabo-access.md'да) |
| `SIGNING_STORE_PASSWORD` | keystore paroli |
| `SIGNING_KEY_ALIAS` | `tizbiz` |
| `SIGNING_KEY_PASSWORD` | keystore paroli (bir xil) |
| `GOOGLE_SERVICES_JSON` | **ixtiyoriy** — faqat real Firebase (Path B) uchun |

### Qadam 2 — build'ни ishga tushirish
GitHub → **Actions → "Build TizBiz SMS APK" → Run workflow** → versiya (masalan `1.0.0`) →
**Run**. ~3–5 daqiqa. (Workflow: `.github/workflows/build-sms-apk.yml`.)

### Qadam 3 — APK'ni yuklab olish
Tugagach, run sahifasида pastда **Artifacts → `tizbiz-sms-release-apk`** → yuklab oling →
`.zip` ichидан `app-release.apk`ни telefonга o'rnating (Play Store'siz, "unknown sources").

---

## 2. Push arxitekturasi — Path A yoki Path B?

Ilova serverdан "yangi xabar bor" signalini qanday oladi degan savol. Ikki yo'l bor:

### Path A — Firebase'siz (tez, tavsiya: sinov uchun)
- `GOOGLE_SERVICES_JSON` secret **qo'yilmaydi** → build placeholder ishlatadi.
- APK quriладi, o'rnатилади, ishlaydi. Lekin **FCM push o'chiq** — ilova xabarларни
  **SSE** orqали oladi (telefon serverга doimiy ulanिб turadi; batareyaга ozroq ta'sir).
- Server tomonида **hech narsa o'zgармайди** (hozirги `gate.tizbiz.uz` shundoq ishlayveradi).
- Kamchiligi: telefon SSE ulanишни ushlab turishи kerak (Home'да "Cloud server" yoqilган).

### Path B — o'z Firebase'imiz bilan (to'liq mustaqil, ishlab chiqarish uchun)
- O'z Firebase loyihamiz → FCM push to'g'ridан-to'g'ri bizning serverdan boradi.
- `api.sms-gate.app`га umuman bog'liqlik qolmaydi.
- **Server `public` rejimга o'tkаziladi** (pastда 3-bo'lim). Bu yerда bitta muhim jihat bor:

> ⚠️ **OGOHLANTIRISH:** server `public` rejimга o'tса, hozир Redmi telefonда ishlаётган
> **rasmiy SMSGate ilovaси push olмай qoladi** (u capcom6'ning Firebase'ига bog'langan).
> Redmiга **yangi TizBiz SMS APK**'ни o'rnатиб, qайта ro'yxatдан o'tkаzиш kerak bo'ladi.
> Shuning uchun Path B'ни tayyor bo'lganда, bilиб qiling.

---

## 3. Path B — Firebase + serverни `public` rejimга o'tkаzиш

### 3.1 Firebase loyиха (Google Console — foydаlanuvchi qiladi)
1. https://console.firebase.google.com → **Add project** (masalan `tizbiz-sms`).
2. **Add app → Android**: package name = **`uz.tizbiz.gateway`** (aynan shu!).
3. **`google-services.json`**'ни yuklab oling. Uni base64 qiling va
   `GOOGLE_SERVICES_JSON` secret'ga qo'ying:
   ```bash
   base64 -i google-services.json | tr -d '\n'
   ```
   (Yoki faylни `mobile/tizbiz-sms/app/google-services.json` deb qo'ying — u `.gitignore`'да.)
4. **Project Settings → Service accounts → Generate new private key** → JSON yuklanadi.
   Bu **server** uchun (FCM'ни o'zi yuboради).

### 3.2 Serverни `public` rejimга o'tkаzиш (gate.tizbiz.uz)
Faylда: `/opt/sms-gateway/app.env` (yoki config.yml). O'zgаришlар:
```env
GATEWAY__MODE=public
FCM__CREDENTIALS_JSON={... 3.1.4 dagi service-account JSON to'liq ...}
# GATEWAY__UPSTREAM_URL endi kerak emas (public rejimда ishlatilmaydi)
```
So'ng: `systemctl restart sms-gateway`.

- `public` rejимда qurilma **anonim** ro'yxatдан o'tади (private token shart emas).
- Ro'yxatдан o'tиш endpoint'и ochiq bo'lади — istаса reverse-proxy'да
  `/api/mobile/v1/device` ни IP/rate-limit bilan himoyаlаng (har qurilma faqat **o'z**
  SIM'ида yuboради, shuning uchun xавf past).

> Bu qadamни men (Claude) bajara olaman — lekin **Firebase service-account JSON**'ни
> siz bergач va yuqoriдаги ⚠️ni tasdiqlaгач. Ayting — serverni o'zim o'tkаzиб beraman.

---

## 4. Telefonда o'rnатиш va ulash

1. `app-release.apk`ни o'rnating → "TizBiz SMS" ochiladi.
2. SMS/telefon ruxsatларини bering.
3. **Home** → "Cloud server"ни yoqing → **Start**.
4. Ochilган oynада:
   - **Path B (public):** "Sign Up" (Register) → qurilma anonim ro'yxatдан o'tади.
   - **Path A / private token:** "Sign Up" tab, oldin Settings → Cloud server'да
     **Private Token**'ни kiritиб qo'ying.
5. Muvaffaqиятли bo'lса, Home'даги **Cloud Server** kartаsида: server (`gate.tizbiz.uz`),
   **login / parol / device ID** chiqади — bu 3rd-party API (TizBiz backend SMS yuboradi)
   uchun ishlаtилади. superadmin panelда shu qurilma orqали test SMS yuborиб ko'ring.

---

## 5. Nimalar o'zgартирилган (rebrand)

- **Identity:** `app_name` = "TizBiz SMS"; `applicationId` = `uz.tizbiz.gateway`
  (ichки Kotlin namespace `me.capcom.smsgateway` — o'zgармаган, ko'rinmaydi).
- **Default server:** `GatewaySettings.PUBLIC_URL` → `https://gate.tizbiz.uz/api/mobile/v1`.
- **Ikonka:** TizBiz ko'k "TB" (adaptive + legacy, barcha dpi) — `res/mipmap-*`.
- **Ranglar:** `colorPrimary` → TizBiz ko'k `#2D7EEC` (`values/colors.xml`, `themes.xml`).
- **Matnlar:** "SMSGate" → "TizBiz SMS", privacy URL → `tizbiz.uz/privacy` (barcha til fayllar).
- **Litsenziya:** LICENSE (Apache-2.0) + NOTICE (capcom6 atributsияси) saqlangan.

### Ixtiyoriy: "faqat token" oqими uchun
`GatewaySettings.enabled` default'ини `true` qilса, ilova birinchи ochилганда Cloud server
avtomат yoqиq bo'lади (`?: false` → `?: true`). Hozir upstream default (`false`) qoldirилган.
