<script setup>
import { ref, computed } from 'vue'
import { RouterLink } from 'vue-router'
import { posts, formatDate } from '../data/posts'

const REGISTER_URL = 'https://admin.tizbiz.uz/app/register'
const PHONE = '+998 90 000 00 00'
const TELEGRAM = 'https://t.me/tizbiz'

/* ---------- Interactive loss calculator ---------- */
const sizes = [
  { key: 's', label: 'Kichik', hint: '1–2 usta', daily: 8, price: 60000 },
  { key: 'm', label: 'O‘rta', hint: '3–6 usta', daily: 20, price: 90000 },
  { key: 'l', label: 'Katta', hint: '7+ usta', daily: 45, price: 120000 },
]
const sizeKey = ref('m')
const noShow = ref(20)
const active = computed(() => sizes.find((s) => s.key === sizeKey.value))
const monthlyBookings = computed(() => active.value.daily * 30)
const lostPerMonth = computed(() =>
  Math.round(monthlyBookings.value * (noShow.value / 100) * active.value.price),
)
const recovered = computed(() => Math.round(lostPerMonth.value * 0.7))

function som(n) {
  return new Intl.NumberFormat('ru-RU').format(Math.round(n)).replace(/,/g, ' ')
}
function mln(n) {
  return (n / 1_000_000).toFixed(1).replace('.', ',')
}

/* ---------- Static content ---------- */
const integrations = ['Telegram', 'Payme', 'Click', 'SMS', 'Instagram', 'Google']

const features = [
  { icon: '🌐', title: 'Brendlangan sayt + bot', text: 'Nomingiz bilan mini-sayt va Telegram bot — bir kunda, kod yozmasdan ishga tushadi.' },
  { icon: '📅', title: 'Onlayn navbat (booking)', text: 'Mijoz xizmat, usta va bo‘sh vaqtni tanlab, o‘zi navbat oladi. Real vaqtda yangilanadi.' },
  { icon: '💳', title: 'Oldindan to‘lov', text: 'Payme / Click orqali depozit — no-show tugaydi, bo‘sh qolgan vaqt kamayadi.' },
  { icon: '📇', title: 'Mijozlar bazasi (CRM)', text: 'Har mijoz saqlanadi, tarixi ko‘rinadi. Kim keldi, kim yo‘qoldi — hammasi ochiq.' },
  { icon: '🎁', title: 'Cashback loyallik', text: 'Cashback, referral va takliflar bilan mijozlarni qaytarib turasiz.' },
  { icon: '✉️', title: 'SMS + Telegram eslatma', text: 'Navbatdan oldin avtomat eslatma. Kelmaslik kamayadi, ishonch ortadi.' },
]

const controls = [
  { key: 'teal', icon: '📅', title: 'Navbatlar', text: 'Barcha booking bitta kalendarda — telefon, bot va saytdan kelgan navbatlar.' },
  { key: 'green', icon: '💰', title: 'To‘lovlar', text: 'Oldindan to‘lov, depozit va daromad — har kuni aniq raqamlarda.' },
  { key: 'orange', icon: '📣', title: 'Eslatma / SMS', text: 'Avtomatik eslatma va xabarnomalar — o‘z SMS shlyuzingiz orqali.' },
  { key: 'violet', icon: '🤝', title: 'Mijozlar', text: 'Butun mijozlar bazasi, tarixi va loyallik — bitta joyda.' },
]

const useCases = [
  { key: 'green', tag: 'Barbershop', metric: '−70%', label: 'no-show', text: 'Oldindan to‘lov va eslatma bilan bo‘sh qolgan vaqt keskin kamayadi.' },
  { key: 'violet', tag: 'Go‘zallik saloni', metric: '+40%', label: 'qaytish', text: 'Cashback va avtomatik takliflar mijozlarni qaytarib turadi.' },
  { key: 'pink', tag: 'Klinika / stomatologiya', metric: '24/7', label: 'qabul', text: 'Registratura band bo‘lsa ham, bemor botdan navbatga yoziladi.' },
  { key: 'blue', tag: 'Tort / kelin ko‘ylak', metric: '0', label: 'yo‘qolgan buyurtma', text: 'Har so‘rov saqlanadi, hech bir mijoz e’tibordan chetda qolmaydi.' },
]

const plans = [
  { name: 'Bepul', price: '0', period: 'so‘m/oy', tagline: 'Boshlash uchun', highlight: false,
    features: ['Brendlangan mini-sayt', 'Telegram bot', '1 xodim, oyiga 30 navbat', 'Asosiy mijozlar bazasi'], cta: 'Bepul boshlash' },
  { name: 'Start', price: '99 000', period: 'so‘m/oy', tagline: 'Yakka usta uchun', highlight: false,
    features: ['Cheksiz navbat', '2 xodimgacha', 'Payme / Click oldindan to‘lov', 'SMS + Telegram eslatma'], cta: 'Tanlash' },
  { name: 'Standart', price: '249 000', period: 'so‘m/oy', tagline: 'O‘sayotgan biznes', highlight: true,
    features: ['Start’dagi hammasi', '10 xodimgacha', 'Cashback loyallik + referral', 'Kengaytirilgan CRM va hisobotlar'], cta: 'Eng ommabop' },
  { name: 'Klinika', price: '590 000', period: 'so‘m/oy', tagline: 'Klinika va tarmoqlar', highlight: false,
    features: ['Standart’dagi hammasi', 'Cheksiz xodim va filial', 'Rollar va ruxsatlar', 'Prioritet qo‘llab-quvvatlash'], cta: 'Bog‘lanish' },
]

const trust = [
  { big: '1 kun', small: 'ishga tushish vaqti' },
  { big: '0%', small: 'booking komissiyasi' },
  { big: '24/7', small: 'Telegram bot savdosi' },
  { big: 'Payme·Click', small: 'oldindan to‘lov' },
]

const faqs = [
  { q: 'Saytim yo‘q — ishlata olamanmi?', a: 'Ha. Aynan shuning uchun TizBiz sizga brendlangan mini-sayt, Telegram bot va booking sahifasini qutida beradi. Alohida sayt yasashning hojati yo‘q.' },
  { q: 'Mijoz ilova o‘rnatishi kerakmi?', a: 'Yo‘q. Mijoz Telegram’ni ochib, xizmat va bo‘sh vaqtni tanlaydi — hech narsa o‘rnatmaydi. Vaqti kelganda eslatma keladi.' },
  { q: 'Oldindan to‘lov qanday ishlaydi?', a: 'Payme yoki Click orqali mijoz kichik depozit qoldiradi. Bu no-show’ni to‘xtatadi; kelganда depozit xizmat narxidan chegiriladi.' },
  { q: 'Komissiya olasizmi?', a: 'Booking bizneslari uchun — yo‘q, faqat oylik obuna. Komissiya faqat uy-xizmat marketplace yo‘nalishida bo‘ladi.' },
  { q: 'Bir necha usta / filial bo‘lsa-chi?', a: 'Har usta va filialni alohida boshqarasiz — rollar, jadval va hisobotlar bilan. Standart va Klinika tariflari buni qo‘llab-quvvatlaydi.' },
]
const openFaq = ref(0)

const latestPosts = posts.slice(0, 3)
</script>

<template>
  <main>
    <!-- ===== HERO ===== -->
    <section class="hero">
      <div class="container hero__inner">
        <div class="hero__text">
          <span class="eyebrow">O‘zbekiston xizmat bizneslari uchun</span>
          <h1>Biznes navbati, mijozlari va puli — <span class="hl">bitta joyda</span></h1>
          <p class="hero__sub">
            Brendlangan sayt, Telegram bot, onlayn booking, oldindan to‘lov va CRM/loyallik —
            yagona tizimda. Bir kunda ishga tushiring.
          </p>
          <div class="hero__actions">
            <a class="btn btn-primary btn-lg" :href="REGISTER_URL">Bepul boshlash</a>
            <RouterLink class="btn btn-ghost btn-lg" to="/how-it-works">Qanday ishlaydi ↗</RouterLink>
          </div>
          <div class="hero__meta">
            <span>✓ Karta shart emas</span>
            <span>✓ Bir kunda tayyor</span>
            <span>✓ Payme / Click</span>
          </div>
        </div>

        <!-- Dashboard mock -->
        <div class="hero__panel" aria-hidden="true">
          <div class="dash">
            <div class="dash__top">
              <div>
                <div class="dash__name">Baraka Barbershop</div>
                <div class="dash__sub">Bu oy · daromad</div>
              </div>
              <span class="dash__pill">+40%</span>
            </div>
            <div class="dash__figure">12,4<span>mln so‘m</span></div>
            <div class="dash__chart">
              <span v-for="(h, i) in [42, 58, 50, 72, 64, 86, 78]" :key="i" :style="{ height: h + '%' }"></span>
            </div>
            <div class="dash__row">
              <div class="dash__stat"><b>128</b><small>navbat</small></div>
              <div class="dash__stat"><b>96%</b><small>kelish</small></div>
              <div class="dash__stat"><b>+31</b><small>yangi mijoz</small></div>
            </div>
          </div>
          <div class="hero__glow"></div>
        </div>
      </div>

      <div class="container hero__logos">
        <span>Ulanadi:</span>
        <div class="hero__logos-row">
          <span v-for="l in integrations" :key="l" class="logo-chip">{{ l }}</span>
        </div>
      </div>
    </section>

    <!-- ===== LOSS CALCULATOR ===== -->
    <section class="section section--tight">
      <div class="container">
        <div class="calc">
          <div class="calc__head">
            <span class="calc__badge">Siz har kuni pul yo‘qotyapsiz</span>
            <h2>No-show va bo‘sh qolgan vaqt — bu real pul</h2>
            <p>Biznesingiz o‘lchamini tanlang va oyiga qancha yo‘qotayotganingizni ko‘ring.</p>
          </div>

          <div class="calc__grid">
            <div class="calc__controls">
              <label class="calc__label">Biznes o‘lchami</label>
              <div class="seg">
                <button
                  v-for="s in sizes"
                  :key="s.key"
                  class="seg__btn"
                  :class="{ 'seg__btn--on': sizeKey === s.key }"
                  @click="sizeKey = s.key"
                >
                  <b>{{ s.label }}</b><small>{{ s.hint }}</small>
                </button>
              </div>

              <label class="calc__label" style="margin-top: 26px">
                Kelmaslik (no-show): <b class="calc__pct">{{ noShow }}%</b>
              </label>
              <input v-model.number="noShow" type="range" min="5" max="40" step="1" class="range" />

              <div class="calc__facts">
                <span>Oyiga navbat: <b>{{ som(monthlyBookings) }}</b></span>
                <span>O‘rtacha narx: <b>{{ som(active.price) }} so‘m</b></span>
              </div>
            </div>

            <div class="calc__result">
              <div class="calc__lost">
                <span class="calc__lost-label">Oyiga yo‘qotish</span>
                <div class="calc__lost-num">{{ mln(lostPerMonth) }} <span>mln so‘m</span></div>
              </div>
              <div class="calc__recover">
                <div class="calc__recover-bar"><span :style="{ width: '70%' }"></span></div>
                <p>
                  TizBiz bilan oldindan to‘lov va eslatma orqali
                  <b>~{{ som(recovered) }} so‘m</b> qaytariladi.
                </p>
              </div>
              <a class="btn btn-primary btn-block" :href="REGISTER_URL">Yo‘qotishni to‘xtatish</a>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== FEATURES ===== -->
    <section id="features" class="section section--soft">
      <div class="container">
        <div class="section-head">
          <span class="eyebrow">Imkoniyatlar</span>
          <h2>Barchasi bitta markazda ishlaydi</h2>
          <p>Sayt, bot, navbat, to‘lov va CRM — alohida vositalar emas, yagona tizim.</p>
        </div>
        <div class="grid feat-grid">
          <article v-for="f in features" :key="f.title" class="card feat">
            <div class="feat__icon">{{ f.icon }}</div>
            <h3>{{ f.title }}</h3>
            <p>{{ f.text }}</p>
          </article>
        </div>
      </div>
    </section>

    <!-- ===== CONTROL (pastel cards) ===== -->
    <section class="section">
      <div class="container">
        <div class="section-head">
          <span class="eyebrow">Bitta oynadan</span>
          <h2>TizBiz bilan nimani nazorat qilasiz</h2>
          <p>Har kanaldan kelgan ma’lumot — bir joyda, real vaqtda.</p>
        </div>
        <div class="grid ctrl-grid">
          <article v-for="c in controls" :key="c.title" class="ctrl" :class="`pastel--${c.key}`">
            <div class="ctrl__icon">{{ c.icon }}</div>
            <h3>{{ c.title }}</h3>
            <p>{{ c.text }}</p>
          </article>
        </div>
      </div>
    </section>

    <!-- ===== USE CASES ===== -->
    <section class="section section--soft">
      <div class="container">
        <div class="section-head">
          <span class="eyebrow">Kimlar uchun</span>
          <h2>Har xil biznes — bitta tizim</h2>
          <p>Navbat oladigan har qanday xizmat biznesiga mos. Quyidagi raqamlar — kutilayotgan natija.</p>
        </div>
        <div class="grid case-grid">
          <article v-for="u in useCases" :key="u.tag" class="case" :class="`pastel--${u.key}`">
            <span class="case__tag">{{ u.tag }}</span>
            <div class="case__metric">{{ u.metric }} <small>{{ u.label }}</small></div>
            <p>{{ u.text }}</p>
          </article>
        </div>
      </div>
    </section>

    <!-- ===== DARK VALUE BAND ===== -->
    <section class="section">
      <div class="container">
        <div class="valueband">
          <div class="valueband__text">
            <span class="valueband__badge">Qancha daromadni qo‘ldan boy beryapsiz?</span>
            <h2>No-show’ni to‘xtating, mijozni qaytaring — daromad o‘sadi</h2>
            <p>Oldindan to‘lov + eslatma + loyallik birga ishlaganda, yo‘qolgan pulning katta qismi qaytadi.</p>
            <a class="btn btn-primary btn-lg" :href="REGISTER_URL">Hisoblab ko‘rish</a>
          </div>
          <div class="valueband__stats">
            <div class="vstat"><b>+40%</b><span>qaytgan mijoz</span></div>
            <div class="vstat"><b>−70%</b><span>no-show</span></div>
            <div class="vstat vstat--hot"><b>24/7</b><span>bot savdosi</span></div>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== PRICING ===== -->
    <section id="pricing" class="section section--soft">
      <div class="container">
        <div class="section-head">
          <span class="eyebrow">Narxlar</span>
          <h2>Oddiy obuna, komissiya yo‘q</h2>
          <p>Booking bizneslari uchun oylik obuna. Narxlar taxminiy — biznesingizga moslashtiramiz.</p>
        </div>
        <div class="grid price-grid">
          <article v-for="p in plans" :key="p.name" class="price" :class="{ 'price--hot': p.highlight }">
            <div v-if="p.highlight" class="price__badge">Ommabop</div>
            <h3 class="price__name">{{ p.name }}</h3>
            <p class="price__tagline">{{ p.tagline }}</p>
            <div class="price__amount">{{ p.price }} <span>{{ p.period }}</span></div>
            <ul class="price__list">
              <li v-for="feat in p.features" :key="feat">{{ feat }}</li>
            </ul>
            <a class="btn btn-block" :class="p.highlight ? 'btn-primary' : 'btn-ghost'" :href="REGISTER_URL">{{ p.cta }}</a>
          </article>
        </div>
      </div>
    </section>

    <!-- ===== TRUST STATS ===== -->
    <section class="section--tight">
      <div class="container">
        <div class="trust">
          <div v-for="t in trust" :key="t.small" class="trust__item">
            <div class="trust__big">{{ t.big }}</div>
            <div class="trust__small">{{ t.small }}</div>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== FAQ ===== -->
    <section class="section">
      <div class="container faq-wrap">
        <div class="section-head">
          <span class="eyebrow">Savol-javob</span>
          <h2>Ko‘p beriladigan savollar</h2>
        </div>
        <div class="faq">
          <div
            v-for="(f, i) in faqs"
            :key="i"
            class="faq__item"
            :class="{ 'faq__item--open': openFaq === i }"
          >
            <button class="faq__q" @click="openFaq = openFaq === i ? -1 : i">
              <span>{{ f.q }}</span>
              <i class="faq__chev">›</i>
            </button>
            <div class="faq__a"><p>{{ f.a }}</p></div>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== BLOG PREVIEW ===== -->
    <section class="section section--soft">
      <div class="container">
        <div class="section-head">
          <span class="eyebrow">Blog</span>
          <h2>Booking va biznes haqida</h2>
          <p>No-show, loyallik, to‘lov va onlayn navbat bo‘yicha amaliy maslahatlar.</p>
        </div>
        <div class="grid post-grid">
          <RouterLink v-for="post in latestPosts" :key="post.slug" class="post" :to="`/blog/${post.slug}`">
            <div class="post__cover" :style="{ background: post.cover }">
              <span class="tag post__tag">{{ post.category }}</span>
            </div>
            <div class="post__body">
              <h3>{{ post.title }}</h3>
              <p>{{ post.excerpt }}</p>
              <time class="post__date" :datetime="post.date">{{ formatDate(post.date) }}</time>
            </div>
          </RouterLink>
        </div>
        <div class="section-more">
          <RouterLink class="btn btn-ghost" to="/blog">Barcha maqolalar →</RouterLink>
        </div>
      </div>
    </section>

    <!-- ===== FINAL DARK CTA + CONSULT ===== -->
    <section class="section">
      <div class="container">
        <div class="finalcta">
          <h2>Agar navbat, mijoz va to‘lov bitta tizimda bo‘lmasa — <span class="hl2">har kuni foyda yo‘qotyapsiz</span></h2>
          <p>Ro‘yxatdan o‘ting, xizmatlaringizni kiriting — bir kunda mijozlar onlayn navbat ola boshlaydi.</p>
          <div class="finalcta__actions">
            <a class="btn btn-primary btn-lg" :href="REGISTER_URL">Bepul boshlash</a>
            <a class="btn btn-ghost-dark btn-lg" :href="TELEGRAM">Telegram’da yozish</a>
          </div>
          <div class="finalcta__consult">
            <span>Bepul maslahat:</span>
            <a :href="`tel:${PHONE.replace(/\s/g, '')}`">{{ PHONE }}</a>
          </div>
        </div>
      </div>
    </section>
  </main>
</template>

<style scoped>
/* ============ HERO ============ */
.hero {
  position: relative;
  padding: 56px 0 40px;
  overflow: hidden;
}
.hero__inner {
  display: grid;
  grid-template-columns: 1.05fr 0.95fr;
  gap: 48px;
  align-items: center;
}
.hero h1 {
  font-size: clamp(34px, 5.4vw, 62px);
  line-height: 1.04;
  margin: 18px 0 18px;
}
.hl { color: var(--brand); }
.hero__sub {
  font-size: clamp(16px, 2vw, 20px);
  color: var(--text-soft);
  max-width: 520px;
  margin: 0 0 28px;
}
.hero__actions { display: flex; gap: 12px; flex-wrap: wrap; }
.hero__meta {
  display: flex;
  gap: 20px;
  flex-wrap: wrap;
  margin-top: 22px;
  color: var(--text-soft);
  font-size: 14px;
  font-weight: 500;
}

/* Dashboard mock */
.hero__panel { position: relative; }
.hero__glow {
  position: absolute;
  inset: -12% -8% -8% 8%;
  z-index: 0;
  background: radial-gradient(closest-side, color-mix(in srgb, var(--violet) 30%, transparent), transparent 70%);
  filter: blur(10px);
}
.dash {
  position: relative;
  z-index: 1;
  background: linear-gradient(160deg, #6d5ef0, #5b46d6 60%, #4b38c2);
  color: #fff;
  border-radius: 22px;
  padding: 26px 26px 22px;
  box-shadow: var(--shadow-lg);
}
.dash__top { display: flex; justify-content: space-between; align-items: flex-start; }
.dash__name { font-weight: 700; font-size: 16px; }
.dash__sub { font-size: 12.5px; opacity: 0.72; margin-top: 2px; }
.dash__pill {
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.24);
  border-radius: 999px;
  padding: 5px 12px;
  font-size: 13px;
  font-weight: 700;
}
.dash__figure { font-size: 38px; font-weight: 700; letter-spacing: -0.03em; margin: 16px 0 18px; }
.dash__figure span { font-size: 15px; font-weight: 500; opacity: 0.72; margin-left: 6px; }
.dash__chart {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 9px;
  align-items: end;
  height: 96px;
  margin-bottom: 18px;
}
.dash__chart span {
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.95), rgba(255, 255, 255, 0.5));
  border-radius: 6px 6px 3px 3px;
  min-height: 8px;
}
.dash__row { display: flex; justify-content: space-between; gap: 8px; }
.dash__stat { text-align: left; }
.dash__stat b { display: block; font-size: 19px; font-weight: 700; }
.dash__stat small { font-size: 12px; opacity: 0.72; }

/* Integrations */
.hero__logos {
  display: flex;
  align-items: center;
  gap: 18px;
  margin-top: 44px;
  flex-wrap: wrap;
}
.hero__logos > span { color: var(--text-faint); font-size: 14px; }
.hero__logos-row { display: flex; gap: 10px; flex-wrap: wrap; }
.logo-chip {
  padding: 7px 14px;
  border: 1px solid var(--border);
  border-radius: 999px;
  font-size: 13.5px;
  font-weight: 500;
  color: var(--text-soft);
  background: #fff;
}

/* ============ LOSS CALCULATOR ============ */
.calc {
  background: var(--ink-900);
  color: #fff;
  border-radius: var(--radius-lg);
  padding: 46px;
  box-shadow: var(--shadow-lg);
}
.calc__head { text-align: center; max-width: 640px; margin: 0 auto 34px; }
.calc__badge {
  display: inline-block;
  background: color-mix(in srgb, #ef5b5b 20%, transparent);
  color: #ff9d9d;
  border: 1px solid color-mix(in srgb, #ef5b5b 32%, transparent);
  padding: 6px 14px;
  border-radius: 999px;
  font-size: 13px;
  font-weight: 500;
}
.calc__head h2 { font-size: clamp(24px, 3.4vw, 34px); margin: 16px 0 10px; }
.calc__head p { color: rgba(255, 255, 255, 0.66); margin: 0; font-size: 16px; }
.calc__grid { display: grid; grid-template-columns: 1.1fr 0.9fr; gap: 26px; }
.calc__controls {
  background: var(--ink-800);
  border: 1px solid var(--ink-line);
  border-radius: 18px;
  padding: 26px;
}
.calc__label { display: block; font-size: 14px; color: rgba(255, 255, 255, 0.7); margin-bottom: 12px; }
.calc__pct { color: var(--brand); }
.seg { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.seg__btn {
  background: transparent;
  border: 1px solid var(--ink-line);
  border-radius: 12px;
  padding: 12px 8px;
  color: rgba(255, 255, 255, 0.8);
  cursor: pointer;
  transition: border-color 0.15s, background 0.15s;
  text-align: center;
}
.seg__btn b { display: block; font-size: 15px; }
.seg__btn small { font-size: 11.5px; opacity: 0.62; }
.seg__btn--on { border-color: var(--brand); background: color-mix(in srgb, var(--brand) 16%, transparent); color: #fff; }
.range { width: 100%; accent-color: var(--brand); margin-top: 4px; }
.calc__facts { display: flex; justify-content: space-between; gap: 12px; margin-top: 22px; flex-wrap: wrap; }
.calc__facts span { font-size: 13px; color: rgba(255, 255, 255, 0.6); }
.calc__facts b { color: #fff; font-weight: 700; }

.calc__result {
  background: linear-gradient(165deg, #182420, #101a16);
  border: 1px solid var(--ink-line);
  border-radius: 18px;
  padding: 26px;
  display: flex;
  flex-direction: column;
}
.calc__lost-label { font-size: 13px; color: rgba(255, 255, 255, 0.6); }
.calc__lost-num { font-size: clamp(34px, 6vw, 52px); font-weight: 700; letter-spacing: -0.03em; color: #ff8f8f; line-height: 1.05; margin-top: 4px; }
.calc__lost-num span { font-size: 16px; font-weight: 500; color: rgba(255, 255, 255, 0.6); }
.calc__recover { margin: 22px 0; }
.calc__recover-bar { height: 8px; border-radius: 999px; background: rgba(255, 255, 255, 0.1); overflow: hidden; }
.calc__recover-bar span { display: block; height: 100%; background: var(--brand); border-radius: 999px; }
.calc__recover p { font-size: 14px; color: rgba(255, 255, 255, 0.78); margin: 12px 0 0; }
.calc__recover b { color: var(--brand); }
.calc__result .btn { margin-top: auto; }

/* ============ FEATURES ============ */
.feat-grid { grid-template-columns: repeat(3, 1fr); }
.feat { transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease; }
.feat:hover { transform: translateY(-3px); box-shadow: var(--shadow); border-color: var(--border-strong); }
.feat__icon {
  width: 52px; height: 52px;
  display: grid; place-items: center;
  border-radius: 14px;
  background: var(--brand-soft);
  font-size: 24px;
  margin-bottom: 16px;
}
.feat h3 { font-size: 18px; margin: 0 0 8px; }
.feat p { margin: 0; color: var(--text-soft); font-size: 14.5px; }

/* ============ PASTEL CARDS ============ */
.pastel--teal { background: var(--p-teal-bg); }
.pastel--teal .ctrl__icon, .pastel--teal .case__tag { color: var(--p-teal-ink); }
.pastel--green { background: var(--p-green-bg); }
.pastel--green .ctrl__icon, .pastel--green .case__tag, .pastel--green .case__metric { color: var(--p-green-ink); }
.pastel--orange { background: var(--p-orange-bg); }
.pastel--orange .ctrl__icon, .pastel--orange .case__tag { color: var(--p-orange-ink); }
.pastel--violet { background: var(--p-violet-bg); }
.pastel--violet .ctrl__icon, .pastel--violet .case__tag, .pastel--violet .case__metric { color: var(--p-violet-ink); }
.pastel--pink { background: var(--p-pink-bg); }
.pastel--pink .case__tag, .pastel--pink .case__metric { color: var(--p-pink-ink); }
.pastel--blue { background: var(--p-blue-bg); }
.pastel--blue .case__tag, .pastel--blue .case__metric { color: var(--p-blue-ink); }

.ctrl-grid { grid-template-columns: repeat(4, 1fr); }
.ctrl { border-radius: var(--radius); padding: 26px; }
.ctrl__icon {
  width: 46px; height: 46px;
  display: grid; place-items: center;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.6);
  font-size: 22px;
  margin-bottom: 16px;
}
.ctrl h3 { font-size: 17px; margin: 0 0 8px; }
.ctrl p { margin: 0; color: var(--text-soft); font-size: 14px; }

/* Case cards */
.case-grid { grid-template-columns: repeat(4, 1fr); }
.case { border-radius: var(--radius); padding: 26px; }
.case__tag { font-size: 13px; font-weight: 700; }
.case__metric { font-size: 40px; font-weight: 700; letter-spacing: -0.03em; margin: 14px 0 10px; color: var(--text); }
.case__metric small { font-size: 14px; font-weight: 500; color: var(--text-soft); }
.case p { margin: 0; color: var(--text-soft); font-size: 14px; }

/* ============ DARK VALUE BAND ============ */
.valueband {
  background: var(--ink-900);
  color: #fff;
  border-radius: var(--radius-lg);
  padding: 48px;
  display: grid;
  grid-template-columns: 1.3fr 1fr;
  gap: 40px;
  align-items: center;
}
.valueband__badge {
  display: inline-block;
  color: #ffd964;
  background: color-mix(in srgb, #ffd964 16%, transparent);
  border: 1px solid color-mix(in srgb, #ffd964 30%, transparent);
  padding: 6px 14px; border-radius: 999px; font-size: 13px; font-weight: 500;
}
.valueband h2 { font-size: clamp(24px, 3.2vw, 34px); margin: 16px 0 12px; }
.valueband p { color: rgba(255, 255, 255, 0.7); margin: 0 0 24px; font-size: 16px; }
.valueband__stats { display: grid; gap: 14px; }
.vstat {
  background: var(--ink-800);
  border: 1px solid var(--ink-line);
  border-radius: 14px;
  padding: 18px 22px;
  display: flex; align-items: baseline; gap: 12px;
}
.vstat b { font-size: 30px; font-weight: 700; letter-spacing: -0.02em; }
.vstat span { color: rgba(255, 255, 255, 0.66); font-size: 14px; }
.vstat--hot b { color: #ffd964; }

/* ============ PRICING ============ */
.price-grid { grid-template-columns: repeat(4, 1fr); align-items: stretch; }
.price {
  position: relative;
  background: #fff;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 28px 24px;
  display: flex;
  flex-direction: column;
}
.price--hot { border-color: var(--brand); box-shadow: var(--shadow); }
.price__badge {
  position: absolute; top: -12px; left: 24px;
  background: var(--brand); color: #fff;
  font-size: 12px; font-weight: 700;
  padding: 5px 14px; border-radius: 999px;
}
.price__name { font-size: 20px; margin: 0 0 4px; }
.price__tagline { color: var(--text-soft); font-size: 14px; margin: 0 0 18px; }
.price__amount { font-size: 30px; font-weight: 700; letter-spacing: -0.02em; }
.price__amount span { font-size: 14px; font-weight: 500; color: var(--text-soft); }
.price__list { list-style: none; margin: 20px 0 24px; padding: 0; display: grid; gap: 11px; flex: 1; }
.price__list li { position: relative; padding-left: 26px; font-size: 14.5px; color: var(--text-soft); }
.price__list li::before { content: '✓'; position: absolute; left: 0; top: 0; color: var(--brand); font-weight: 700; }

/* ============ TRUST ============ */
.trust {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 20px;
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  background: var(--bg-mint);
  padding: 34px 20px;
  text-align: center;
}
.trust__big { font-size: clamp(24px, 3vw, 34px); font-weight: 700; letter-spacing: -0.02em; color: var(--brand-ink); }
.trust__small { color: var(--text-soft); font-size: 14px; margin-top: 4px; }

/* ============ FAQ ============ */
.faq-wrap { max-width: 780px; }
.faq { display: grid; gap: 12px; }
.faq__item { border: 1px solid var(--border); border-radius: 14px; background: #fff; overflow: hidden; transition: border-color 0.15s; }
.faq__item--open { border-color: var(--brand); }
.faq__q {
  width: 100%;
  display: flex; align-items: center; justify-content: space-between; gap: 16px;
  background: transparent; border: 0; cursor: pointer;
  padding: 20px 22px;
  font: inherit; font-weight: 500; font-size: 16px; color: var(--text); text-align: left;
}
.faq__chev { font-style: normal; font-size: 22px; color: var(--text-faint); transition: transform 0.2s; transform: rotate(90deg); }
.faq__item--open .faq__chev { transform: rotate(-90deg); color: var(--brand); }
.faq__a { max-height: 0; overflow: hidden; transition: max-height 0.25s ease; }
.faq__item--open .faq__a { max-height: 240px; }
.faq__a p { margin: 0; padding: 0 22px 20px; color: var(--text-soft); font-size: 15px; }

/* ============ BLOG ============ */
.post-grid { grid-template-columns: repeat(3, 1fr); }
.post {
  background: #fff; border: 1px solid var(--border); border-radius: var(--radius);
  overflow: hidden; display: flex; flex-direction: column;
  transition: transform 0.15s ease, border-color 0.15s ease, box-shadow 0.15s ease;
}
.post:hover { transform: translateY(-3px); border-color: var(--border-strong); box-shadow: var(--shadow); }
.post__cover { position: relative; height: 140px; }
.post__tag { position: absolute; left: 14px; bottom: 14px; background: rgba(255, 255, 255, 0.92); }
.post__body { padding: 20px; display: flex; flex-direction: column; gap: 8px; flex: 1; }
.post__body h3 { font-size: 17px; margin: 0; }
.post__body p {
  margin: 0; color: var(--text-soft); font-size: 14px;
  display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden;
}
.post__date { margin-top: auto; color: var(--text-faint); font-size: 13px; font-weight: 500; }

/* ============ FINAL CTA ============ */
.finalcta {
  background: radial-gradient(120% 140% at 20% 0%, #16261f, var(--ink-900));
  color: #fff;
  border-radius: var(--radius-lg);
  padding: 64px 40px;
  text-align: center;
}
.finalcta h2 { font-size: clamp(26px, 4vw, 42px); line-height: 1.12; margin: 0 auto 14px; max-width: 780px; }
.hl2 { color: #ff8f8f; }
.finalcta p { color: rgba(255, 255, 255, 0.72); margin: 0 auto 28px; max-width: 540px; font-size: 17px; }
.finalcta__actions { display: flex; gap: 12px; justify-content: center; flex-wrap: wrap; }
.btn-ghost-dark { background: transparent; color: #fff; border-color: rgba(255, 255, 255, 0.28); }
.btn-ghost-dark:hover { background: rgba(255, 255, 255, 0.1); }
.finalcta__consult { margin-top: 24px; color: rgba(255, 255, 255, 0.66); font-size: 15px; }
.finalcta__consult a { color: #fff; font-weight: 700; margin-left: 6px; }

/* ============ RESPONSIVE ============ */
@media (max-width: 980px) {
  .hero__inner { grid-template-columns: 1fr; gap: 36px; }
  .hero__panel { order: -1; max-width: 440px; }
  .feat-grid { grid-template-columns: repeat(2, 1fr); }
  .ctrl-grid, .case-grid, .price-grid { grid-template-columns: repeat(2, 1fr); }
  .calc__grid { grid-template-columns: 1fr; }
  .valueband { grid-template-columns: 1fr; gap: 28px; padding: 34px; }
  .post-grid { grid-template-columns: 1fr; }
  .trust { grid-template-columns: repeat(2, 1fr); gap: 24px; }
}
@media (max-width: 560px) {
  .calc { padding: 26px 18px; }
  .feat-grid, .ctrl-grid, .case-grid, .price-grid { grid-template-columns: 1fr; }
  .hero__meta { gap: 12px; }
  .finalcta { padding: 44px 22px; }
}
</style>
