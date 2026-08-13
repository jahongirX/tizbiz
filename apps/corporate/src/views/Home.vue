<script setup>
import { RouterLink } from 'vue-router'
import { posts, formatDate } from '../data/posts'

const REGISTER_URL = 'https://admin.tizbiz.uz/app/register'

const steps = [
  {
    n: '1',
    title: 'Ro‘yxatdan o‘ting',
    text: 'Biznesingiz nomi, xizmatlari va ish vaqtini kiritasiz.',
  },
  {
    n: '2',
    title: 'Sayt + bot tayyor',
    text: 'Brendlangan mini-sayt, Telegram bot va booking sahifasi generatsiya qilinadi.',
  },
  {
    n: '3',
    title: 'Mijoz onlayn yoziladi',
    text: 'Xizmat, usta va bo‘sh vaqtni tanlab, o‘zi navbat oladi.',
  },
  {
    n: '4',
    title: 'Baza + loyallik o‘sadi',
    text: 'Har mijoz saqlanadi, cashback yig‘iladi, eslatmalar avtomatik boradi.',
  },
]

const features = [
  {
    icon: '🌐',
    title: 'Brendlangan sayt + bot + booking',
    text: 'Sizning nomingiz bilan mini-sayt, Telegram bot va onlayn navbat — hammasi bitta qutida, bir kunda ishga tushadi.',
  },
  {
    icon: '💳',
    title: 'Payme / Click orqali oldindan to‘lov',
    text: 'Mijoz depozit qoldiradi — no-show yo‘q. Bo‘sh qolgan navbatlar va yo‘qotilgan pul kamayadi.',
  },
  {
    icon: '📇',
    title: 'Mijozlar bazasi + cashback loyallik',
    text: 'Har bir mijoz saqlanadi, tarixi ko‘rinadi. Cashback va takliflar bilan ularni qaytarib turing.',
  },
  {
    icon: '✈️',
    title: 'Telegram-native — ilova shart emas',
    text: 'Mijoz hech narsa o‘rnatmaydi. Telegram ochib, xizmatni tanlab, navbat oladi — vaqti kelganda eslatma keladi.',
  },
]

const audiences = [
  { icon: '💈', name: 'Barbershop' },
  { icon: '💇', name: 'Go‘zallik saloni' },
  { icon: '🦷', name: 'Stomatologiya / klinika' },
  { icon: '🎂', name: 'Tort ustaxonasi' },
  { icon: '👰', name: 'Kelin ko‘ylak saloni' },
  { icon: '📚', name: 'Repetitor / o‘quv markaz' },
]

const plans = [
  {
    name: 'Bepul',
    price: '0',
    period: 'so‘m/oy',
    tagline: 'Boshlash uchun',
    highlight: false,
    features: ['Brendlangan mini-sayt', 'Telegram bot', '1 xodim, oyiga 30 navbat', 'Asosiy mijozlar bazasi'],
    cta: 'Bepul boshlash',
  },
  {
    name: 'Start',
    price: '99 000',
    period: 'so‘m/oy',
    tagline: 'Yakka usta uchun',
    highlight: false,
    features: ['Cheksiz navbat', '2 xodimgacha', 'Payme / Click oldindan to‘lov', 'SMS + Telegram eslatma'],
    cta: 'Tanlash',
  },
  {
    name: 'Standart',
    price: '249 000',
    period: 'so‘m/oy',
    tagline: 'O‘sayotgan biznes',
    highlight: true,
    features: ['Start’dagi hammasi', '10 xodimgacha', 'Cashback loyallik + referral', 'Kengaytirilgan CRM va hisobotlar'],
    cta: 'Eng ommabop',
  },
  {
    name: 'Klinika',
    price: '590 000',
    period: 'so‘m/oy',
    tagline: 'Klinika va tarmoqlar',
    highlight: false,
    features: [
      'Standart’dagi hammasi',
      'Cheksiz xodim va filial',
      'Rollar va ruxsatlar (registratura, shifokor)',
      'Prioritet qo‘llab-quvvatlash',
    ],
    cta: 'Bog‘lanish',
  },
]

const latestPosts = posts.slice(0, 3)
</script>

<template>
  <main>
    <!-- HERO -->
    <section class="hero">
      <div class="container hero__inner">
        <span class="eyebrow">Surxondaryo xizmat bizneslari uchun</span>
        <h1>
          Biznesingiz uchun onlayn navbat, brendlangan sayt va CRM —
          <span class="grad">Telegram’da</span>
        </h1>
        <p class="hero__sub">
          Sayti yo‘qmi? Muammo emas. TizBiz sizga brendlangan mini-sayt, Telegram bot va
          booking’ni qutida beradi — oldindan to‘lov bilan no-show’ni to‘xtatadi, mijozlar
          bazasini yig‘adi.
        </p>
        <div class="hero__actions">
          <a class="btn btn-primary btn-lg" :href="REGISTER_URL">Bepul boshlash</a>
          <router-link class="btn btn-ghost btn-lg" to="/how-it-works">Qanday ishlaydi</router-link>
        </div>
        <div class="hero__meta">
          <span>✓ Bir kunda ishga tushadi</span>
          <span>✓ Karta shart emas</span>
          <span>✓ Payme / Click</span>
        </div>

        <div class="hero__card" aria-hidden="true">
          <div class="mock">
            <div class="mock__bar"><span></span><span></span><span></span></div>
            <div class="mock__site">
              <div class="mock__brand">
                <div class="mock__logo">B</div>
                <div>
                  <strong>Baraka Barbershop</strong>
                  <small>Termiz · 09:00–21:00</small>
                </div>
              </div>
              <div class="mock__slots">
                <span>10:00</span>
                <span class="on">11:30</span>
                <span>13:00</span>
                <span>15:30</span>
              </div>
              <div class="mock__pay">Depozit: 20 000 so‘m · Payme</div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- HOW IT WORKS PREVIEW -->
    <section class="section section--soft">
      <div class="container">
        <div class="section-head">
          <span class="eyebrow">Qanday ishlaydi</span>
          <h2>To‘rt qadamda ishga tushadi</h2>
          <p>Ro‘yxatdan booking’gacha — texnik bilim shart emas.</p>
        </div>
        <div class="grid grid--steps">
          <article v-for="s in steps" :key="s.n" class="card step">
            <span class="step__num">{{ s.n }}</span>
            <h3>{{ s.title }}</h3>
            <p>{{ s.text }}</p>
          </article>
        </div>
        <div class="section-more">
          <router-link class="btn btn-ghost" to="/how-it-works">To‘liq jarayonni ko‘rish →</router-link>
        </div>
      </div>
    </section>

    <!-- FEATURES -->
    <section id="features" class="section">
      <div class="container">
        <div class="section-head">
          <span class="eyebrow">Nega TizBiz</span>
          <h2>Mahalliy biznes uchun ishlangan</h2>
          <p>Biz “arzon YClients” emasmiz. Sizda sayt yo‘q edi — biz uni ham qo‘shib beramiz.</p>
        </div>
        <div class="grid grid--features">
          <article v-for="f in features" :key="f.title" class="card feature">
            <div class="feature__icon">{{ f.icon }}</div>
            <h3>{{ f.title }}</h3>
            <p>{{ f.text }}</p>
          </article>
        </div>
      </div>
    </section>

    <!-- AUDIENCE -->
    <section id="audience" class="section section--soft">
      <div class="container">
        <div class="section-head">
          <span class="eyebrow">Kimlar uchun</span>
          <h2>Navbat oladigan har qanday biznesga mos</h2>
          <p>Barber va salondan tortib klinika va repetitorgacha.</p>
        </div>
        <div class="grid grid--audience">
          <div v-for="a in audiences" :key="a.name" class="card audience">
            <span class="audience__icon">{{ a.icon }}</span>
            <span class="audience__name">{{ a.name }}</span>
          </div>
        </div>
      </div>
    </section>

    <!-- PRICING -->
    <section id="pricing" class="section">
      <div class="container">
        <div class="section-head">
          <span class="eyebrow">Narxlar</span>
          <h2>Oddiy obuna, komissiya yo‘q</h2>
          <p>Booking bizneslari uchun obuna. Narxlar taxminiy — biznesingizga qarab moslashtiramiz.</p>
        </div>
        <div class="grid grid--pricing">
          <article
            v-for="p in plans"
            :key="p.name"
            class="card plan"
            :class="{ 'plan--hot': p.highlight }"
          >
            <div v-if="p.highlight" class="plan__badge">Ommabop</div>
            <h3 class="plan__name">{{ p.name }}</h3>
            <p class="plan__tagline">{{ p.tagline }}</p>
            <div class="plan__price">
              <span class="plan__amount">{{ p.price }}</span>
              <span class="plan__period">{{ p.period }}</span>
            </div>
            <p class="plan__note">taxminiy</p>
            <ul class="plan__features">
              <li v-for="feat in p.features" :key="feat">{{ feat }}</li>
            </ul>
            <a class="btn" :class="p.highlight ? 'btn-primary' : 'btn-ghost'" :href="REGISTER_URL">
              {{ p.cta }}
            </a>
          </article>
        </div>
      </div>
    </section>

    <!-- BLOG PREVIEW -->
    <section class="section section--soft">
      <div class="container">
        <div class="section-head">
          <span class="eyebrow">Blog</span>
          <h2>Booking va biznes haqida foydali maqolalar</h2>
          <p>No-show, loyallik, to‘lov va onlayn navbat bo‘yicha amaliy maslahatlar.</p>
        </div>
        <div class="grid grid--posts">
          <router-link
            v-for="post in latestPosts"
            :key="post.slug"
            class="card post-card"
            :to="`/blog/${post.slug}`"
          >
            <div class="post-card__cover" :style="{ background: post.cover }">
              <span class="tag post-card__tag">{{ post.category }}</span>
            </div>
            <div class="post-card__body">
              <h3>{{ post.title }}</h3>
              <p>{{ post.excerpt }}</p>
              <time class="post-card__date" :datetime="post.date">{{ formatDate(post.date) }}</time>
            </div>
          </router-link>
        </div>
        <div class="section-more">
          <router-link class="btn btn-ghost" to="/blog">Barcha maqolalar →</router-link>
        </div>
      </div>
    </section>

    <!-- ABOUT TEASER -->
    <section class="section">
      <div class="container">
        <div class="teaser">
          <div class="teaser__text">
            <span class="eyebrow">Loyiha haqida</span>
            <h2>Bosqichma-bosqich super-app</h2>
            <p>
              TizBiz booking’dan boshlanadi, keyin AI-seller, restoran zakazi, uy-xizmat va
              iste’molchi ilovasiga o‘sadi. Biz hammasini birdan qurmaymiz — avval real
              ishlaydigan booking, keyin keyingisi.
            </p>
            <router-link class="btn btn-ghost" to="/about">Batafsil →</router-link>
          </div>
          <div class="teaser__marks" aria-hidden="true">
            <span>Booking</span>
            <span>AI-seller</span>
            <span>Restoran</span>
            <span>Uy-xizmat</span>
            <span>Iste’molchi app</span>
          </div>
        </div>
      </div>
    </section>

    <!-- FINAL CTA -->
    <section class="section cta">
      <div class="container">
        <div class="cta__box">
          <h2>Bugun brendlangan navbat tizimini oching</h2>
          <p>Ro‘yxatdan o‘ting, xizmatlaringizni kiriting — bir kunda mijozlar onlayn navbat ola boshlaydi.</p>
          <div class="cta__actions">
            <a class="btn btn-primary btn-lg" :href="REGISTER_URL">Bepul boshlash</a>
            <router-link class="btn btn-ghost btn-lg" :to="{ path: '/', hash: '#pricing' }">Narxlarni ko‘rish</router-link>
          </div>
        </div>
      </div>
    </section>
  </main>
</template>

<style scoped>
/* HERO */
.hero {
  position: relative;
  padding: 72px 0 40px;
  overflow: hidden;
}
.hero::before {
  content: '';
  position: absolute;
  top: -220px;
  left: 50%;
  transform: translateX(-50%);
  width: 900px;
  height: 620px;
  background: radial-gradient(closest-side, color-mix(in srgb, var(--accent) 22%, transparent), transparent);
  z-index: 0;
  pointer-events: none;
}
.hero__inner {
  position: relative;
  z-index: 1;
  text-align: center;
  max-width: 820px;
}
.hero h1 {
  font-size: clamp(32px, 6vw, 56px);
  line-height: 1.08;
  letter-spacing: -0.03em;
  margin: 20px 0 18px;
}
.grad {
  background: linear-gradient(90deg, var(--accent), #7aa2ff);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}
.hero__sub {
  font-size: clamp(16px, 2.2vw, 20px);
  color: var(--text-soft);
  margin: 0 auto 28px;
  max-width: 640px;
}
.hero__actions {
  display: flex;
  gap: 12px;
  justify-content: center;
  flex-wrap: wrap;
}
.hero__meta {
  display: flex;
  gap: 20px;
  justify-content: center;
  flex-wrap: wrap;
  margin-top: 22px;
  color: var(--text-soft);
  font-size: 14px;
  font-weight: 500;
}

/* HERO MOCK */
.hero__card {
  margin: 52px auto 0;
  max-width: 460px;
}
.mock {
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 18px;
  box-shadow: var(--shadow);
  overflow: hidden;
  text-align: left;
}
.mock__bar {
  display: flex;
  gap: 7px;
  padding: 13px 16px;
  border-bottom: 1px solid var(--border);
}
.mock__bar span {
  width: 11px;
  height: 11px;
  border-radius: 50%;
  background: var(--border);
}
.mock__site {
  padding: 20px;
}
.mock__brand {
  display: flex;
  align-items: center;
  gap: 12px;
}
.mock__logo {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  background: linear-gradient(135deg, var(--accent), #7aa2ff);
  color: #fff;
  font-weight: 800;
  display: grid;
  place-items: center;
  font-size: 18px;
}
.mock__brand strong {
  display: block;
  font-size: 15px;
}
.mock__brand small {
  color: var(--text-soft);
  font-size: 13px;
}
.mock__slots {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
  margin: 18px 0 14px;
}
.mock__slots span {
  text-align: center;
  padding: 10px 0;
  border-radius: 10px;
  border: 1px solid var(--border);
  font-size: 13px;
  font-weight: 600;
  color: var(--text-soft);
}
.mock__slots span.on {
  background: var(--accent);
  border-color: var(--accent);
  color: #fff;
}
.mock__pay {
  background: var(--bg-soft);
  border-radius: 10px;
  padding: 10px 12px;
  font-size: 13px;
  font-weight: 600;
  color: var(--text-soft);
}

/* STEPS */
.grid--steps {
  grid-template-columns: repeat(4, 1fr);
}
.step__num {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  border-radius: 12px;
  background: var(--accent-soft);
  color: var(--accent);
  font-weight: 800;
  font-size: 18px;
  margin-bottom: 16px;
}
.step h3 {
  font-size: 17px;
  margin: 0 0 8px;
  letter-spacing: -0.01em;
}
.step p {
  margin: 0;
  color: var(--text-soft);
  font-size: 14.5px;
}
.section-more {
  text-align: center;
  margin-top: 32px;
}

/* FEATURES */
.grid--features {
  grid-template-columns: repeat(4, 1fr);
}
.feature__icon {
  font-size: 26px;
  width: 52px;
  height: 52px;
  display: grid;
  place-items: center;
  border-radius: 13px;
  background: var(--accent-soft);
  margin-bottom: 16px;
}
.feature h3 {
  font-size: 17px;
  margin: 0 0 8px;
  letter-spacing: -0.01em;
}
.feature p {
  margin: 0;
  color: var(--text-soft);
  font-size: 14.5px;
}

/* AUDIENCE */
.grid--audience {
  grid-template-columns: repeat(6, 1fr);
}
.audience {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  text-align: center;
  padding: 24px 14px;
}
.audience__icon {
  font-size: 30px;
}
.audience__name {
  font-size: 14px;
  font-weight: 600;
}

/* PRICING */
.grid--pricing {
  grid-template-columns: repeat(4, 1fr);
  align-items: stretch;
}
.plan {
  display: flex;
  flex-direction: column;
  position: relative;
}
.plan--hot {
  border-color: var(--accent);
  box-shadow: var(--shadow);
}
.plan__badge {
  position: absolute;
  top: -12px;
  left: 50%;
  transform: translateX(-50%);
  background: var(--accent);
  color: #fff;
  font-size: 12px;
  font-weight: 700;
  padding: 5px 14px;
  border-radius: 999px;
}
.plan__name {
  font-size: 19px;
  margin: 0 0 4px;
}
.plan__tagline {
  color: var(--text-soft);
  font-size: 14px;
  margin: 0 0 18px;
}
.plan__price {
  display: flex;
  align-items: baseline;
  gap: 6px;
}
.plan__amount {
  font-size: 30px;
  font-weight: 800;
  letter-spacing: -0.02em;
}
.plan__period {
  color: var(--text-soft);
  font-size: 14px;
}
.plan__note {
  color: var(--text-soft);
  font-size: 12px;
  margin: 4px 0 18px;
}
.plan__features {
  list-style: none;
  margin: 0 0 24px;
  padding: 0;
  display: grid;
  gap: 11px;
  flex: 1;
}
.plan__features li {
  position: relative;
  padding-left: 26px;
  font-size: 14.5px;
  color: var(--text-soft);
}
.plan__features li::before {
  content: '✓';
  position: absolute;
  left: 0;
  top: 0;
  color: var(--accent);
  font-weight: 800;
}
.plan .btn {
  width: 100%;
}

/* BLOG PREVIEW CARDS */
.grid--posts {
  grid-template-columns: repeat(3, 1fr);
}
.post-card {
  padding: 0;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  transition: transform 0.15s ease, border-color 0.15s ease, box-shadow 0.15s ease;
}
.post-card:hover {
  transform: translateY(-3px);
  border-color: var(--accent);
  box-shadow: var(--shadow);
}
.post-card__cover {
  position: relative;
  height: 132px;
}
.post-card__tag {
  position: absolute;
  left: 14px;
  bottom: 14px;
  background: rgba(255, 255, 255, 0.9);
  color: #10151c;
}
.post-card__body {
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex: 1;
}
.post-card__body h3 {
  font-size: 17px;
  margin: 0;
  letter-spacing: -0.01em;
}
.post-card__body p {
  margin: 0;
  color: var(--text-soft);
  font-size: 14px;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.post-card__date {
  margin-top: auto;
  color: var(--text-soft);
  font-size: 13px;
  font-weight: 500;
}

/* ABOUT TEASER */
.teaser {
  display: grid;
  grid-template-columns: 1.2fr 1fr;
  gap: 40px;
  align-items: center;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 44px;
}
.teaser__text h2 {
  font-size: clamp(24px, 4vw, 34px);
  letter-spacing: -0.02em;
  margin: 14px 0 12px;
}
.teaser__text p {
  color: var(--text-soft);
  font-size: 16px;
  margin: 0 0 22px;
}
.teaser__marks {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}
.teaser__marks span {
  padding: 10px 16px;
  border-radius: 999px;
  border: 1px solid var(--border);
  background: var(--bg-soft);
  font-size: 14px;
  font-weight: 600;
  color: var(--text-soft);
}
.teaser__marks span:first-child {
  background: var(--accent);
  border-color: var(--accent);
  color: #fff;
}

/* CTA */
.cta__box {
  background: linear-gradient(135deg, var(--accent), #6b93ff);
  color: #fff;
  border-radius: 26px;
  padding: 56px 32px;
  text-align: center;
}
.cta__box h2 {
  font-size: clamp(26px, 4vw, 38px);
  margin: 0 0 12px;
  letter-spacing: -0.02em;
}
.cta__box p {
  margin: 0 auto 26px;
  max-width: 520px;
  font-size: 17px;
  opacity: 0.92;
}
.cta__actions {
  display: flex;
  gap: 12px;
  justify-content: center;
  flex-wrap: wrap;
}
.cta__box .btn-primary {
  background: #fff;
  color: var(--accent);
}
.cta__box .btn-primary:hover {
  background: #f0f4ff;
}
.cta__box .btn-ghost {
  border-color: rgba(255, 255, 255, 0.5);
  color: #fff;
}
.cta__box .btn-ghost:hover {
  background: rgba(255, 255, 255, 0.12);
}

/* RESPONSIVE */
@media (max-width: 980px) {
  .grid--features,
  .grid--steps,
  .grid--pricing {
    grid-template-columns: repeat(2, 1fr);
  }
  .grid--audience {
    grid-template-columns: repeat(3, 1fr);
  }
  .grid--posts {
    grid-template-columns: 1fr;
  }
  .teaser {
    grid-template-columns: 1fr;
    gap: 28px;
    padding: 32px;
  }
}
@media (max-width: 560px) {
  .section {
    padding: 60px 0;
  }
  .grid--features,
  .grid--steps,
  .grid--pricing,
  .grid--audience {
    grid-template-columns: 1fr;
  }
  .hero__meta {
    gap: 12px;
  }
  .cta__box {
    padding: 40px 22px;
  }
}
</style>
