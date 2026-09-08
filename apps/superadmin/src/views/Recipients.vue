<script setup>
import { ref, onMounted } from 'vue'
import { api } from '@tizbiz/api-client'

const items = ref([])
const total = ref(0)
const loading = ref(true)
const q = ref('')
const sort = ref('recent')
const fmt = (n) => new Intl.NumberFormat('ru-RU').format(n || 0)
const dt = (t) => new Date(t * 1000).toLocaleString('ru-RU', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' })

async function load() {
  loading.value = true
  try {
    const p = new URLSearchParams()
    if (q.value.trim()) p.set('q', q.value.trim())
    if (sort.value === 'count') p.set('sort', 'count')
    const r = await api.get('/v1/superadmin/recipients' + (p.toString() ? '?' + p : ''))
    items.value = r.items || []
    total.value = r.total || 0
  } finally { loading.value = false }
}
onMounted(load)

function exportCsv() {
  const rows = [['phone', 'send_count', 'last_seen'], ...items.value.map((x) => [x.phone, x.send_count, dt(x.last_seen_at)])]
  const csv = rows.map((r) => r.join(',')).join('\n')
  const b = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' })
  const u = URL.createObjectURL(b)
  const a = document.createElement('a')
  a.href = u; a.download = 'raqamlar.csv'; a.click()
  URL.revokeObjectURL(u)
}
</script>

<template>
  <div class="page-head">
    <h2>Raqamlar bazasi <span class="muted" style="font-size:15px;font-weight:500">({{ fmt(total) }})</span></h2>
    <button class="btn ghost" :disabled="!items.length" @click="exportCsv">Export CSV</button>
  </div>

  <div class="card" style="margin-bottom:16px">
    <div class="row" style="gap:12px; flex-wrap:wrap">
      <select v-model="sort" @change="load" style="width:auto">
        <option value="recent">Oxirgi yuborilgan</option>
        <option value="count">Eng ko‘p</option>
      </select>
      <input v-model="q" style="flex:1; min-width:200px" placeholder="Raqam bo‘yicha qidirish" @keyup.enter="load" />
      <button class="btn" @click="load">Qidirish</button>
    </div>
  </div>

  <div v-if="loading" class="spinner"></div>
  <div v-else-if="!items.length" class="card empty">Raqam yo‘q. Akkauntlar SMS yuborgach shu yerda to‘planadi.</div>

  <div v-else class="table-wrap">
    <table class="table">
      <thead><tr><th>Raqam</th><th>Yuborilgan</th><th>Oxirgi</th></tr></thead>
      <tbody>
        <tr v-for="x in items" :key="x.id">
          <td style="font-weight:600">+{{ x.phone }}</td>
          <td class="muted">{{ fmt(x.send_count) }} marta</td>
          <td class="muted" style="font-size:12px; white-space:nowrap">{{ dt(x.last_seen_at) }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
