<script setup>
import { RouterLink } from 'vue-router'
import { CreditCard, Gift, CalendarClock, Wallet } from 'lucide-vue-next'

const cards = [
  {
    icon: CreditCard,
    title: 'Loyallik kartalari, chegirma va cashback',
    description:
      "Doimiy mijozlarga loyallik kartasi bo'yicha chegirma bering. Tashriflar uchun ball yoki cashback yig'ish qaytishni rag'batlantiradi. Referal dastur bilan yangi mijoz jalb qiling.",
    to: '/loyalty/cards',
    guide: 'https://support.yclients.com/58-60-124',
  },
  {
    icon: Gift,
    title: 'Sertifikatlar',
    description:
      "Sotilgan sertifikatlarning bir qismi ishlatilmay qoladi, har to'rtinchisi yangi mijoz keltiradi. Sovg'a sertifikatlarini soting va boshqaring.",
    to: '/loyalty/certificates',
    guide: 'https://support.yclients.com/58-61-128',
  },
  {
    icon: CalendarClock,
    title: 'Abonementlar',
    description:
      "Belgilangan muddatli abonementlar mijozlarni tez-tez kelishga undaydi va xodimlar vaqtidan samarali foydalanishga yordam beradi.",
    to: '/loyalty/subscriptions',
    guide: 'https://support.yclients.com/58-62-764--tipy-abonementov',
  },
  {
    icon: Wallet,
    title: 'Mijoz depozitlari',
    description:
      "Depozit — eng sodiq mijozlar bilan alohida munosabat. Avans kiritgan mijoz albatta xizmatlaringizga sarflaydi.",
    to: '/loyalty/deposits',
    guide: 'https://support.yclients.com/49-54-441',
  },
]
</script>

<template>
  <div>
    <div class="page-head">
      <h1>Loyallik dasturi</h1>
    </div>

    <div class="hub-list">
      <div v-for="c in cards" :key="c.to" class="card hub-card">
        <div class="hub-icon">
          <component :is="c.icon" :size="26" />
        </div>
        <div class="hub-body">
          <h3 class="hub-title">{{ c.title }}</h3>
          <p class="hub-desc muted">{{ c.description }}</p>
        </div>
        <div class="hub-actions">
          <RouterLink :to="c.to" class="btn btn-primary">Sozlash</RouterLink>
          <a :href="c.guide" target="_blank" rel="noopener" class="hub-guide">
            Sozlash bo'yicha qo'llanma
          </a>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.hub-list {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.hub-card {
  display: flex;
  align-items: center;
  gap: 18px;
  padding: 20px;
}

.hub-icon {
  flex: 0 0 auto;
  width: 52px;
  height: 52px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
  background: var(--primary-soft);
  color: var(--primary);
}

.hub-body {
  flex: 1 1 auto;
  min-width: 0;
}

.hub-title {
  margin: 0 0 6px;
  font-size: 16px;
  font-weight: 700;
  color: var(--text);
}

.hub-desc {
  margin: 0;
  font-size: 13px;
  line-height: 1.5;
}

.hub-actions {
  flex: 0 0 auto;
  display: flex;
  flex-direction: column;
  align-items: stretch;
  gap: 8px;
  text-align: center;
  min-width: 180px;
}

.hub-guide {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-muted);
  text-decoration: none;
}
.hub-guide:hover {
  color: var(--primary);
  text-decoration: underline;
}

@media (max-width: 720px) {
  .hub-card {
    flex-direction: column;
    align-items: flex-start;
  }
  .hub-actions {
    width: 100%;
    min-width: 0;
  }
}
</style>
