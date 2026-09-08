<script setup>
import { ref, computed, onMounted } from 'vue'
import { api } from '@tizbiz/api-client'

const items = ref([])
const loading = ref(true)
const fmt = (n) => new Intl.NumberFormat('ru-RU').format(n || 0)
const dt = (t) => (t ? new Date(t * 1000).toLocaleDateString('ru-RU') : '—')
const total = computed(() => items.value.reduce((s, x) => s + (x.amount || 0), 0))

async function load() {
  loading.value = true
  try { items.value = await api.get('/v1/superadmin/sales') } finally { loading.value = false }
}
onMounted(load)

async function remove(s) {
  if (!confirm('Sotuvni o‘chirasizmi?')) return
  await api.del('/v1/superadmin/sales/' + s.id)
  await load()
}
</script>

<template>
  <div class="page-head"><h2>Sotuvlar <span class="muted" style="font-size:15px;font-weight:500">({{ items.length }})</span></h2></div>

  <div class="card" style="margin-bottom:16px">
    <b style="font-size:22px">{{ fmt(total) }} so‘m</b> <span class="muted">— jami daromad</span>
  </div>

  <div v-if="loading" class="spinner"></div>
  <div v-else-if="!items.length" class="card empty">Hali sotuv yo‘q. Arizalar bo‘limida arizani “Sotuv”ga aylantiring.</div>

  <div v-else class="table-wrap">
    <table class="table">
      <thead><tr><th>Mijoz</th><th>Telefon</th><th>Tarif</th><th>Summa</th><th>Muddat</th><th>Amal qiladi</th><th>Sana</th><th></th></tr></thead>
      <tbody>
        <tr v-for="s in items" :key="s.id">
          <td style="font-weight:600">{{ s.name || '—' }}</td>
          <td class="muted" style="white-space:nowrap">{{ s.phone || '—' }}</td>
          <td class="muted" style="text-transform:capitalize">{{ s.tariff || '—' }}</td>
          <td style="font-weight:600; white-space:nowrap">{{ fmt(s.amount) }} so‘m</td>
          <td class="muted">{{ s.period_months }} oy</td>
          <td class="muted" style="white-space:nowrap; font-size:12px">{{ dt(s.starts_at) }} – {{ dt(s.ends_at) }}</td>
          <td class="muted" style="white-space:nowrap; font-size:12px">{{ dt(s.created_at) }}</td>
          <td><button class="btn ghost sm" style="color:var(--danger,#ef5350)" @click="remove(s)">🗑</button></td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
