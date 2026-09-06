<script setup>
import { RouterLink } from 'vue-router'
import logoUrl from '../assets/logo.png'

const LOGIN_URL = 'https://admin.tizbiz.uz/app/login'
const REGISTER_URL = 'https://admin.tizbiz.uz/app/register'
const TELEGRAM = 'https://t.me/tizbiz'
const YEAR = 2026

const stats = [
  { big: '1 kun', small: 'ishga tushish' },
  { big: '0%', small: 'booking komissiyasi' },
  { big: '24/7', small: 'bot savdosi' },
  { big: 'Payme·Click', small: 'oldindan to‘lov' },
]
</script>

<template>
  <footer class="footer">
    <div class="container">
      <div class="footer__grid">
        <div class="footer__brand">
          <router-link to="/" class="brand">
            <img :src="logoUrl" alt="TizBiz" class="brand__logo" />
          </router-link>
          <p>O‘zbekiston xizmat bizneslari uchun booking, brendlangan sayt, to‘lov va CRM — Telegram’da, bitta tizimda.</p>
          <a class="btn btn-primary btn-sm" :href="REGISTER_URL">Bepul boshlash</a>
        </div>

        <nav class="footer__col" aria-label="Platforma">
          <span class="footer__title">Platforma</span>
          <router-link :to="{ path: '/', hash: '#features' }">Imkoniyatlar</router-link>
          <router-link to="/how-it-works">Qanday ishlaydi</router-link>
          <router-link :to="{ path: '/', hash: '#pricing' }">Narxlar</router-link>
          <router-link to="/about">Loyiha haqida</router-link>
        </nav>

        <nav class="footer__col" aria-label="Resurslar">
          <span class="footer__title">Resurslar</span>
          <router-link to="/blog">Blog</router-link>
          <a :href="LOGIN_URL">Kirish</a>
          <a :href="REGISTER_URL">Ro‘yxatdan o‘tish</a>
        </nav>

        <nav class="footer__col" aria-label="Kontaktlar">
          <span class="footer__title">Kontaktlar</span>
          <a href="tel:+998900000000">+998 90 000 00 00</a>
          <a :href="TELEGRAM">Telegram</a>
          <span class="footer__muted">O‘zbekiston bo‘ylab</span>
        </nav>
      </div>

      <div class="footer__stats">
        <div v-for="s in stats" :key="s.small" class="fstat">
          <b>{{ s.big }}</b>
          <span>{{ s.small }}</span>
        </div>
      </div>

      <div class="footer__bottom">
        <span>© {{ YEAR }} TizBiz. Barcha huquqlar himoyalangan.</span>
        <span>Ishchi nom — brend keyin belgilanadi.</span>
      </div>
    </div>
  </footer>
</template>

<style scoped>
.footer {
  background: var(--ink-900);
  color: #fff;
  padding: 64px 0 28px;
}
.footer__grid {
  display: grid;
  grid-template-columns: 1.8fr 1fr 1fr 1fr;
  gap: 32px;
  padding-bottom: 44px;
  border-bottom: 1px solid var(--ink-line);
}
.brand { display: inline-flex; align-items: center; }
/* Dark footer → render the (light-background) logo as a clean white mark. */
.brand__logo { height: 40px; width: auto; display: block; filter: brightness(0) invert(1); }
.footer__brand p { color: rgba(255, 255, 255, 0.6); font-size: 14px; margin: 16px 0 20px; max-width: 340px; }
.footer__col { display: flex; flex-direction: column; gap: 12px; }
.footer__title { font-size: 13px; font-weight: 700; color: #fff; margin-bottom: 2px; }
.footer__col a { color: rgba(255, 255, 255, 0.62); font-size: 14.5px; }
.footer__col a:hover { color: #fff; }
.footer__muted { color: rgba(255, 255, 255, 0.4); font-size: 14px; }

.footer__stats {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 20px;
  padding: 34px 0;
  border-bottom: 1px solid var(--ink-line);
}
.fstat b { display: block; font-size: 26px; font-weight: 700; letter-spacing: -0.02em; }
.fstat span { color: rgba(255, 255, 255, 0.55); font-size: 13.5px; }

.footer__bottom {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
  padding-top: 24px;
  color: rgba(255, 255, 255, 0.45);
  font-size: 13px;
}

@media (max-width: 860px) {
  .footer__grid { grid-template-columns: 1fr 1fr; }
  .footer__brand { grid-column: 1 / -1; }
}
@media (max-width: 520px) {
  .footer__grid { grid-template-columns: 1fr; }
  .footer__stats { grid-template-columns: repeat(2, 1fr); gap: 24px; }
}
</style>
