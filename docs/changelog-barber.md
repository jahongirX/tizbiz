# Barber vertikali — ish jurnali (branch `jalol`)

> Bizning zonamizdagi (barber / `slot` engine) o'zgarishlar shu yerda yozib boriladi.
> Maqsad: prezentatsiya va PR tavsifi uchun tayyor material. Yangi yozuv — tepaga.
> Zona qoidalari: [CLAUDE.md §9](../CLAUDE.md).

---

## 2026-08-17 — barber optimizatsiyasi (1-3 to'lqin)

Reja: [barber-optimization-plan.md](barber-optimization-plan.md).

### 31. Navbatlar sahifasida filtrlar yangilashdan keyin tiklanadi

**Muammo.** Sana oralig'i, xodim va holat tanlangandan keyin "Ko'rsatish"
bosilsa ro'yxat to'g'ri chiqardi, lekin sahifa yangilansa hammasi standart
holatga (bugun + 7 kun, barcha xodim) qaytardi.

**Yechim.** Filtrlar endi **URL query** da saqlanadi:
`/app/appointments?from=…&to=…&staff=…&status=…`. Sahifa ochilganda holat
o'sha yerdan tiklanadi.

URL tanlangani uchun ikkita qo'shimcha foyda bor: havolani hamkasbga yuborsa
ham o'sha ko'rinish ochiladi, va brauzerning "orqaga" tugmasi sahifadan chiqadi
— har bir filtr o'zgarishi tarixga yozilmaydi (`router.replace`).

### 30. Jadvalda qisqa yozuvlar faqat soatni ko'rsatardi

**Muammo.** 10-30 daqiqalik xizmat (masalan "Qosh olish") blokida faqat `10:00`
ko'rinardi — xizmat nomi ham, mijoz ham yo'q. Ya'ni eng kerakli qism kesilib
qolardi.

**Sabab.** Blok balandligi davomiylikdan hisoblanadi (soatiga 56px), minimal
22px. Uchta qator (vaqt / xizmat / mijoz) esa ~46px joy talab qiladi, ortiqchasi
`overflow: hidden` bilan kesilardi — birinchi bo'lib vaqt sig'ardi, qolgani yo'q.

**Yechim.** Blok balandligiga qarab uch xil ko'rinish:

| Davomiylik | Ko'rinish |
|---|---|
| 50 daqiqa va undan uzun | vaqt / xizmat / mijoz — uch qator |
| 30-40 daqiqa | vaqt va xizmat **bitta qatorda**, mijoz yashiriladi |
| 10-25 daqiqa | xuddi shunday, shrift bir oz kichik |

Bundan tashqari har blokka `title` qo'shildi — sichqonchani olib borsangiz
to'liq ma'lumot (vaqt · xizmat · mijoz) chiqadi. Minimal balandlik 26px ga
ko'tarildi.

### 29. "Yangi" va "Yo'qolgan" segmentlari bo'sh edi (demo ma'lumot)

**Muammo.** Mijozlar bazasida "Yangi" va "Yo'qolgan" filtrlari hech nima
ko'rsatmasdi.

**Sabab — kod emas, ma'lumot.** API va SQL bir xil natija berdi (0 va 0):
bulk seed har bir mijozga ko'plab tashrif bergan va hammasining oxirgi tashrifi
yaqin edi. Segment ta'riflari: *Yangi* = 1 tadan ko'p bo'lmagan tashrif,
*Yo'qolgan* = 60 kundan beri kelmagan. Ikkalasiga ham mos keluvchi mijoz yo'q edi.

**Yechim.** Seed endi haqiqiy bazadagidek uch xil mijozni yaratadi:

- **8 yangi** — 0 yoki 1 ta yaqin tashrif ("Birinchi marta keldi")
- **6 yo'qolgan** — 2-4 ta tashrif, hammasi 70-140 kun oldin
- qolganlari doimiy mijozlar

**Natija.** Barchasi 48 · Yangi 9 · Takroriy 39 · Yo'qolgan 6.

### 28. Public bron mijozsiz saqlanardi (bug) + vaqt formati

**Muammo.** Saytdan navbat olinganda "Navbat band qilindi!" chiqardi, lekin
adminda o'sha yozuvning mijozi **bo'sh** (`—`) bo'lardi.

**Sabab va yechim (uch qatlam).**

1. **Jimgina yo'qolish.** `upsertClient()` telefon bo'sh bo'lsa `null`
   qaytaradi, `actionCreate` esa yozuvni baribir saqlardi. Endi public bronda
   mijoz aniqlanmasa — **400**: *"Telefon raqamingizni kiriting."* Ya'ni
   ma'lumot jimgina yo'qolishi o'rniga xato ko'rinadi. Admin tomondan
   yaratilgan yozuv avvalgidek mijozsiz bo'lishi mumkin (walk-in shunday ishlaydi).
2. **Telefon formati.** Booking sahifasi `+998 90 123 45 67` (bo'shliqli),
   admin esa `+998901234567` saqlaydi. Qidiruv xom satr bo'yicha ketgani uchun
   **bir odamga ikkita mijoz kartasi** ochilardi. Endi raqam bitta ko'rinishga
   normallashtiriladi (`normalizePhone`), ya'ni bo'shliqli raqam mavjud mijozga
   tushadi.
3. **Forma yopiq qolishi.** `ConfirmStep` da maydonlar `props.client.phone` bo'sh
   bo'lmasa yashirilardi — yarim to'ldirilgan xotira (masalan ismsiz) bilan forma
   yopiq turaverar edi. Endi mezon bitta: yuborishga yaroqli bo'lmasa — forma ochiq.

**Yo'l-yo'lakay ikkita vaqt bug'i.** API `start_local` ni faqat soat sifatida
qaytaradi ("09:30"), UI esa to'liq sana-vaqt kutardi:

- `slotBucket()` soatni qat'iy o'rindan o'qir edi → **hamma slot "Ertalab"**
  bo'limiga tushardi. Endi ikkala ko'rinish ham tushuniladi.
- `prettyLocal()` sanasiz qiymatda `"09:30 · "` (osilib qolgan ajratgich)
  qaytarardi. Endi `DateTimeStep` tanlangan kunni slotga biriktiradi va
  tasdiqlash ekrani **"26 avgust · 09:30"** deb yozadi.

**Tekshiruv.** Bo'sh mijoz bilan bron → 400; `+998 90 123 00 01` → mavjud
mijoz #14 ga bog'landi (yangi karta ochilmadi); guruhlash 09:00→ertalab,
14:00→kunduzi, 19:30→kechqurun.

### 27. To'liq demo do'kon: chizilgan avatarlar + oylik tarix

**Avatarlar.** Ism harflari o'rniga ustalar endi **chizilgan portret** bilan
chiqadi: bosh, soch, soqol va yelka rangli fonda. Uslub (soch turi, soqol yoki
mo'ylov) indeksdan tanlanadi, ya'ni ustalar bir-biridan farq qiladi. Xizmat
kartochkalarida ham bitta qaychi o'rniga uchta belgi aylanadi: **qaychi, ustara,
taroq**. Hammasi GD bilan joyida chiziladi — internetdan hech nima olinmaydi.

**Bulk demo.** Yangi komanda
`php yii barber-bulk/generate [slug] [pastDays] [futureDays]` do'konni haqiqiy
tarix bilan to'ldiradi:

- 34 mijoz (kartada usta eslab qoladigan izohlar bilan)
- **437 yozuv**: 75 kun orqaga va 12 kun oldinga, yakshanba yopiq, shanba eng
  band kun; 342 bajarilgan, 20 kelmagan, 12 bekor, 58 kelajakdagi
- har to'rtinchi tashrifda **ikkinchi xizmat** (soch + soqol) — 114 ta yozuv
- mijoz kategoriyalari (VIP / Doimiy / Yangi) tashriflar soniga qarab biriktiriladi
- abonement turlari, ustaning dam olish kuni, onlayn depozitlar (Payme + Click)

Pul va keshbek **seed ichida qo'lda yozilmaydi** — o'sha `appointmentCompleted`
hodisasi ishga tushiriladi, ya'ni demo tarix ilova real ishlaganda yozadigan
narsaning aynan o'zi. Generator deterministik (bir xil seed → bir xil do'kon) va
mavjud yozuvlarga tegmaydi.

**Keshbek uchun:** `php yii loyalty/backfill [slug]` — qoida yoqilmasdan oldin
yakunlangan tashriflarga keshbekni qaytadan hisoblaydi. Idempotent.

**Natija.** Moliya: **26 065 000 so'm**, 348 tranzaksiya (naqd 342, Payme 4,
Click 2). Keshbek: 340 yozuv, jami 1 288 750 so'm. Eng faol mijozda 67 000 so'm
balans.

### 26. Bo'lim tablari — booking sahifasida ham, adminda ham

Uchta bo'lim ostidagi 11 ta xizmat bitta ustunda uzun ro'yxat bo'lib qolgan edi.

**Nega drill-down emas.** "Kategoriyani och → ichidan tanla" varianti ko'p
xizmat tanlash bilan qarama-qarshi: bitta tashrif ko'pincha ikki bo'limga tegadi
(soch + soqol), ya'ni mijoz ichkariga kirib-chiqib yurishi kerak bo'lardi.
Shuning uchun **tab (filtr)**: bosilganda ro'yxat qisqaradi, tanlovlar esa
saqlanib qoladi.

- **Booking sahifasi** — "Hammasi" + har bo'lim uchun chip. Boshqa bo'limda
  tanlangan xizmatlar yo'qolib qolmasligi uchun tepada eslatma chiqadi
  ("Boshqa bo'limdan tanlangan: …"), pastda esa jami paneli avvalgidek turadi.
  "Hammasi" da bo'lim sarlavhalari ko'rinadi, bitta bo'lim tanlanganda ular
  ortiqcha bo'lgani uchun yashiriladi.
- **Admin → Xizmatlar** — jadval ustida shu tablar, har birida xizmatlar soni;
  "Bo'limsiz" faqat kerak bo'lganda chiqadi.

Gate bitta joyga yig'ildi: `isBarberShop(business)` (`apps/admin/src/lib/verticals.js`).
`AppointmentForm` ham endi shu funksiyani ishlatadi — ilgari kategoriyalar ro'yxati
ikki joyda takrorlanardi.

**Tekshiruv.** Tab hisoblari: Hammasi 11, Soch olish 4, Soqol va yuz 3,
Qo'shimcha 3, Bo'limsiz 1.

### 25. Xizmat kategoriyalari endi mijozga ham ko'rinadi

**Muammo.** Xizmat kategoriyalari ("Soch olish", "Soqol va yuz", "Qo'shimcha")
faqat admin jadvalidagi ustun edi. Public booking sahifasi 11 ta xizmatni
**tekis ro'yxat** qilib chiqarardi — `category_id` payload'da kelsa ham,
`ServiceStep` uni o'qimasdi. Ya'ni bo'limlarni yaratishning amaliy foydasi yo'q edi.

**Yechim.**
- `SlotEngine::publicData()` ga `service_categories` qo'shildi (`sort`, keyin
  `id` bo'yicha tartiblangan). Additive — bu maydonni o'qimaydigan klient
  avvalgi payload'ni ko'radi.
- `ServiceStep` xizmatlarni bo'lim sarlavhalari ostida guruhlaydi. Bo'limi
  yo'q xizmatlar oxirida "Boshqa" ostida chiqadi; bo'limi umuman bo'lmagan
  biznesda esa avvalgidek bitta tekis ro'yxat qoladi.
- Guruhlash ham ko'p tanlov kabi **faqat `barber`/`salon`** da yoqiladi
  (`isBarberShop`), shuning uchun `slot` engine'ga tushadigan boshqa turlar
  o'zgarishsiz qoladi.

**Tekshiruv.** `jalolbek` → 3 bo'lim (4 + 3 + 3 xizmat) va bo'limsiz 1 ta
xizmat "Boshqa" da; `demo` (klinika) → gate yopiq, tekis ro'yxat.

### 24. Moliya naqd tushumni ko'rmasdi (offline zakazlar)

**Muammo.** Moliya sahifasi kun bo'yi ishlagan sartaroshxonaga ham
"Kirim: 0 so'm" ko'rsatardi. Sabab: hisobot faqat `transactions` jadvalidagi
**to'lov provayderi** yozuvlarini (Payme/Click depozitlari) o'qirdi. Barberning
pulining aksariyati esa kursida naqd to'lanadi va hech qayerga yozilmasdi.

**Yechim.** Yakunlangan tashrif endi o'z yozuvini oladi.

- `Transaction` ga ikkita qiymat qo'shildi: `provider = cash` (do'konda
  to'langan) va `type = sale` (xizmat to'lovi). Enum kengaytmasi — mavjud
  yozuvlarga ta'sir qilmaydi.
- Yangi `SaleService` `appointmentCompleted` hodisasiga ulanadi va tashrifning
  **to'liq summasi** (asosiy xizmat + qo'shimcha xizmatlar + sotilgan
  mahsulotlar) uchun bitta `sale` yozuvi yozadi.
- **Qo'shaloq hisoblanmaydi:** onlayn to'langan depozit ayiriladi. 50 000 so'mlik
  tashrifda 20 000 depozit to'langan bo'lsa, naqd sotuv 30 000 bo'lib yoziladi.
  To'liq oldindan to'langan bo'lsa — umuman yozilmaydi.
- `idempotency_key = sale:appointment:<id>` — takroriy yakunlash yangi yozuv
  yaratmaydi.
- Hodisa API va konsolda ham ishlaydi, ya'ni **qo'lda yakunlangan** va
  **avto-yakunlangan** (cron) tashrif bir xil yoziladi.
- `GET /v1/finance/summary` endi kirimni `sale + deposit` bo'yicha hisoblaydi;
  provayderlar kesimida "Naqd" alohida chiqadi. Filtrlarga "Naqd" va
  "Xizmat to'lovi" qo'shildi.

**Eski ma'lumot uchun:** `php yii finance/backfill-sales [slug]` — bu
o'zgarishdan oldin yakunlangan tashriflar uchun yetishmagan yozuvlarni to'ldiradi.
Idempotent.

**Tekshiruv.** Backfill 13 ta yozuv yozdi (845 000 so'm); qayta ishga tushirilganda
0 ta yangi. API orqali yakunlash → 50 000 so'mlik naqd sotuv; cron orqali
yakunlash → xuddi shunday. To'langan depozitli tashrifda sotuv 30 000 bo'ldi.
Moliya summary: **895 000 so'm, 14 tranzaksiya** (avval 0 edi).

### 23. Ustalar va xizmatlar uchun demo rasmlar

Barcha ustalarda avatar, barcha xizmatlarda rasm bo'sh edi — demo bo'm-bo'sh
ko'rinardi.

**Yechim.** Yangi konsol komandasi
`php yii barber-image/generate [slug] [baseUrl] [--only=masters|services] [--force]`
GD bilan **joyida chizadi** — internetdan hech nima olinmaydi, birovning surati
ishlatilmaydi:

- **Usta** — 320×320, hue bo'yicha gradient disk + ism harflari (JN, SQ, AT…).
- **Xizmat** — 480×320, gradient + qaychi belgisi + xizmat nomi.
- Ranglar oltin burchak (137.5°) bo'yicha aylanadi, ya'ni qo'shni yozuvlar
  bir-biriga o'xshab qolmaydi.

Fayllar `POST /v1/uploads` qayerga qo'ysa, o'sha joyga yoziladi
(`api/web/uploads/YYYYMM/`), URL esa `staff.avatar` / `services.image` ga
saqlanadi. Rasmi bor qatorga tegilmaydi (`--force` bundan mustasno).

Booking saytida xizmat kartasiga kichik rasm qo'shildi (`ServiceStep`); rasm
yo'q bo'lsa avvalgidek ko'rinadi.

**Natija.** 5/5 usta va 11/11 xizmat rasmli.

### 22. Bir yozuvda bir necha xizmat (soch + soqol)

Barberning eng ko'p buyurtmasi bitta xizmat emas. Ilgari `service_id` bitta
bo'lgani uchun ikkinchi xizmatning vaqti jadvalda ko'rinmasdi va slot noto'g'ri
hisoblanardi.

**Yondashuv.** Migratsiya kerak bo'lmadi: `appointment_items` jadvali
`kind = service` ni allaqachon qo'llaydi. Birinchi xizmat avvalgidek
`service_id` da qoladi (barcha eski o'quvchilar ishlayveradi), qolganlari
qator sifatida yoziladi.

- `AvailabilityService::slots(..., array $extraServiceIds = [])` — slot
  uzunligi barcha xizmatlar yig'indisi. `GET .../availability?...&extra=7,10`.
- `POST /v1/appointments` ixtiyoriy `extra_service_ids` qabul qiladi:
  `ends_at` yig'indi bo'yicha, qo'shimchalar `appointment_items` ga snapshot
  qilinadi. Public bronda faqat faol va onlayn xizmatlar ruxsat etiladi;
  begona xizmat 400 qaytaradi.
- `Appointment::fields()` ga `service_names` qo'shildi (birlamchi + qo'shimchalar).
- **Keshbek** endi qo'shimcha xizmatlarni ham hisoblaydi
  (`kind = service` qatorlari). Mahsulotlar avvalgidek hisobga kirmaydi —
  catalog vertikalining xatti-harakati o'zgarmadi.

**Faqat barber/salon.** Ko'p tanlov `category` bo'yicha yoqiladi
(`barber`, `salon`). `slot` engine'ga tushadigan boshqa biznes turlari (masalan
ijara — hozircha o'z engine'i yo'q) avvalgidek: belgilash katakchasi ham, jami
paneli ham ko'rinmaydi, xizmatni bosish darhol keyingi qadamga o'tkazadi.
Admin formasida ham xuddi shunday gate bor.

**Frontend.**
- Booking sayti: `ServiceStep` — ko'p tanlovli, pastda yopishib turuvchi jami
  (narx, davomiylik, depozit) va "Davom etish".
- Tasdiqlash va yakuniy ekranda xizmatlar ro'yxati, yig'ma narx va depozit.
- Admin: "Yangi yozuv" formasida xizmatlarni bir nechta tanlash (davomiylik
  avtomatik yig'iladi); jadval va Navbatlar ro'yxatida "Soch + Soqol" ko'rinadi.

**Tekshiruv.** 30 daq → 20 slot; +20 daq → 7 slot. Uch xizmatli yozuv
04:00→05:00 yaratildi, keshbek bazasi 95 000 so'm; ustma-ust yozuvga urinish
"Tanlangan vaqt band" bilan rad etildi.

### 21. Jadvalda usta tanlash: select o'rniga tab, tanlov esda qoladi

**Muammo.** Ustani almashtirgandan keyin sahifa yangilansa, tanlov birinchi
ustaga qaytardi. Bundan tashqari 3-5 ta usta uchun ochiladigan select ortiqcha
bosish talab qilardi.

**Yechim.**
- Usta tanlash **tab** ko'rinishida: rasm (yoki ism harflari) + ism +
  mutaxassislik. Bitta bosish, kim tanlanganini bir qarashda ko'rinadi.
- Tanlov `localStorage` da **biznes bo'yicha** saqlanadi
  (`tizbiz_tt_staff_<businessId>`) — bitta hisobda bir nechta biznes bo'lsa
  aralashmaydi. Saqlangan usta o'chirilgan bo'lsa, birinchi faol ustaga tushadi.

Fayl: `apps/admin/src/views/Timetable.vue`.

### 20. Mijoz kategoriyalari — nima uchunligi endi ko'rinadi

**Muammo.** Kategoriyalar sahifasida faqat nom, rang va tartib bor edi. Mijozni
guruhga qanday qo'shish kerakligi hech qayerda aytilmagan (u aslida Mijozlar →
Baza → mijoz kartasida), guruhda kimdir bor-yo'qligi ham bilinmasdi.

**Yechim.**
- Sahifa boshida qisqa izoh: kategoriya nima uchun kerak, mijozni qayerda
  biriktiriladi va avtomatik qoidalar qayerda (Loyallik kartalari) — havolalar bilan.
- `GET /v1/client-categories` javobiga `clients_count` qo'shildi; jadvalda
  "Mijozlar" ustuni chiqadi va bosilganda o'sha guruh bo'yicha filtrlangan baza
  ochiladi.
- `GET /v1/clients` endi `category` parametrini qabul qiladi. Mijozlar sahifasida
  faol filtr rangli chip bo'lib turadi, × bilan tozalanadi.

Ikkala backend o'zgarishi ham qo'shimcha (additive) — parametr yuborilmasa
xatti-harakat avvalgidek.

**Tekshiruv.** Kategoriya yaratildi → mijozga biriktirildi → `clients_count: 1`,
`?category=2` bo'yicha ro'yxatda 1 ta mijoz.

### 19. Xato matnlari o'zbekchada + yozuv o'zi yakunlanadi

**Xato matnlari.** Holat o'zgarishi rad etilganda texnik kalitlar chiqardi:
*"Holatni 'canceled' dan 'completed' ga o'zgartirib bo'lmaydi."* Endi
`Appointment::STATUS_LABELS` orqali:
*«Bekor qilindi» holatidan «Bajarildi» holatiga o'tkazib bo'lmaydi.*
Shu bilan birga `TenantContext` dagi oxirgi inglizcha xabar ham tarjima qilindi
("No active business selected." → "Faol biznes tanlanmagan.").

**Avtomatik yakunlash.** Yangi konsol komandasi
`php yii appointment/auto-complete [graceMin]`: **"Keldi"** holatidagi yozuv
xizmat vaqti tugagach o'zi **"Bajarildi"** ga o'tadi. Usta kompyuterga qaytib
tugma bosmaydi.

- Faqat `arrived` supuriladi. `pending`/`confirmed` tegilmaydi — bu mijoz
  ro'yxatdan o'tmaganini bildiradi, uni yakunlash yo'q tushumni yozish bo'lardi.
- `graceMin` — usta bir-ikki daqiqa cho'zsa kesib qo'ymasligi uchun.
- Konsol ilovasiga `appointmentCompleted` hodisasi ulandi, ya'ni keshbek
  API orqali yakunlangandagi kabi hisoblanadi.

Cron (har 5 daqiqada):

```
*/5 * * * *  php /path/yii appointment/auto-complete
```

**Tekshiruv.** Vaqti o'tgan 3 ta "Keldi" yozuvi "Bajarildi" ga o'tdi; kelajakdagi
yozuvlarga tegilmadi.

### 18. Ustalarga rasm (avatar)

Mijoz ustani ismidan emas, **yuzidan** taniydi — booking sahifasida esa faqat
ism harflari ko'rinardi.

- **Migratsiya** `m260817_100000_add_avatar_to_staff` — `staff` jadvaliga
  nullable `avatar` (URL, 500 belgi). Additive: boshqa vertikallar o'zgarishsiz
  ishlayveradi.
- `common/models/Staff.php` — maydon va validatsiya qoidasi.
- `StaffController::assign()` — `avatar` qabul qilinadi; bo'sh satr rasmni
  o'chiradi (brending maydonlaridagi kabi).
- `apps/admin/src/views/Staff.vue` — formada `ImageUpload` (mavjud
  `POST /v1/uploads` orqali), ro'yxatda dumaloq avatar; rasm yo'q bo'lsa ism
  harflari ko'rinadi.
- `apps/booking/src/components/StaffStep.vue` — usta kartasida rasm.
  Public payload allaqachon butun modelni qaytaradi, shuning uchun
  `SiteController` ga tegilmadi.

**Tekshiruv.** Rasm bilan yaratish → saqlandi; `{"avatar":""}` → `null`;
public `/v1/site/{slug}` javobida maydon bor.

### 17. Mijoz kategoriyalari sahifasi bo'sh ochilardi (bug)

**Muammo.** Mijozlar → Kategoriyalar bosilganda sahifa butunlay bo'sh edi: sarlavha
ham, "kategoriya qo'shilmagan" xabari ham chiqmasdi.

**Sabab.** `Categories.vue` da `const form = ref(blank())` chaqiruvi `presets`
massivi e'lon qilinishidan **oldin** turardi. `blank()` funksiyasi hoisting
tufayli mavjud, lekin `presets` o'sha paytda hali TDZ (temporal dead zone) da —
`ReferenceError: Cannot access 'presets' before initialization`. Xato `setup()`
ichida yuz bergani uchun komponent umuman render bo'lmasdi; layout esa joyida
qolgani uchun tashqaridan "sahifa bo'sh" bo'lib ko'rinardi.

**Yechim.** `presets` va `blank()` `form` dan oldinga ko'chirildi.

**Nima uchun kerak.** Bu sahifa mijozlarni ranglangan guruhlarga ajratadi (VIP,
Doimiy, Yangi). Guruh mijozlar bazasida chip sifatida ko'rinadi va segment bo'yicha
filtrlash uchun ishlatiladi. API (`/v1/client-categories`) ishlayotgan edi — faqat
sahifa ochilmasdi.

### 16. Yozuv holatini o'zgartirib bo'lmasdi — seed'dagi noto'g'ri `source` (bug)

**Muammo.** Navbatlar ro'yxatida holatni "Tasdiqlangan" dan "Keldi" ga o'zgartirsa,
qizil "Manba noto'g'ri." xatosi chiqib, holat saqlanmasdi.

**Sabab.** `seed/barber` public saytdan kelgan yozuvlarga `source = 'site'` yozgan edi,
model esa faqat `admin` / `link` / `telegram` ni qabul qiladi
(`Appointment::SOURCE_*`). Seed `save(false)` bilan yozgani uchun validatsiya
o'tkazib yuborilgan va yaroqsiz qiymat bazaga tushgan. Keyin har qanday tahrirda
model **barcha** maydonlarni tekshiradi va aynan shu eski qiymatda yiqilardi.

**Yechim.** Seed endi `Appointment::SOURCE_LINK` konstantasini ishlatadi (satr emas).
Bazadagi mavjud `'site'` qatorlari `'link'` ga tuzatildi.

**Tekshiruv.** `source=admin` va `source=link` yozuvlarida holat o'zgarishi saqlandi.

**Saboq.** Seed'da `save(false)` validatsiyani o'chiradi — konstantalar o'rniga qo'lda
yozilgan satrlar shu yo'l bilan bazaga kirib qoladi va keyin boshqa joyda portlaydi.

### 8. Demo ma'lumot: `php yii seed/barber [slug]`

Yangi konsol komandasi barber biznesini real ma'lumot bilan to'ldiradi: 3 usta
(foizi bilan), 3 kategoriya + 10 xizmat (narx tiyinda), 8 mijoz (kartada usta
eslab qoladigan izohlar — "Mashinka #2", "Fade"), kecha/bugun/ertangi yozuvlar
(bittasi `no_show`), 5% keshbek qoidasi va **tanaffusli ish jadvali**
(Du-Sha 09:00-13:00 + 14:00-20:00). Qayta ishga tushirish xavfsiz: mavjud
yozuvlarga tegmaydi. Fayl: `console/controllers/SeedController.php`.

### 9. Ish jadvali: kunga bir necha oraliq (tushlik tanaffusi)

`working_hours` bazasi kuniga bir nechta qatorni allaqachon qo'llardi, lekin UI
kuniga faqat bitta oraliq berardi — tushlikni yopishning iloji yo'q edi.
Endi har kunda "+ Tanaffus" (bitta blokni ikkiga bo'ladi) va "+ Oraliq"
tugmalari bor; yuklashda qatorlar kun bo'yicha guruhlanadi.
Fayl: `apps/admin/src/views/Schedule.vue`.

**Tekshiruv.** Availability 18 slot qaytardi, 13:00-13:30 oralig'i yo'q.

### 10. Jonli navbat — "Hozir keldi" (walk-in)

Sartaroshxonaga mijozlarning ko'pchiligi yozilmasdan keladi. Jadval sahifasida
yangi tugma bitta ekran ochadi: usta + xizmat (chip'lar), telefon **ixtiyoriy**,
vaqt = hozir (5 daqiqagacha yaxlitlangan), status `arrived`. Sana/vaqt tanlash
yo'q. Backend o'zgarmadi — `POST /v1/appointments` allaqachon `client_id` siz va
admin tomonidan berilgan status bilan ishlaydi.
Fayl: `apps/admin/src/components/WalkInForm.vue`, `views/Timetable.vue`.

### 11. Booking oqimi: 5 qadam → 2-3 qadam

- Biznesda **bitta usta** bo'lsa "Mutaxassis" qadami umuman ko'rsatilmaydi.
- **"Farqi yo'q"** varianti: barcha ustalarning bo'sh vaqti birlashtiriladi,
  tanlangan vaqt ustani ham belgilaydi (`DateTimeStep` endi `staff-ids` massivini
  oladi va so'rovlarni parallel yuboradi).
- "Ma'lumotlaringiz" qadami **tasdiqlash ekraniga birlashdi** (`InfoStep.vue`
  o'chirildi). Qaytgan mijozning ismi/telefoni `localStorage` dan tiklanadi va
  faqat "O'zgartirish" bosilganda tahrirlanadi.

Natija: qaytgan mijoz uchun **xizmat → vaqt → tasdiqlash**.
Fayllar: `apps/booking/src/engines/slot/SlotEngineApp.vue`, `components/{StaffStep,DateTimeStep,ConfirmStep}.vue`.

### 12. Takroriy yozuv (rebooking)

Yozuv "Bajarildi" ga o'tkazilganda darhol so'raladi: "Keyingi safarga yozamizmi?"
— rozi bo'lsa forma o'sha usta / xizmat / mijoz bilan, **3 hafta keyingi** o'sha
vaqtga to'ldirilgan holda ochiladi. Yozuv oynasida "Takror yozish" tugmasi ham bor.
`AppointmentForm` endi `serviceId`/`clientId`/`client` bilan ham to'ldiriladi.

### 13. No-show belgisi

`GET /v1/clients` javobiga `no_shows` agregati qo'shildi (orqaga mos — qo'shimcha
maydon). Mijozlar ro'yxatida 2 va undan ko'p bo'lsa qizil "2× kelmagan" belgisi
chiqadi. Fayllar: `api/modules/crm/controllers/ClientController.php`,
`apps/admin/src/views/Clients.vue`.

### 14. Nav tozalash + rol tekshiruvi + o'zbekcha xato

- "Sertifikatlar" `category = barber` bo'lganda yashiriladi (salonda qoladi).
- `Staff.vue` da "Yangi xodim" / "Tahrir" / "O'chirish" endi faqat
  `business_owner` va `business_admin` ga ko'rinadi — 403 ga urilish tugadi.
- `common/rest/Controller.php`: "Insufficient role for this action." →
  "Bu amal uchun ruxsatingiz yetarli emas."

### 15. API shartnomasi mustahkamlandi (texnik qarz)

Ikkita himoya, `days`/`items` bug'i sinfini yopadi:

1. `packages/api-client` da nomlangan funksiya — `booking.saveWorkingHours(staffId, days)`
   payload'ni bitta joyda quradi; `Schedule.vue` endi shuni chaqiradi.
2. `ScheduleController::actionUpdateWorkingHours` bo'sh ro'yxatni **rad etadi**
   (400). Butun haftani tozalash uchun `?clear=1` kerak — ilgari bo'sh payload
   jimgina hamma narsani o'chirib, 200 qaytarardi.

**Tekshiruv.** `{"days":[]}` → 400; tanaffusli payload → 2 qator saqlandi.

---

## 2026-08-16

### 5. Go'zallik saloni "Barber" deb belgilanardi (vertikal moslash)

**Muammo.** Sidebar'dagi badge har doim vertikalning nomini (`Barber`) ko'rsatardi.
`barber` vertikali esa ikki xil biznesni qamraydi — sartaroshxona va go'zallik saloni.
Salon egasi o'z kabinetida "Barber" yozuvini ko'rardi. Bundan tashqari ro'yxatdan
o'tishda salon o'zini salon deb belgilay olmasdi: sehrgar doim `category: 'barber'`
yuborardi.

**Yechim.**
- `apps/admin/src/lib/verticals.js` — `barber` vertikaliga `subCategories`
  (`barber` / `salon`) va `categoryLabel(business)` funksiyasi qo'shildi. O'z yorlig'i
  yo'q kategoriyalar avvalgidek vertikalning `short` nomiga tushadi — boshqa
  vertikallar uchun hech nima o'zgarmaydi.
- `apps/admin/src/views/Register.vue` — 2-qadamda "Biznes turi" tanlovi (faqat
  `subCategories` bor vertikallarda ko'rinadi), tanlangan qiymat `category` sifatida
  yuboriladi. `engine` avvalgidek `slot`.
- `apps/admin/src/components/AppLayout.vue` — badge endi `categoryLabel()` dan
  o'qiydi: sartaroshxona → "Barber", salon → "Salon".

Backend'ga tegilmadi: `category` ixtiyoriy satr, `salon` esa `CATEGORY_ALIAS` orqali
o'sha barber vertikaliga (`slot` engine) tushadi.

### 7. Placeholder va yordamchi matnlar barber/salonga moslandi

**Muammo.** Admin formalaridagi namunalar kafe/tort vertikalidan qolgan edi: xizmat
kategoriyasi — "Tortlar", biznes nomi — "Shirin Tort", slug — "aziza-tortlari",
sarlavha ostidagi matn — "Onlayn buyurtma", tavsif — "Mahsulot haqida...".
Sartaroshxona egasi uchun bular chalg'ituvchi.

**Yechim.** `apps/admin/src/lib/verticals.js` ga `samplesFor(business)` qo'shildi:
`SAMPLES_DEFAULT` (bugungi matnlar) ← vertikal `samples` ← sub-kategoriya `samples`.
Ya'ni **o'z `samples` i yo'q vertikallarda matn bir harf ham o'zgarmaydi**.

Barber/salon uchun: nomi "Barber King" / "Aziza Beauty", slug `barber-king` /
`aziza-beauty`, kategoriya "Soch olish" / "Soch parvarishi", mutaxassislik
"Usta / Sartarosh" / "Usta / Stilist", tagline "Onlayn navbat olish", tavsif
"Xizmat haqida qisqacha ma'lumot", kategoriya bo'sh bo'lgandagi maslahat
"Xizmatlarni bo'limlarga ajrating".

**Ulangan joylar:** `Services.vue` (nomi, tavsif, kategoriya nomi, bo'sh holat matni),
`Staff.vue` (mutaxassislik), `BookingSettings.vue` (biznes nomi, slug, tagline +
ko'rinish preview'i), `Register.vue` (biznes nomi, slug — tanlangan yo'nalish va
biznes turiga qarab).

### 6. Mavjud biznes o'z turini o'zgartira oladi (Sozlamalar)

Ro'yxatdan o'tgan biznes keyinchalik "Barber ↔ Salon" ni almashtira olmasdi.

- `api/modules/booking/controllers/SettingsController.php` — `PUT /v1/settings/booking`
  endi ixtiyoriy `category` ni qabul qiladi va uni `GET` javobida qaytaradi. **`engine`
  ga tegilmaydi**, ya'ni mavjud bizneslarning booking oqimi o'zgarmaydi; maydon
  yuborilmasa xatti-harakat avvalgidek qoladi (backward-compatible).
- `apps/admin/src/views/BookingSettings.vue` — "Biznes ma'lumotlari" kartasida
  "Biznes turi" tanlovi (faqat sub-kategoriyasi bor vertikallarda ko'rinadi).
  Saqlagandan keyin `auth.fetchMe()` chaqiriladi — sidebar badge darhol yangilanadi.

**Tekshiruv.** `PUT {"category":"salon"}` → javobda `category: salon`, bazada `engine`
o'zgarmagan (`slot`).

### 4. "Ombor" barber menyusidan olib tashlandi (UX / vertikal moslash)

**Muammo.** Sartaroshxonada ombor moduli ishlatilmaydi — menyuda turgan bo'sh
"0 / 0 / 0 so'm" sahifa mahsulot tugallanmagandek taassurot qoldiradi.

**Qaror.** Kod o'chirilmadi, faqat `slot` engine uchun nav elementi yashirildi.
Sabab: `barber` vertikali go'zallik salonini ham qamraydi, u yerda ombor (bo'yoq,
kosmetika, sotuv) kerak. Kelajakda biznes sozlamalarida "Ombor moduli" tugmasi
bo'ladi — salon yoqadi, sartaroshxonada o'chiq turadi.

**O'zgarish.** `apps/admin/src/components/AppLayout.vue` — Katalog guruhidagi
`/ombor` elementi faqat `engine !== 'slot'` bo'lganda qo'shiladi. Route va sahifa
joyida: `/app/ombor` to'g'ridan-to'g'ri ochiladi. Boshqa vertikallarga (cafe →
`catalog`, medical) ta'sir yo'q.

### 1. Ish jadvali saqlanmayotgan edi — API shartnomasi mos emasdi (bug)

**Muammo.** Admin → *Ish jadvali* da kunlarni belgilab "Saqlash" bosilganda hech nima
saqlanmasdi: xato ko'rinmasdi, log toza, bazada esa qator yo'q edi. Natijada public
booking saytida hamma sanaga "Bu kunga bo'sh vaqt yo'q" chiqardi.

**Sabab.** Frontend backend kutgan formatdan boshqa format yuborardi:

| | Frontend yuborardi | Backend kutadi |
|---|---|---|
| Ro'yxat kaliti | `days` | `items` |
| Vaqt maydonlari | `start` / `end` | `start_time` / `end_time` |
| Yakshanba raqami | `0` | `7` (ISO-8601) |

`ScheduleController::extractItems()` `items` topolmay bo'sh massiv qaytarardi. Keyingi
kod esa avval **xodimning butun jadvalini o'chirib**, so'ng bo'sh ro'yxatni yozardi va
**200 OK** qaytarardi — shuning uchun UI "saqlandi" deb ko'rsatardi. Ya'ni har bosishda
mavjud jadval ham yo'q qilinardi.

**Yechim.** `apps/admin/src/views/Schedule.vue` — to'g'ri `items` payload'i,
`start_time`/`end_time` (`HH:MM:00`), yakshanba `7`, faqat yoqilgan kunlar yuboriladi.
Backend'ga tegilmadi (u o'z shartnomasiga muvofiq ishlayotgan edi).

**Tekshiruv.** `PUT /v1/staff/1/working-hours` → 6 qator bazaga yozildi.

### 2. Ish jadvaliga "Barcha kunlar" tugmasi (UX)

Har kunni alohida belgilash o'rniga:
- **Barcha kunlar** — bitta checkbox bilan hammasini yoqish/o'chirish (qisman
  belgilangan holatda `indeterminate` ko'rinadi).
- **Vaqtni hammasiga qo'llash** — birinchi yoqilgan kunning soatlarini qolgan
  yoqilgan kunlarga nusxalaydi.

Fayl: `apps/admin/src/views/Schedule.vue`.

### 3. Mini-kalendarda kun raqami markazda emasdi (UI)

**Sabab.** `{{ d.day }}` shablonda alohida qatorda turgani uchun tugma ichida raqam
oldi/ortida bo'sh joy (whitespace) matn tugunlari qolgan — raqam markazdan siljigan.
Bundan tashqari brauzerning `<button>` uchun standart `padding: 1px 6px` i qolgan edi.

**Yechim.** `apps/admin/src/components/MiniCalendar.vue` — interpolyatsiya bo'sh joysiz
(`>{{ d.day }}</button>`), `padding: 0`, `line-height: 1`, `display: grid` o'rniga aniq
`flex` + `align-items/justify-content: center` (Safari ba'zi versiyalarda `<button>` da
`display: grid` ni e'tiborsiz qoldiradi).

---

## Aniqlangan, lekin hali tuzatilmagan

- **Xodimlar sahifasi `staff` roliga ham "Yangi xodim" tugmasini ko'rsatadi** —
  bosilganda faqat 403 (`Insufficient role for this action`) chiqadi. `Team.vue` dagidek
  `auth.role` bo'yicha yashirish kerak. Fayl: `apps/admin/src/views/Staff.vue`.
- **API xato matnlari inglizcha** (`Insufficient role for this action`), UI esa o'zbekcha.

---

## Lokal ishga tushirish (dev eslatma)

Bu qismlar kodga emas, muhitga tegishli — README dagi buyruqlarga qo'shimcha:

- `ROOT_DOMAIN=lvh.me` — `*.lvh.me` 127.0.0.1 ga ishora qiladi, `/etc/hosts` shart emas.
- `PUBLIC_BASE=http://127.0.0.1:8082` — bo'lmasa admin'dagi "Saytni ochish" havolasi
  prod formulasi bilan (`https://{slug}.tizbiz.uz`) yasaladi va localda ochilmaydi.
  Booking SPA `?slug=` fallback'ini qo'llab-quvvatlaydi.
- SPA tierlar (`frontend`/`backend`/`tenant`) PHP built-in server uchun history-fallback
  router talab qiladi; repoda faqat `api/web/router.php` bor.
- `corepack pnpm` bu mashinada imzo tekshiruvida yiqiladi — global `pnpm` ishlatiladi.
- Portlar: API `8899`, corporate `8080`, admin `8081`, tenant `8082`.
