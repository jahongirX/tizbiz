<script setup>
const LOGIN_URL = 'https://b.startup/'
const REGISTER_URL = 'https://b.startup/app/register'
const YEAR = 2026
</script>

<template>
  <footer class="footer">
    <div class="container footer__inner">
      <div class="footer__brand">
        <router-link to="/" class="brand">
          <span class="brand__mark">N</span>
          <span class="brand__name">Navbat</span>
        </router-link>
        <p>Surxondaryo va Termiz xizmat bizneslari uchun booking, brendlangan sayt va CRM — Telegram’da.</p>
      </div>

      <nav class="footer__col" aria-label="Sahifalar">
        <span class="footer__title">Platforma</span>
        <router-link to="/">Bosh sahifa</router-link>
        <router-link to="/how-it-works">Qanday ishlaydi</router-link>
        <router-link :to="{ path: '/', hash: '#pricing' }">Narxlar</router-link>
        <router-link to="/about">Loyiha haqida</router-link>
      </nav>

      <nav class="footer__col" aria-label="Resurslar">
        <span class="footer__title">Resurslar</span>
        <router-link to="/blog">Blog</router-link>
        <a :href="LOGIN_URL">Kirish</a>
        <a :href="REGISTER_URL">Boshlash</a>
      </nav>
    </div>

    <div class="container footer__bottom">
      <span>© {{ YEAR }} Navbat. Barcha huquqlar himoyalangan.</span>
      <span>Ishchi nom — brend keyin belgilanadi.</span>
    </div>
  </footer>
</template>

<style scoped>
.footer {
  border-top: 1px solid var(--border);
  padding: 56px 0 32px;
  background: var(--bg-soft);
}
.footer__inner {
  display: grid;
  grid-template-columns: 2fr 1fr 1fr;
  gap: 32px;
  margin-bottom: 32px;
}
.brand {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  font-weight: 700;
  font-size: 18px;
  letter-spacing: -0.01em;
}
.brand__mark {
  display: grid;
  place-items: center;
  width: 30px;
  height: 30px;
  border-radius: 9px;
  background: var(--accent);
  color: #fff;
  font-weight: 800;
}
.footer__brand p {
  color: var(--text-soft);
  font-size: 14px;
  margin: 14px 0 0;
  max-width: 340px;
}
.footer__col {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.footer__title {
  font-size: 13px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--text);
  margin-bottom: 2px;
}
.footer__col a {
  color: var(--text-soft);
  font-size: 14.5px;
  font-weight: 500;
}
.footer__col a:hover {
  color: var(--text);
}
.footer__bottom {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
  padding-top: 24px;
  border-top: 1px solid var(--border);
  color: var(--text-soft);
  font-size: 13px;
}

@media (max-width: 720px) {
  .footer__inner {
    grid-template-columns: 1fr 1fr;
  }
  .footer__brand {
    grid-column: 1 / -1;
  }
}
@media (max-width: 460px) {
  .footer__inner {
    grid-template-columns: 1fr;
  }
}
</style>
