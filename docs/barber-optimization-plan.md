# Barber / Salon vertikali — optimizatsiya tahlili

> Holat: 2026-08-17. Zona: `barber` / `salon` → `slot` engine ([CLAUDE.md §9](../CLAUDE.md)).
> Maqsad: kabinetni sartaroshxona/salon ish jarayoniga moslash — ortiqchasini olib
> tashlash, yetishmayotganini qo'shish, oqimni qisqartirish.
> Bajarilgan ishlar: [changelog-barber.md](changelog-barber.md).

## 0. Qisqacha xulosa

Bugungi holat: platforma **universal booking yadrosi** sifatida yaxshi qurilgan, lekin
kabinet hamma vertikal uchun bir xil ko'rinadi. Sartaroshxona uchun uchta muammo bor:

1. **Ortiqcha yuk** — 20+ sahifa, 6 nav guruhi. Bir usta ishlaydigan barberga bu ko'p.
2. **Yo'q bo'lgan asosiy stsenariylar** — jonli navbat (walk-in), bir yozuvda bir necha
   xizmat, tushlik tanaffusi. Bular barberning kunlik ishi, lekin tizimda yo'q.
3. **Booking oqimi uzun** — 5 qadam. Sartaroshxonaga 2-3 qadam yetadi.

Quyida ustuvorlik bo'yicha (ta'sir / mehnat) tartiblangan.

---

## 1. Ortiqcha — barberda yashirish kerak

| Bo'lim | Nega ortiqcha | Taklif |
|---|---|---|
| **Ombor** | Sartaroshxona qoldiq hisoblamaydi | ✅ Bajarildi — `slot` da yashirildi |
| **Sertifikatlar** | Barberda sovg'a sertifikati kam ishlatiladi; salonda esa mashhur | Sub-kategoriyaga bog'lash: `barber` da yashirish, `salon` da qoldirish |
| **Mijoz kategoriyalari** (+ avto-qoidalar) | CRM segmentatsiya — 200+ mijozdan keyin ma'noli | "Qo'shimcha" ostiga olish yoki mijozlar soni 100 dan oshganda ko'rsatish |
| **Hisobotlar: 4 ta sahifa** (Boshqaruv / Analitika / Moliya / Ish haqi) | Kichik biznesda bir-birini takrorlaydi | Bittaga birlashtirish: bitta "Hisobot" sahifasi, ichida tab. Ish haqi alohida qoladi |
| **Buyurtmalar (`/orders`)** | Catalog engine uchun | ✅ Allaqachon `slot` da `/appointments` ga yo'naltirilgan |

Natija: nav 6 guruh × 20 sahifadan → **~10 sahifa**ga tushadi.

---

## 2. Yetishmayapti — qo'shish kerak (ta'sir bo'yicha)

### 2.1 Jonli navbat / walk-in ⭐ eng muhim

Sartaroshxonada mijozlarning katta qismi **oldindan yozilmasdan** keladi. Hozir ularni
tizimga kiritish uchun to'liq "yangi yozuv" formasini to'ldirish kerak.

**Taklif.** Jadval ekranida bitta tugma: **"Hozir keldi"** → usta + xizmat tanlanadi,
vaqt = hozir, status `in_progress`. Telefon ixtiyoriy (keyin loyallik uchun so'raladi).
Bu bo'lmasa barber tizimni kunlik ishida umuman ishlatmaydi — eng katta yo'qotish shu.

### 2.2 Bir yozuvda bir necha xizmat ⭐

Real buyurtma: *soch olish + soqol + qosh*. Hozir `appointments.service_id` — bitta
xizmat, ya'ni ustaning 20 daqiqalik qo'shimcha ishi jadvalda ko'rinmaydi va slot
noto'g'ri hisoblanadi.

**Taklif.** `appointment_items` jadvali allaqachon bor (catalog uchun ishlatiladi) —
`slot` engine uchun ham qo'llash: davomiylik = xizmatlar yig'indisi, narx = yig'indi.
Backend o'zgarishi kerak, orqaga mos qilinadi (bitta xizmat — hozirgi yo'l).

### 2.3 Tushlik tanaffusi / kun ichida bo'shliq ⭐

`working_hours` jadvali bir kunga **bir nechta oraliq**ni qo'llab-quvvatlaydi
(`staff_id + weekday + start + end`), lekin admin UI kuniga faqat **bitta** oraliq
beradi. Ya'ni 13:00–14:00 tushlikni belgilashning iloji yo'q — usta o'sha vaqtga
yozilib qoladi.

**Taklif.** Ish jadvali sahifasida kunga "+ oraliq qo'shish". Backend tayyor, faqat UI.

### 2.4 Booking oqimini qisqartirish (5 qadam → 3)

Hozir: `xizmat → usta → vaqt → ma'lumot → tasdiqlash`.

- **Bitta usta bo'lsa** — "usta" qadami avtomatik o'tkazib yuborilsin.
- **"Farqi yo'q"** varianti — mijoz ustani tanlashni istamasa, tizim bo'sh ustani
  o'zi beradi (barberda juda keng tarqalgan).
- **Qaytgan mijoz** — telefon `localStorage` da saqlansin, "ma'lumot" qadami
  o'tkazilsin (faqat tasdiqlash).
- **"Ma'lumot" + "Tasdiqlash"** bitta ekranga birlashtirilsin.

Natija: aksariyat mijoz uchun **2 qadam** (xizmat → vaqt), yangi mijozga 3.

### 2.5 Takroriy yozuv (rebooking)

Barber mijozi o'rtacha 3-4 haftada qaytadi. Yozuvni yopgandan keyin darhol
**"Keyingi safarga yozish"** taklifi (masalan +3 hafta, o'sha usta, o'sha vaqt) —
bir bosishda. Bu takroriy tashrifni oshiruvchi eng arzon mexanizm.

### 2.6 Mijoz kartasi — sartarosh/salon uchun maxsus maydonlar

Hozir `clients.notes` — strukturasiz matn. Barber/salon uchun eng qimmatli ma'lumot:

- **Barber:** mashinka raqami (#1/#2/#3), soch modeli, qaysi usta bilan ishlaydi.
- **Salon:** bo'yoq formulasi (masalan `7.1 + 9%`), allergiya, oxirgi bo'yash sanasi.

Bu maydonlar aynan shu vertikalga tegishli → `clients` ga JSON `profile` maydoni va
sub-kategoriyaga qarab forma. Salon uchun bo'yoq formulasi — YClients'da ham
salonlarni ushlab turuvchi asosiy narsa.

### 2.7 No-show hisobi

Depozit mexanizmi bor, lekin usta mijoz kartasida "3 marta kelmagan" degan ogohlantirish
ko'rmaydi. `appointments.status` da ma'lumot bor — faqat ko'rsatish kerak: mijoz
kartasida va yozuv yaratishda kichik belgi.

### 2.8 Eslatma + tasdiqlash (Telegram)

`notify` moduli bor. Barber uchun foydali qo'shimcha: eslatmada **"Tasdiqlayman / Bekor
qilaman"** tugmalari — no-show'ni depozitsiz ham kamaytiradi.

### 2.9 Usta foizi — xizmat darajasida

Hozir `staff.commission_percent` — ustaga bitta foiz. Amalda: soch olish 50%, bo'yash
30%, mahsulot sotuvi 10%. Xizmat bo'yicha foiz kerak (ustadagi qiymat — standart).

---

## 3. Soddalashtirish (mavjud narsani yaxshilash)

| Nima | Muammo | Taklif |
|---|---|---|
| **Xizmatlar ro'yxati** | Barberda 5-15 ta xizmat, lekin kategoriya + rasm + galereya to'liq forma | Barber uchun soddalashtirilgan forma: nomi, davomiyligi, narxi. Qolgani "Batafsil" ostida |
| **Ish jadvali** | Har ustaga alohida to'ldiriladi | "Boshqa ustaga nusxalash" tugmasi |
| **Xodim qo'shish** | 403 xatosi rol tekshiruvisiz ko'rinadi | Rolga qarab tugmani yashirish (changelog'da "tuzatilmagan" ro'yxatida) |
| **Xato matnlari** | API inglizcha (`Insufficient role...`) | O'zbekchaga o'tkazish |
| **Statistika** | 4 ta sahifada tarqoq | Barberga kerakli 4 ko'rsatkich: kunlik tushum, band slot %, no-show %, takroriy mijoz % |

---

## 4. Texnik qarz / xavflar

1. **API shartnomalari tekshirilmaydi.** `days`/`items` bug'i aynan shundan chiqdi:
   frontend boshqa format yuborsa ham backend 200 qaytaraveradi. Taklif:
   `packages/api-client` da har endpoint uchun nomlangan funksiya (`updateWorkingHours(staffId, days)`),
   toza payload bir joyda qursin. Bu shunday bug'lar sinfini butunlay yopadi.
2. **"Bo'sh ro'yxat = hammasini o'chir" xavfi.** `PUT working-hours` bo'sh `items` bilan
   jadvalni o'chiradi va 200 qaytaradi. Ehtiyot chorasi: bo'sh ro'yxatda tasdiq
   (`?confirm=1`) yoki 422.
3. **Vaqt zonasi qattiq yozilgan.** `apps/admin/src/lib/datetime.js` da
   `TZ_OFFSET_HOURS = 5`. Hozir to'g'ri (O'zbekiston DST ishlatmaydi), lekin biznes
   `timezone` maydoni bor ekan, hisob shu maydondan olinishi kerak.
4. **Rol tekshiruvi faqat backendda.** UI hamma tugmani ko'rsatadi → foydalanuvchi
   403 ga uriladi.

---

## 4a. Mobil (telefon) — hozirgi holat

Kod bo'yicha tekshirildi, taxmin emas.

**Bor:**
- `viewport` meta ikkala SPA'da to'g'ri
- Sidebar 860px dan pastda burger + drawer bo'lib yig'iladi
- `.field-row` va `AppointmentForm` ning uch ustuni 880px da bitta ustunga tushadi
- Jadvallar `.table-wrap` ichida gorizontal skroll bo'ladi (ma'lumot yo'qolmaydi)

**Yetishmayapti:**

| Muammo | Nega og'riqli | Yechim |
|---|---|---|
| **15 ta jadvalli sahifa**, har hujayrada `white-space: nowrap` | Telefonda Navbatlar/Mijozlar/Moliya doim yonga suriladi | ~640px dan pastda qator → **karta** (ustun nomi + qiymat) |
| **Jadval (Timetable) — 7 kunlik setka** | 390px ekranda o'qib bo'lmaydi; faqat nav tugmalari moslashgan | Telefonda **bir kunlik** ko'rinish (ustun = usta) yoki oddiy ro'yxat |
| **Teginish maydoni ~36px** (`.btn` 9×16, input 9×11) | Barmoq bilan, ho'l qo'l bilan tegish qiyin | ≤640px da 44px minimal balandlik |
| **Modal telefonda ham "oyna"** | Uzun forma o'rtada qisilib qoladi | ≤640px da to'liq ekranli sheet (pastdan chiqadi) |
| **Mini-kalendar drawer'ning yarmini egallaydi** | Menyuga yetish uchun skroll kerak | Telefonda yig'iladigan qilish yoki yashirish |

**Ustuvorlik:** jadval→karta va bir kunlik Timetable — qolgan hammasidan
muhimroq, chunki usta kunda eng ko'p shu ikki ekranga qaraydi.

## 5. Bajarilish holati (2026-08-17)

| Punkt | Holat |
|---|---|
| 1. Ombor barberda yashirildi | ✅ |
| 1. Sertifikatlar barberda yashirildi | ✅ (salonda qoldi) |
| 2.1 Jonli navbat / walk-in | ✅ |
| 2.3 Tushlik tanaffusi (bir necha oraliq) | ✅ |
| 2.4 Booking oqimi 5 → 2-3 qadam | ✅ |
| 2.5 Takroriy yozuv (rebooking) | ✅ |
| 2.7 No-show belgisi | ✅ |
| 3. Rol bo'yicha tugmalar + o'zbekcha xato | ✅ |
| 4.1 `api-client` shartnoma funksiyalari | ✅ (working-hours) |
| 4.2 Bo'sh ro'yxat himoyasi | ✅ (`?clear=1`) |
| **2.2 Bir yozuvda bir necha xizmat** | ✅ (migratsiyasiz — `appointment_items`) |
| **2.6 Mijoz kartasi maxsus maydonlari** | ⏳ migratsiya talab qiladi |
| **2.9 Xizmat bo'yicha usta foizi** | ⏳ migratsiya talab qiladi |
| 1. Hisobot sahifalarini birlashtirish | ⏳ |
| 1. Mijoz kategoriyalarini yashirish | ⏳ |
| 4.3 Vaqt zonasini biznesdan olish | ⏳ |
| 2.8 Telegram eslatmasida tasdiq tugmalari | ⏳ (eslatma yuboriladi, tugmalar yo'q) |
| **Mobil: jadval → karta** | ⏳ |
| **Mobil: bir kunlik Timetable** | ⏳ |
| **Mobil: teginish maydoni + sheet modal** | ⏳ |

Qolganlari `appointments` / `clients` / `services` jadvallarida schema o'zgarishini
talab qiladi (`appointment_items` ni slot engine uchun ochish, `clients.profile`
JSON, `service_staff_commission`). Ular boshqa vertikallar ham ishlatadigan
jadvallarga tegadi — shuning uchun alohida, migratsiyali va sinovli qadam sifatida
qilinishi kerak.

## 6. Tavsiya etilgan tartib

**1-to'lqin (kunlik ishni yopadi):**
1. Jonli navbat / "Hozir keldi" (2.1)
2. Tushlik tanaffusi — ish jadvalida bir necha oraliq (2.3)
3. Booking oqimi 5 → 2-3 qadam (2.4)

**2-to'lqin (pul va qaytish):**
4. Bir yozuvda bir necha xizmat (2.2)
5. Takroriy yozuv taklifi (2.5)
6. Xizmat bo'yicha usta foizi (2.9)

**3-to'lqin (ushlab qolish va tozalash):**
7. Mijoz kartasi maxsus maydonlari — bo'yoq formulasi / mashinka raqami (2.6)
8. No-show belgisi (2.7)
9. Nav tozalash: sertifikat/kategoriya/hisobotlarni birlashtirish (1-bo'lim)
10. `api-client` shartnoma funksiyalari (4.1)
