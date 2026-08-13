<script setup>
import { RouterLink } from 'vue-router'

const REGISTER_URL = 'https://admin.tizbiz.uz/app/register'

const steps = [
  {
    n: '1',
    title: 'Biznes ro‘yxatdan o‘tadi',
    text: 'Biznes nomi, xizmatlar ro‘yxati, narxlar, xodimlar va ish vaqtini kiritasiz. Bu — bir martalik sozlash, texnik bilim talab qilmaydi.',
  },
  {
    n: '2',
    title: 'Sayt + bot + booking tayyor bo‘ladi',
    text: 'Sizning ma’lumotingizdan brendlangan mini-sayt, Telegram bot va booking sahifasi avtomatik generatsiya qilinadi. Nomingiz, logotipingiz va xizmatlaringiz bilan — bir kunda.',
  },
  {
    n: '3',
    title: 'Mijoz onlayn yoziladi',
    text: 'Mijoz saytdan yoki Telegram botdan xizmatni, ustani va bo‘sh vaqtni tanlab, o‘zi navbat oladi. Ikki mijoz bir vaqtga tushib qolmaydi.',
  },
  {
    n: '4',
    title: 'Kerak bo‘lsa oldindan to‘laydi',
    text: 'Payme yoki Click orqali depozit yoki to‘liq to‘lov qoldiradi. Bu no-show’ni kamaytiradi va pul oqimini barqarorlashtiradi. Rejimni biznes o‘zi tanlaydi.',
  },
  {
    n: '5',
    title: 'Baza va loyallik yig‘iladi',
    text: 'Har bir yozuv mijozlar bazasiga tushadi: kim, qachon, qaysi xizmatga keldi. Ustiga cashback loyallik va referral qo‘shiladi — mijoz qaytishga sabab topadi.',
  },
  {
    n: '6',
    title: 'Eslatmalar avtomatik boradi',
    text: 'Navbatdan oldin Telegram va SMS orqali eslatma yuboriladi. Mijoz tasdiqlaydi yoki bekor qiladi — bo‘shagan vaqt boshqa mijozga taklif qilinadi.',
  },
]

const faq = [
  {
    q: 'Menda sayt yo‘q, baribir ishlaydimi?',
    a: 'Ha. Aynan shu bizning farqimiz — biz sizga brendlangan mini-sayt, bot va booking’ni qutida beramiz. Alohida sayt qildirish shart emas.',
  },
  {
    q: 'Mijoz ilova o‘rnatishi kerakmi?',
    a: 'Yo‘q. TizBiz Telegram-native. Mijoz allaqachon ochiq turgan Telegram’da bir necha tugma bilan navbat oladi.',
  },
  {
    q: 'To‘lov qanday olinadi?',
    a: 'Payme va Click qo‘llab-quvvatlanadi. Depozit yoki to‘liq oldindan to‘lovni biznes o‘zi tanlaydi.',
  },
]
</script>

<template>
  <main>
    <section class="container page-header">
      <span class="eyebrow">Qanday ishlaydi</span>
      <h1>Ro‘yxatdan o‘tishdan booking’gacha — olti qadam</h1>
      <p>
        TizBiz texnik bilim talab qilmaydi. Bir marta sozlaysiz — keyin tizim mijozlarni qabul
        qilishni, to‘lovni va eslatmalarni o‘zi bajaradi.
      </p>
    </section>

    <section class="section" style="padding-top: 20px">
      <div class="container steps">
        <article v-for="s in steps" :key="s.n" class="step-row">
          <div class="step-row__num">{{ s.n }}</div>
          <div class="step-row__body">
            <h2>{{ s.title }}</h2>
            <p>{{ s.text }}</p>
          </div>
        </article>
      </div>
    </section>

    <section class="section section--soft">
      <div class="container">
        <div class="section-head">
          <span class="eyebrow">Tez-tez so‘raladi</span>
          <h2>Boshlashdan oldingi savollar</h2>
        </div>
        <div class="faq">
          <article v-for="item in faq" :key="item.q" class="card faq__item">
            <h3>{{ item.q }}</h3>
            <p>{{ item.a }}</p>
          </article>
        </div>
      </div>
    </section>

    <section class="section cta">
      <div class="container">
        <div class="cta__box">
          <h2>Sinab ko‘rishga tayyormisiz?</h2>
          <p>Bepul tarifda ro‘yxatdan o‘ting — sayt, bot va booking bir kunda ishga tushadi.</p>
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
.steps {
  display: grid;
  gap: 16px;
  max-width: 760px;
}
.step-row {
  display: grid;
  grid-template-columns: 56px 1fr;
  gap: 20px;
  align-items: start;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 26px;
}
.step-row__num {
  display: grid;
  place-items: center;
  width: 56px;
  height: 56px;
  border-radius: 16px;
  background: var(--accent);
  color: #fff;
  font-weight: 800;
  font-size: 22px;
}
.step-row__body h2 {
  font-size: 19px;
  letter-spacing: -0.01em;
  margin: 4px 0 8px;
}
.step-row__body p {
  margin: 0;
  color: var(--text-soft);
  font-size: 15.5px;
}

.faq {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
}
.faq__item h3 {
  font-size: 16px;
  margin: 0 0 8px;
}
.faq__item p {
  margin: 0;
  color: var(--text-soft);
  font-size: 14.5px;
}

/* CTA (shared look with Home) */
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

@media (max-width: 760px) {
  .faq {
    grid-template-columns: 1fr;
  }
  .step-row {
    grid-template-columns: 44px 1fr;
    gap: 16px;
    padding: 20px;
  }
  .step-row__num {
    width: 44px;
    height: 44px;
    font-size: 18px;
    border-radius: 13px;
  }
  .cta__box {
    padding: 40px 22px;
  }
}
</style>
