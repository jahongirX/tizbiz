<script setup>
import { ref, onMounted } from 'vue'
import { api } from '@tizbiz/api-client'

const r = ref(null)
const loading = ref(true)
const fmt = (n) => new Intl.NumberFormat('ru-RU').format(n || 0)

onMounted(async () => {
  try { r.value = await api.get('/v1/superadmin/report') } finally { loading.value = false }
})
</script>

<template>
  <div class="page-head"><h2>Boshqaruv</h2></div>

  <div v-if="loading" class="spinner"></div>

  <template v-else-if="r">
    <div class="sa-stats">
      <div class="sa-stat"><div class="v">{{ fmt(r.revenue_month) }}</div><div class="l">Bu oy daromad (so‘m)</div></div>
      <div class="sa-stat"><div class="v">{{ fmt(r.revenue_total) }}</div><div class="l">Jami daromad</div></div>
      <div class="sa-stat"><div class="v">{{ r.sales_count }}</div><div class="l">Sotuvlar</div></div>
      <div class="sa-stat"><div class="v">{{ r.accounts_active }}/{{ r.accounts_total }}</div><div class="l">Faol akkauntlar</div></div>
      <div class="sa-stat"><div class="v">{{ fmt(r.sms_today) }}</div><div class="l">Bugun SMS</div></div>
      <div class="sa-stat"><div class="v">{{ fmt(r.sms_month) }}</div><div class="l">Bu oy SMS</div></div>
      <div class="sa-stat"><div class="v">{{ fmt(r.recipients) }}</div><div class="l">Bazadagi raqamlar</div></div>
      <div class="sa-stat"><div class="v">{{ r.conversion }}%</div><div class="l">Ariza → sotuv</div></div>
    </div>

    <div class="sa-grid2">
      <div class="card">
        <h3 style="margin:0 0 12px">Arizalar voronkasi</h3>
        <div class="sa-fr"><span>🆕 Yangi</span><b>{{ r.leads.new }}</b></div>
        <div class="sa-fr"><span>📞 Bog‘lanildi</span><b>{{ r.leads.contacted }}</b></div>
        <div class="sa-fr"><span>✅ Sotildi</span><b>{{ r.leads.won }}</b></div>
        <div class="sa-fr"><span>❌ Rad</span><b>{{ r.leads.lost }}</b></div>
      </div>
      <div class="card">
        <h3 style="margin:0 0 12px">Top akkauntlar (bu oy)</h3>
        <div v-if="!r.top_accounts.length" class="muted">Ma’lumot yo‘q</div>
        <div v-for="t in r.top_accounts" :key="t.name" class="sa-fr"><span>{{ t.name }}</span><b>{{ fmt(t.count) }}</b></div>
      </div>
    </div>
  </template>
</template>

<style scoped>
.sa-stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; margin-bottom: 16px; }
.sa-stat { background: #111c30; border: 1px solid #1f2b44; border-radius: 14px; padding: 18px; }
.sa-stat .v { font-size: 24px; font-weight: 800; }
.sa-stat .l { color: #93a1bd; font-size: 12px; margin-top: 4px; }
.sa-grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
.sa-fr { display: flex; justify-content: space-between; align-items: center; padding: 9px 0; border-bottom: 1px solid #1f2b44; }
.sa-fr:last-child { border-bottom: 0; }
.sa-fr b { font-weight: 700; }
@media (max-width: 800px) { .sa-stats { grid-template-columns: repeat(2, 1fr); } .sa-grid2 { grid-template-columns: 1fr; } }
</style>
