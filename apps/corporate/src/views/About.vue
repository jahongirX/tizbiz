<script setup>
import { RouterLink } from 'vue-router'

const REGISTER_URL = 'https://b.startup/app/register'

const pillars = [
  {
    icon: '🌐',
    title: 'Sayt yo‘q edi — biz beramiz',
    text: 'Mahalliy bizneslarning aksariyatida sayt yo‘q. Shuning uchun biz “sayt + bot + booking”ni qutida beramiz. Bu YClients Rossiyada qilmagan narsa — u yerda bizneslarda sayt bor edi.',
  },
  {
    icon: '✈️',
    title: 'Telegram-native',
    text: 'Mijoz uchun yangi ilova — to‘siq. Bizda esa hamma narsa Telegram’da: mijoz hech narsa o‘rnatmaydi, biznes esa mijoz allaqachon bo‘lgan joyda uchrashadi.',
  },
  {
    icon: '💳',
    title: 'Oldindan to‘lov',
    text: 'Payme va Click orqali depozit no-show’ni to‘xtatadi va pul oqimini barqarorlashtiradi. Booking bizneslari uchun asosiy model — obuna, komissiya emas.',
  },
  {
    icon: '📇',
    title: 'Ma’lumot biznesda qoladi',
    text: 'Har bir mijoz, tashrif va to‘lov sizning bazangizda. Cashback loyallik va referral shu baza ustida quriladi — mijoz qaytadi, biznes o‘sadi.',
  },
]

const phases = [
  { tag: 'Hozir', title: 'Booking + sayt + CRM', text: 'Onlayn navbat, brendlangan sayt/bot, oldindan to‘lov, mijozlar bazasi va cashback loyallik.' },
  { tag: 'Keyin', title: 'AI-seller', text: 'Biznes ma’lumotidan javob beruvchi 24/7 savdo-yordamchi bot — savoldan yozuvgacha olib boradi.' },
  { tag: 'Keyin', title: 'Restoran zakazi', text: 'Dostavkasiz restoran zakaz oqimi — joyida va olib ketish uchun.' },
  { tag: 'Keyin', title: 'Uy-xizmat', text: 'Hamshira, massaj, santexnik uchun komissiya marketplace: vetting va escrow.' },
  { tag: 'Keyin', title: 'Iste’molchi ilovasi', text: 'Discovery, featured bizneslar va premium obuna — mijoz uchun yagona kirish nuqtasi.' },
]
</script>

<template>
  <main>
    <section class="container page-header">
      <span class="eyebrow">Loyiha haqida</span>
      <h1>Mahalliy biznesni onlaynga olib chiqamiz</h1>
      <p>
        TizBiz — Surxondaryo va Termiz xizmat bizneslari uchun onlayn borliq, booking, CRM/loyallik
        va AI platformasi. Telegram-native. Biz “arzon YClients” emasmiz.
      </p>
    </section>

    <section class="section" style="padding-top: 20px">
      <div class="container">
        <div class="mission card">
          <span class="tag">Missiya</span>
          <p>
            Mahalliy xizmat bizneslari kuchli, lekin ular internetda deyarli ko‘rinmaydi — sayti
            yo‘q, yozuv qog‘oz daftarda, mijoz bazasi yo‘qoladi. Biz ularga onlayn borliq va
            zamonaviy asboblarni <strong>qutida</strong>, bir kunda va texnik bilim talab qilmasdan
            beramiz.
          </p>
        </div>
      </div>
    </section>

    <section class="section section--soft">
      <div class="container">
        <div class="section-head">
          <span class="eyebrow">Farqimiz</span>
          <h2>Nega TizBiz boshqacha</h2>
          <p>To‘rtta tamoyil ustiga qurilgan.</p>
        </div>
        <div class="grid pillars">
          <article v-for="p in pillars" :key="p.title" class="card pillar">
            <div class="pillar__icon">{{ p.icon }}</div>
            <h3>{{ p.title }}</h3>
            <p>{{ p.text }}</p>
          </article>
        </div>
      </div>
    </section>

    <section class="section">
      <div class="container">
        <div class="section-head">
          <span class="eyebrow">Yo‘l xaritasi</span>
          <h2>Bosqichma-bosqich super-app</h2>
          <p>Hammasini birdan qurmaymiz. Keyingi bosqich faqat oldingisi real ishlaganda yoqiladi.</p>
        </div>
        <div class="phases">
          <article v-for="(ph, i) in phases" :key="ph.title" class="phase" :class="{ 'phase--now': i === 0 }">
            <span class="phase__tag">{{ ph.tag }}</span>
            <h3>{{ ph.title }}</h3>
            <p>{{ ph.text }}</p>
          </article>
        </div>
      </div>
    </section>

    <section class="section cta">
      <div class="container">
        <div class="cta__box">
          <h2>Biznesingizni TizBiz’ga ulang</h2>
          <p>Bepul boshlang — brendlangan sayt, bot va booking bir kunda tayyor bo‘ladi.</p>
          <div class="cta__actions">
            <a class="btn btn-primary btn-lg" :href="REGISTER_URL">Bepul boshlash</a>
            <router-link class="btn btn-ghost btn-lg" to="/how-it-works">Qanday ishlaydi</router-link>
          </div>
        </div>
      </div>
    </section>
  </main>
</template>

<style scoped>
.mission {
  max-width: 780px;
  margin: 0 auto;
  text-align: center;
  padding: 40px;
}
.mission p {
  font-size: clamp(18px, 2.4vw, 22px);
  line-height: 1.6;
  color: var(--text);
  margin: 18px 0 0;
}

.pillars {
  grid-template-columns: repeat(2, 1fr);
}
.pillar__icon {
  font-size: 26px;
  width: 52px;
  height: 52px;
  display: grid;
  place-items: center;
  border-radius: 13px;
  background: var(--accent-soft);
  margin-bottom: 16px;
}
.pillar h3 {
  font-size: 18px;
  margin: 0 0 8px;
  letter-spacing: -0.01em;
}
.pillar p {
  margin: 0;
  color: var(--text-soft);
  font-size: 15px;
}

.phases {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 16px;
}
.phase {
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 22px;
}
.phase--now {
  border-color: var(--accent);
  box-shadow: var(--shadow);
}
.phase__tag {
  display: inline-block;
  font-size: 12px;
  font-weight: 700;
  color: var(--text-soft);
  margin-bottom: 12px;
}
.phase--now .phase__tag {
  color: var(--accent);
}
.phase h3 {
  font-size: 16px;
  margin: 0 0 8px;
  letter-spacing: -0.01em;
}
.phase p {
  margin: 0;
  color: var(--text-soft);
  font-size: 13.5px;
}

/* CTA (shared look) */
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

@media (max-width: 980px) {
  .phases {
    grid-template-columns: repeat(2, 1fr);
  }
}
@media (max-width: 620px) {
  .pillars {
    grid-template-columns: 1fr;
  }
  .phases {
    grid-template-columns: 1fr;
  }
  .cta__box {
    padding: 40px 22px;
  }
}
</style>
