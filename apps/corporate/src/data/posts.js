// Marketing blog content. Static data — no API. Each post's `body` is an array
// of typed blocks rendered by BlogPost.vue: {type:'p'|'h2'|'quote'|'list'}.
// `cover` is a CSS gradient string used as the article/card cover background.

export const posts = [
  {
    slug: 'no-show-ni-qanday-toxtatish',
    title: 'No-show’ni qanday to‘xtatish mumkin',
    date: '2026-07-10',
    category: 'Booking',
    excerpt:
      'Kelmay qolgan mijoz — bu bo‘sh qolgan navbat va yo‘qotilgan pul. Oldindan to‘lov va aqlli eslatmalar bilan no-show’ni qanday kamaytirish mumkinligini ko‘rib chiqamiz.',
    cover: 'linear-gradient(135deg, #4d82ff, #7aa2ff)',
    body: [
      {
        type: 'p',
        text: 'Har bir kelmay qolgan mijoz — bu shunchaki bo‘sh vaqt emas. Usta bo‘sh o‘tiradi, o‘sha vaqtga boshqa mijozni yozib bo‘lmaydi va kunlik daromad tushadi. Surxondaryodagi ko‘pchilik barber va salonlar uchun no-show haftalik bir necha yuz ming so‘m yo‘qotish demakdir.',
      },
      { type: 'h2', text: 'Nega mijozlar kelmay qoladi' },
      {
        type: 'p',
        text: 'Aksariyat holatlarda yovuz niyat yo‘q — mijoz shunchaki unutadi yoki “bepul yozildim, kelmasam ham hech narsa yo‘qotmayman” deb o‘ylaydi. Muammo ikkita: eslatma yo‘q va majburiyat yo‘q.',
      },
      { type: 'h2', text: 'Yechim 1 — oldindan to‘lov (depozit)' },
      {
        type: 'p',
        text: 'Kichik depozit — masalan 20 000 so‘m — mijozda majburiyat hissini uyg‘otadi. Payme yoki Click orqali to‘langan pul xizmat narxidan chegiriladi. Kelmasa esa depozit biznesda qoladi. Bu psixologik “tayanch” no-show’ni sezilarli kamaytiradi.',
      },
      {
        type: 'quote',
        text: 'Depozit — jazo emas, majburiyat. Mijoz pulini qo‘ygach, o‘sha vaqtga jiddiy qaraydi.',
      },
      { type: 'h2', text: 'Yechim 2 — avtomatik eslatmalar' },
      {
        type: 'p',
        text: 'Navbatdan bir kun oldin va bir necha soat oldin Telegram va SMS orqali eslatma boradi. Mijoz bir tugma bilan tasdiqlaydi yoki bekor qiladi — bo‘shagan vaqtni esa boshqa mijozga taklif qilish mumkin.',
      },
      {
        type: 'list',
        items: [
          'Yozilgach — darhol tasdiq xabari',
          'Bir kun oldin — eslatma',
          '2 soat oldin — yakuniy eslatma + tasdiqlash tugmasi',
          'Bekor qilinsa — vaqt avtomatik bo‘shaydi',
        ],
      },
      { type: 'h2', text: 'Natija' },
      {
        type: 'p',
        text: 'Depozit va eslatmalarni birga qo‘llagan bizneslar no-show’ni ko‘p hollarda ikki-uch barobar kamaytiradi. TizBiz’da bularning hammasi qutida — alohida sozlash shart emas, yoqib qo‘yasiz va ishlaydi.',
      },
    ],
  },
  {
    slug: 'nega-har-bir-biznesga-onlayn-tizbiz-kerak',
    title: 'Nega har bir bizneosga onlayn navbat kerak',
    date: '2026-07-04',
    category: 'Strategiya',
    excerpt:
      'Telefon orqali yozuv — vaqt yo‘qotish va tartibsizlik. Onlayn navbat biznesga tartib, mijozga esa qulaylik beradi. Farqni tushuntiramiz.',
    cover: 'linear-gradient(135deg, #7a5cff, #b18cff)',
    body: [
      {
        type: 'p',
        text: 'Ko‘pchilik mahalliy biznes hali ham yozuvni qog‘oz daftar yoki telefon qo‘ng‘irog‘i orqali yuritadi. Bu ish qizg‘in paytda muammoga aylanadi: usta band, telefon jiringlaydi, mijoz javob kutadi va oxiri boshqa joyga ketadi.',
      },
      { type: 'h2', text: 'Qog‘oz daftarning muammosi' },
      {
        type: 'list',
        items: [
          'Ikki mijoz bir vaqtga yozib qo‘yiladi',
          'Ish vaqtidan tashqarida hech kim yoza olmaydi',
          'Mijoz tarixi va statistikasi yo‘qoladi',
          'Kim keldi, kim kelmadi — hisob yo‘q',
        ],
      },
      { type: 'h2', text: 'Onlayn navbat nima o‘zgartiradi' },
      {
        type: 'p',
        text: 'Mijoz kechasi soat 12 da ham telefonidan xizmat, usta va bo‘sh vaqtni ko‘rib, o‘zi yoziladi. Biznes esa qo‘ng‘iroqqa javob berish o‘rniga ishini qiladi. Barcha yozuvlar bitta joyda — chalkashlik yo‘q.',
      },
      {
        type: 'quote',
        text: 'Mijoz sizga qulay bo‘lgan vaqtda emas, o‘ziga qulay bo‘lgan vaqtda yoziladi. Onlayn navbat aynan shuni beradi.',
      },
      { type: 'h2', text: 'Bu faqat yiriklar uchun emas' },
      {
        type: 'p',
        text: 'Yakka ishlaydigan usta uchun ham onlayn navbat foydali: u ishlagan paytida telefon ko‘tarmaydi, lekin yozuvlar to‘xtamaydi. TizBiz’da hatto bepul tarifda ham brendlangan sayt va bot beriladi — boshlash uchun hech narsa to‘lash shart emas.',
      },
    ],
  },
  {
    slug: 'telegram-bot-orqali-mijoz-yozuvi',
    title: 'Telegram bot orqali mijoz yozuvi',
    date: '2026-06-27',
    category: 'Telegram',
    excerpt:
      'O‘zbekistonda deyarli hamma Telegram’da. Shuning uchun eng qulay booking — ilova o‘rnatmasdan, to‘g‘ridan-to‘g‘ri Telegram’dagi booking. Qanday ishlashini ko‘ramiz.',
    cover: 'linear-gradient(135deg, #229ed9, #57c1eb)',
    body: [
      {
        type: 'p',
        text: 'Yangi ilova o‘rnatish — mijoz uchun to‘siq. Ko‘pchilik “yana bir ilovami?” deb yozilishdan voz kechadi. Lekin Telegram allaqachon hamma telefonida bor. Shuning uchun eng past to‘siqli booking — aynan Telegram ichida bo‘lgani.',
      },
      { type: 'h2', text: 'Mijoz nuqtai nazaridan' },
      {
        type: 'list',
        items: [
          'Botni ochadi yoki brendlangan havolani bosadi',
          'Xizmatni tanlaydi (masalan, soch olish + soqol)',
          'Ustani va bo‘sh vaqtni tanlaydi',
          'Kerak bo‘lsa Payme/Click orqali depozit qoldiradi',
          'Tasdiq va eslatmalar o‘sha Telegram’ga keladi',
        ],
      },
      { type: 'h2', text: 'Biznes nuqtai nazaridan' },
      {
        type: 'p',
        text: 'Bot biznesga tegishli — sizning nomingiz, logotipingiz va xizmatlaringiz bilan. Har bir yozilgan mijoz avtomatik bazaga tushadi. Siz botni qo‘lda sozlamaysiz: TizBiz uni biznesingiz ma’lumotidan generatsiya qiladi.',
      },
      {
        type: 'quote',
        text: 'Mijoz hech narsa o‘rnatmaydi. U allaqachon ochiq turgan Telegram’da bir necha tugma bilan navbat oladi.',
      },
      {
        type: 'p',
        text: 'Kelajakda shu botning ustiga AI-seller qo‘shiladi — mijoz savol bersa, bot biznes ma’lumotidan javob berib, to‘g‘ridan-to‘g‘ri yozuvga olib boradi. Lekin bu keyingi bosqich; avval oddiy, ishonchli booking.',
      },
    ],
  },
  {
    slug: 'cashback-loyallik-mijozni-qaytaruvchi-mexanizm',
    title: 'Cashback loyallik: mijozni qaytaruvchi mexanizm',
    date: '2026-06-19',
    category: 'Loyallik',
    excerpt:
      'Yangi mijoz topish qimmat. Bor mijozni qaytarish arzon. Cashback va loyallik biznesingizga takroriy daromad qanday olib kelishini tushuntiramiz.',
    cover: 'linear-gradient(135deg, #12b886, #63e6be)',
    body: [
      {
        type: 'p',
        text: 'Marketing haqidagi eng muhim haqiqat: yangi mijoz jalb qilish, bor mijozni qaytarishdan bir necha barobar qimmatga tushadi. Shunga qaramay ko‘p biznes butun kuchini reklama va yangi mijozga sarflaydi, borini esa unutadi.',
      },
      { type: 'h2', text: 'Cashback qanday ishlaydi' },
      {
        type: 'p',
        text: 'Mijoz xizmatdan foydalanganda hisobiga kichik ulush — masalan 5% — cashback tushadi. Keyingi kelganda shu balansdan chegirma sifatida foydalanadi. Bu mijozga “yana kelsam foydam bor” degan aniq sabab beradi.',
      },
      {
        type: 'list',
        items: [
          'Har tashrifdan keyin cashback avtomatik hisoblanadi',
          'Balans mijozga Telegram’da ko‘rinadi',
          'Keyingi yozuvda chegirma sifatida ishlatiladi',
          'Referral — do‘stini olib kelsa, ikkalasiga bonus',
        ],
      },
      {
        type: 'quote',
        text: 'Cashback — chegirma emas, qaytishga sabab. Mijoz sizda “yig‘ilgan” puli borligini his qiladi.',
      },
      { type: 'h2', text: 'Ma’lumot — asosiy boylik' },
      {
        type: 'p',
        text: 'Loyallik ishlashi uchun mijozlar bazasi kerak. TizBiz har bir yozuvni bazaga yozadi: kim, qachon, qaysi xizmatga keldi. Shu baza ustida cashback, tug‘ilgan kun tabriklari va “ancha kelmadingiz” tipidagi qaytarish kampaniyalari quriladi.',
      },
      {
        type: 'p',
        text: 'Standart tarifdan boshlab cashback va referral qutida keladi — siz faqat foizni belgilaysiz, qolganini tizim bajaradi.',
      },
    ],
  },
  {
    slug: 'payme-va-click-bilan-oldindan-tolov',
    title: 'Payme va Click bilan oldindan to‘lov',
    date: '2026-06-11',
    category: 'To‘lov',
    excerpt:
      'Oldindan to‘lov faqat no-show’ni to‘xtatmaydi — u pul oqimini ham yaxshilaydi. Payme va Click integratsiyasi qanday ishlashini ko‘rib chiqamiz.',
    cover: 'linear-gradient(135deg, #f76707, #ffa94d)',
    body: [
      {
        type: 'p',
        text: 'O‘zbekistonda Payme va Click — deyarli har bir odam foydalanadigan to‘lov tizimlari. TizBiz ikkalasini ham qo‘llab-quvvatlaydi, shuning uchun mijoz o‘ziga qulayini tanlaydi va yozilish jarayonini tark etmasdan to‘laydi.',
      },
      { type: 'h2', text: 'Nega oldindan to‘lov' },
      {
        type: 'list',
        items: [
          'No-show kamayadi — pul qo‘ygan mijoz keladi',
          'Pul oqimi barqarorlashadi — daromad xizmatdan oldin tushadi',
          'Jiddiy mijozlar ajraladi — “shunchaki qiziqib” yozganlar emas',
          'Kassa hisobi soddalashadi — hamma to‘lov tizimda ko‘rinadi',
        ],
      },
      { type: 'h2', text: 'Depozit yoki to‘liq to‘lov' },
      {
        type: 'p',
        text: 'Biznes o‘zi tanlaydi: to‘liq summani oldindan olishmi yoki faqat kichik depozitmi. Barber uchun 20 000 so‘m depozit yetarli bo‘lsa, kelin ko‘ylak saloni uchun to‘liqroq oldindan to‘lov mantiqiyroq. TizBiz ikkala rejimni ham qo‘llaydi.',
      },
      {
        type: 'quote',
        text: 'Oldindan to‘lov — ishonch belgisi. Mijoz jiddiy, biznes esa vaqtini bekorga sarflamaydi.',
      },
      { type: 'h2', text: 'Float — platforma ustamasi' },
      {
        type: 'p',
        text: 'Har bir oldindan to‘lov ustidan kichik platforma ustamasi (float) olinadi. Bu shaffof va oldindan ma’lum — yashirin komissiya yo‘q. Booking bizneslari uchun asosiy model esa baribir obuna bo‘lib qoladi, komissiya emas.',
      },
    ],
  },
  {
    slug: 'stomatologiya-klinikasi-uchun-onlayn-booking',
    title: 'Stomatologiya klinikasi uchun onlayn booking',
    date: '2026-06-03',
    category: 'Klinika',
    excerpt:
      'Klinikada bir nechta shifokor, registratura va murakkab jadval bo‘ladi. Onlayn booking bu tartibsizlikni qanday boshqarilishi mumkin ekanini ko‘ramiz.',
    cover: 'linear-gradient(135deg, #e64980, #faa2c1)',
    body: [
      {
        type: 'p',
        text: 'Stomatologiya va boshqa klinikalarda navbat oddiy barbershopga qaraganda murakkabroq: bir nechta shifokor, turli xil muolajalar, har xil davomiylik va registratura. Qog‘oz jadval bu yerda tez chalkashib ketadi.',
      },
      { type: 'h2', text: 'Ko‘p shifokorli jadval' },
      {
        type: 'p',
        text: 'Har bir shifokorning o‘z jadvali, ish vaqti va dam olish kunlari bor. Mijoz muolaja turini tanlaydi, tizim esa faqat mos shifokorning haqiqatan bo‘sh vaqtlarini ko‘rsatadi. Ikki mijoz bir vaqtga tushib qolishi mumkin emas.',
      },
      { type: 'h2', text: 'Rollar va ruxsatlar' },
      {
        type: 'list',
        items: [
          'Registratura — yozuvlarni ko‘radi va boshqaradi',
          'Shifokor — faqat o‘z bemorlari va jadvalini ko‘radi',
          'Klinika egasi — umumiy hisobot va statistika',
          'Bemor — o‘z yozuvi va tashrif tarixi',
        ],
      },
      {
        type: 'quote',
        text: 'Klinikada tartib — bu ishonch. Bemor o‘z vaqtida qabul qilinsa, u qaytadi va boshqalarga tavsiya qiladi.',
      },
      { type: 'h2', text: 'Eslatma va qayta tashrif' },
      {
        type: 'p',
        text: 'Ko‘p muolajalar bir necha bosqichdan iborat. TizBiz keyingi tashrifni eslatib turadi va bemor o‘z vaqtida qaytadi — davolash uzilib qolmaydi. Klinika tarifi cheksiz shifokor va filialni, kengaytirilgan rollarni va prioritet qo‘llab-quvvatlashni o‘z ichiga oladi.',
      },
    ],
  },
]

export function getPost(slug) {
  return posts.find((p) => p.slug === slug) || null
}

export function formatDate(iso) {
  const months = [
    'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
    'iyul', 'avgust', 'sentyabr', 'oktyabr', 'noyabr', 'dekabr',
  ]
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  return `${d.getDate()}-${months[d.getMonth()]}, ${d.getFullYear()}`
}
