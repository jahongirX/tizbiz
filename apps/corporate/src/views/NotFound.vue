<script setup>
import { RouterLink } from 'vue-router'
</script>

<template>
  <main class="container notfound">
    <span class="tag">404</span>
    <h1>Sahifa topilmadi</h1>
    <p>Siz izlagan sahifa mavjud emas yoki ko‘chirilgan. Bosh sahifadan davom eting.</p>
    <div class="notfound__actions">
      <router-link class="btn btn-primary btn-lg" to="/">Bosh sahifaga</router-link>
      <router-link class="btn btn-ghost btn-lg" to="/blog">Blogni ochish</router-link>
    </div>
  </main>
</template>

<style scoped>
.notfound {
  text-align: center;
  padding: 110px 20px 120px;
}
.notfound h1 {
  font-size: clamp(30px, 6vw, 48px);
  letter-spacing: -0.02em;
  margin: 18px 0 12px;
}
.notfound p {
  color: var(--text-soft);
  max-width: 480px;
  margin: 0 auto 26px;
  font-size: 17px;
}
.notfound__actions {
  display: flex;
  gap: 12px;
  justify-content: center;
  flex-wrap: wrap;
}
</style>
