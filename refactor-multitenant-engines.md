# TizBiz — Multi-tenant + Modul dvigatel refaktoringi

> **Bu fayl Claude Code uchun.** Maqsad: mavjud ishlayotgan tizimni (Vue SPA + Yii2) **buzmasdan**, bosqichma-bosqich multi-tenant va modul-dvigatel arxitekturasiga o'tkazish.

---

## 0. OLTIN QOIDALAR (har bosqichda amal qil)

1. **Hech narsani o'chirma, faqat qo'sh (additive).** Eski kod ishlab tursin. Yangi qatlam eski ustiga qo'shiladi, eskisini almashtirmaydi — toki yangi qatlam to'liq sinovdan o'tmaguncha.
2. **Har bosqich orqaga qaytariladigan (reversible) bo'lsin.** Bitta bosqich = bitta branch = bitta PR.
3. **Har bosqichdan keyin mavjud funksiyani sinab ko'r.** Ishlab turган narsa hali ham ishlayaptimi? Ha bo'lsa — keyingi bosqich.
4. **DB o'zgarishlari: avval `NULL` bo'ladigan ustun qo'sh → data to'ldir (backfill) → keyingina majburiy (NOT NULL) qil.** Hech qachon to'g'ridan-to'g'ri NOT NULL qo'shma.
5. **Yangi xatti-harakatni feature-flag ortiga qo'y.** Flag o'chiq bo'lsa — eski oqim ishlaydi.
6. **Bir bosqichni to'liq tugatmasdan keyingisiga o'tma.** Hammasini birdan qilma.
7. **Hech qachon:** kodni kopiya qilma, har biznesga alohida DB yaratma, umumiy jadvalni o'chirma.

---

## 1. AVVAL O'RGAN (kod yozishdan oldin)

Refaktoringni boshlashdan oldin mavjud tizimni tushun. Quyidagilarni aniqla va menga (yoki jamoaga) qisqa hisobot ber:

- Yii2 tuzilishi: advanced yoki basic template? Modullar bormi? Qaysi papkalarда model/controller?
- Mavjud DB jadvallari ro'yxati — qaysilarida biznesga bog'liq data bor?
- Hozir biznes (tenant) tushunchasi qanday? `business`/`company`/`shop` jadvali bormi? Auth qanday (JWT?)?
- Mavjud dvigatel (ishlab turgani) qaysi kod/jadvallarда? U qaysi soha (tort? barber?)?
- Frontend: nechta Vue ilova? Routing qanday? API base URL qayerdan olinadi?
- Subdomen hozir ishlatiladi mi, yo'qmi?

**Bu bosqichда hech narsa o'zgartirma — faqat o'qi va tushun.** Aniqlagach, quyidagi bosqichlarni mavjud kodga moslab bajar.

---

## 2. MAQSADLI ARXITEKTURA (qisqacha)

- **Bitta kod bazasi, bitta MySQL baza.** Har jadvalda `business_id` (tenant) ustuni.
- **Subdomen:** `*.tizbiz.uz` (wildcard) → bitta backend. `dash.tizbiz.uz` = admin panel, `{slug}.tizbiz.uz` = biznesning public sahifasi.
- **Dvigatel = kod ichidagi modul**, biznesning `engine` (yoki `business_type`) maydoni bo'yicha tanlanadi (strategy pattern).
- **Yangilanish 1 marta** → hamma biznesga tegadi. Hech qachon per-biznes kod tahriri yo'q.

---

## 3. BOSQICHLI REJA (ketma-ket, har biri alohida PR)

### Bosqich 1 — Tenant ustunini qo'shish (additive, NULL)

**Maqsad:** har biznesga bog'liq jadvalga `business_id` qo'shish, mavjud query'larni buzmasdan.

- Agar `businesses` (yoki ekvivalent tenant) jadvali yo'q bo'lsa — yarat: `id, name, slug (unique), engine, status, created_at`. Slug = subdomen (`aziza`).
- Har biznesga bog'liq jadvalga **`business_id INT NULL`** ustun qo'sh (migratsiya). NULL bo'lgani uchun mavjud kod buzilmaydi.
- Mavjud datani backfill qil: agar hozir bitta biznes bo'lsa (masalan Aziza), hamma qatorga o'shaning `business_id`sini yoz.
- Index qo'sh: `business_id` ustuniga.

**Tekshiruv:** mavjud ilova hali ham avvalgidek ishlayaptimi? (business_id NULL yoki to'ldirilgan — query'lar hali filtrlanmaydi). Ha → keyingi bosqich.

```
// migration namunasi (Yii2)
$this->addColumn('{{%orders}}', 'business_id', $this->integer()->null()->after('id'));
$this->createIndex('idx-orders-business', '{{%orders}}', 'business_id');
// backfill (agar bitta biznes bo'lsa):
$this->execute("UPDATE {{%orders}} SET business_id = 1 WHERE business_id IS NULL");
```

### Bosqich 2 — Tenant komponenti + resolver (subdomen)

**Maqsad:** har so'rovda "hozir qaysi biznes?" ni aniqlash.

- Yii2 application komponenti yarat: `Yii::$app->tenant` — joriy `business_id`ni saqlaydi.
- Resolver: so'rov kelганда aniqla:
  - **Public sahifa (`{slug}.tizbiz.uz`):** `Host` header'dan slug → `businesses` dan `business_id`.
  - **Admin (`dash.tizbiz.uz`):** JWT/login'дan foydalanuvchining `business_id`si.
- Resolverни bootstrap yoki controller behavior sifatida ulа. **Muhim:** tenant aniqlanmasa (masalan eski endpoint, console, superadmin) — `tenant->id = null` qoladi, xato bermaydi.

**Tekshiruv:** subdomen bilan kirilganда to'g'ri `business_id` aniqlanadimi? Eski endpointlar (tenant kerak bo'lmagan) hali ishlayaptimi?

```php
// components/Tenant.php
class Tenant extends \yii\base\Component {
    public ?int $id = null;
    public ?Business $business = null;
    public function setBySlug(string $slug): void {
        $b = Business::findOne(['slug' => $slug, 'status' => 'active']);
        if ($b) { $this->id = $b->id; $this->business = $b; }
    }
}
// resolver (bootstrap yoki behavior) — Host'dan slug ajratib setBySlug chaqiradi
```

### Bosqich 3 — TenantActiveRecord (backward-compatible global scope)

**Maqsad:** query'larni avtomatik `business_id` bo'yicha filtrlash — lekin eski kodni buzmasdan.

- Bazaviy klass yarat: `TenantActiveRecord extends ActiveRecord`.
- `find()` da: **agar `tenant->id` mavjud bo'lsa va jadvalda `business_id` ustuni bo'lsa** — filtr qo'sh. Aks holda — filtrsiz (eski xatti-harakat).
- `beforeSave` da: insert'да `business_id` bo'sh bo'lsa — `tenant->id`ни avtomatik yoz.
- **Modellarni birma-bir** shu klassdan meros oldirib chiq (hammasini birdan emas). Har o'tkazishdan keyin sinab ko'r.

**Nega buzilmaydi:** filtr faqat `tenant->id !== null` bo'lganда qo'llanadi. Eski, tenant o'rnatilmagan kontekstда — avvalgidek ishlaydi.

```php
class TenantActiveRecord extends \yii\db\ActiveRecord {
    public static function find() {
        $q = parent::find();
        $tid = Yii::$app->tenant->id ?? null;
        if ($tid !== null && static::getTableSchema()->getColumn('business_id')) {
            $q->andWhere([static::tableName() . '.business_id' => $tid]);
        }
        return $q;
    }
    public function beforeSave($insert) {
        if ($insert && $this->hasAttribute('business_id') && empty($this->business_id)
            && (Yii::$app->tenant->id ?? null) !== null) {
            $this->business_id = Yii::$app->tenant->id;
        }
        return parent::beforeSave($insert);
    }
}
```

### Bosqich 4 — Dvigatel abstraksiyasi (EngineInterface + Factory)

**Maqsad:** dvigatelni almashtiriladigan modul qilish, mavjud dvigatelni buzmasdan.

- `businesses` jadvaliga `engine VARCHAR` qo'sh (agar yo'q bo'lsa). Mavjud bizneslarga joriy dvigatel qiymatini yoz (masalan `'catalog'`).
- `EngineInterface` yarat — umumiy shartnoma (metod ro'yxati). Bu **bir marta** yoziladi, keyin o'zgarmaydi.
- `EngineFactory` yarat — `engine` qiymatini klassga bog'laydi.
- **Mavjud dvigatel kodini shu interfeysga o'rab** (wrap) chiq: yangi `CatalogEngine implements EngineInterface` klassi ichida mavjud logikани chaqir. Kodni ko'chirma — o'rab ol.

**Tekshiruv:** mavjud dvigatel endi `EngineFactory::make($business)` orqali chaqirilganда ham avvalgidek ishlaydimi?

```php
interface EngineInterface {
    public function publicData(Business $b): array;      // {slug}.tizbiz.uz uchun
    public function services(Business $b): array;
    public function createTransaction(Business $b, array $data): Model; // buyurtma/booking
    // kerakli metodlarni jamoa kelishib qo'shadi — keyin o'zgartirmang
}

class EngineFactory {
    private const MAP = [
        'catalog' => \app\modules\engineCatalog\CatalogEngine::class,
        'slot'    => \app\modules\engineSlot\SlotEngine::class,
        'rental'  => \app\modules\engineRental\RentalEngine::class,
        'medical' => \app\modules\engineMedical\MedicalEngine::class,
    ];
    public static function make(Business $b): EngineInterface {
        $cls = self::MAP[$b->engine] ?? throw new \InvalidArgumentException("Noma'lum engine: {$b->engine}");
        return Yii::createObject($cls);
    }
}
```

### Bosqich 5 — Mavjud dvigatelni modulga ko'chirish

**Maqsad:** har dvigatel alohida papka — parallel ishlash uchun (konfliktsiz).

- Yii2 modul yarat: `/modules/engine-catalog`, `/modules/engine-slot`, va h.k.
- Mavjud dvigatel kodini **o'z moduliga** ko'chir (masalan tort → `engine-catalog`). Yadro (auth, tenant, CRM, to'lov) → `/modules/core`.
- Har modul o'z route'ini o'zi ro'yxatga oladi (module bootstrap) — umumiy route fayliga qo'lda yozma.
- Har dvigatel o'z jadvallarini **o'z prefiksi** bilan yaratadi: `catalog_orders`, `slot_appointments`, `rental_items`, `medical_visits`. Boshqa dvigatel jadvaliga tegmaydi.

**Tekshiruv:** ko'chirilgan dvigatel yangi joyidan ishlayaptimi?

### Bosqich 6 — Subdomen routing (dash + wildcard)

- **Wildcard DNS:** `*.tizbiz.uz` → server. Cloudflare'da bitta wildcard A/CNAME + wildcard SSL. Yangi biznesда DNS'ga tegilmaydi.
- Frontend: `dash.tizbiz.uz` = admin SPA (login → o'z biznesi). `{slug}.tizbiz.uz` = public SPA (subdomendan slug → API → render).
- Public SPA `business_type`/`engine`ga qarab boshqa layout render qiladi (`/src/engines/{type}`).

### Bosqich 7 — Feature-flag'lar

- Har yangi dvigatel/funksiyani flag ortiga qo'y (`config` yoki `businesses.features` json).
- Flag o'chiq → eski oqim. Bu bosqichma-bosqich yoyish va tez orqaga qaytarish imkonini beradi.

---

## 4. PAPKA TUZILISHI (maqsad)

```
backend/
  modules/
    core/            ← auth, tenant, CRM, loyallik, to'lov (BARQAROR — ehtiyot bilan)
    engine-catalog/  ← tort/food        (Sen)
    engine-slot/     ← barber/salon     (Jalol)
    engine-rental/   ← kelin ko'ylak    (Eldor)
    engine-medical/  ← klinika/UZI      (Hakimbek)
  components/
    Tenant.php
    TenantActiveRecord.php
    EngineFactory.php
  common/
    EngineInterface.php   ← BARQAROR shartnoma

frontend/ (apps/)
  dash/     ← admin SPA (dash.tizbiz.uz)
  public/   ← {slug}.tizbiz.uz
    src/engines/
      catalog/  slot/  rental/  medical/
```

**Qoida:** har kim faqat o'z dvigateli papkasida ishlaydi. `core/` va `EngineInterface.php`ga tegish — faqat jamoa kelishuvi / tex-lead orqali.

---

## 5. MIGRATSIYA QOIDALARI

- **Additive + nullable → backfill → (keyin) NOT NULL.** Hech qachon to'g'ridan-to'g'ri NOT NULL/DROP qilma.
- Har dvigatel jadvali **o'z prefiksi** bilan (`slot_`, `catalog_`, ...). Umumiy jadval (`businesses`, `clients`, `users`) faqat `core`da, ularga ustun qo'shish = tex-lead orqali.
- Har migratsiya `up()` va `down()` bilan (orqaga qaytariladigan).
- Migratsiya fayl nomiga Yii2 avtomatik timestamp qo'yadi — to'qnashuv kam.

---

## 6. GIT JARAYONI (4 kishi, konfliktsiz)

- **Branchlar:** `main` (himoyalangan, faqat merge) · `dev` (integratsiya) · `feat/{engine}-{narsa}` (har kishi o'zi).
- **Kunlik ritm:** ertalab `git pull origin dev` → o'z branchingда ishla → kichik commit → funksiya tugaganда PR → `dev`ga.
- **Kichik, tez-tez PR.** Katta PR = konflikt do'zaxi.
- **Umumiy faylga (`core`, `EngineInterface`, routing) tegsang — jamoaga ayt.**
- `.gitignore`: `.env`, `vendor/`, `node_modules/`, IDE fayllari.
- Konflikt asosan umumiy fayllardagina bo'ladi — arxitektura (alohida modul/papka) buni ~90% kamaytiradi.

---

## 7. HAR BOSQICHDA TEKSHIRISH (checklist)

Har bosqichdan keyin:
- [ ] Mavjud (ishlab turган) funksiya hali ham ishlayaptimi?
- [ ] Yangi qatlam eski datani buzmadimi? (backfill to'g'rimi?)
- [ ] Bir biznes boshqasining datasini ko'rmayaptimi? (tenant izolyatsiya)
- [ ] Migratsiya `down()` bilan orqaga qaytadimi?
- [ ] Feature-flag o'chiq holatda eski oqim ishlayaptimi?

Bittasi "yo'q" bo'lsa — keyingi bosqichga o'tma, avval tuzat.

---

## 8. CLAUDE CODE UCHUN ISHLASH TARTIBI

1. **Avval 1-bo'lim (O'rgan)ni bajar** — mavjud kodni inventarizatsiya qil, hisobot ber. Hech narsa o'zgartirma.
2. **Bosqichlarni BITTA-BITTA bajar.** Har bosqich = alohida branch + PR. Bir bosqichni tugatmasdan keyingisiga o'tma.
3. Har o'zgarishdan oldin: **nima o'zgartirayotganingni va nega buzmasligini** qisqa tushuntir.
4. **Hech narsani o'chirma** — additive ishla. Eski kod flag/parallel holida qolsin.
5. Har bosqichdan keyin 7-bo'lim checklistini yugurt.
6. Ikkilanсang — to'xtab so'ra, taxmin qilib buzma.
```
