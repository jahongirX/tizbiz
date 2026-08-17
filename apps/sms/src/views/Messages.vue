<script setup>
import { ref, onMounted } from 'vue'
import { api } from '@tizbiz/api-client'

const loading = ref(true)
const items = ref([])
const total = ref(0)
const limit = 50
const offset = ref(0)
const fStatus = ref('')
const fPhone = ref('')

const STATUS_LABEL = { sent: 'Yuborildi', failed: 'Xato', pending: 'Kutilmoqda' }

function fmt(ts) {
  if (!ts) return '—'
  return new Date(ts * 1000).toLocaleString('uz-UZ', { timeZone: 'Asia/Tashkent', dateStyle: 'short', timeStyle: 'short' })
}

async function load() {
  loading.value = true
  try {
    const params = new URLSearchParams({ limit: String(limit), offset: String(offset.value) })
    if (fStatus.value) params.set('status', fStatus.value)
    if (fPhone.value.trim()) params.set('phone', fPhone.value.trim())
    const res = await api.get('/v1/sms/messages?' + params.toString())
    items.value = res.items || []
    total.value = res.total || 0
  } finally {
    loading.value = false
  }
}
onMounted(load)

function search() { offset.value = 0; load() }
function prev() { if (offset.value > 0) { offset.value = Math.max(0, offset.value - limit); load() } }
function next() { if (offset.value + limit < total.value) { offset.value += limit; load() } }
</script>

<template>
  <div class="page-head"><h2>Xabarlar <span class="muted" style="font-size: 15px; font-weight: 500">({{ total }})</span></h2></div>

  <div class="card" style="margin-bottom: 16px">
    <div class="row" style="gap: 12px; flex-wrap: wrap">
      <select v-model="fStatus" style="width: auto" @change="search">
        <option value="">Barcha holat</option>
        <option value="sent">Yuborildi</option>
        <option value="failed">Xato</option>
        <option value="pending">Kutilmoqda</option>
      </select>
      <input v-model="fPhone" style="width: auto; flex: 1; min-width: 180px" placeholder="Raqam bo‘yicha qidirish" @keyup.enter="search" />
      <button class="btn" @click="search">Qidirish</button>
    </div>
  </div>

  <div v-if="loading" class="spinner"></div>
  <div v-else-if="!items.length" class="card empty">Xabar topilmadi.</div>

  <template v-else>
    <div class="table-wrap">
      <table class="table">
        <thead>
          <tr><th>Raqam</th><th>Xabar</th><th>Holat</th><th>Sana</th></tr>
        </thead>
        <tbody>
          <tr v-for="m in items" :key="m.id">
            <td style="font-weight: 600; white-space: nowrap">{{ m.phone }}</td>
            <td style="max-width: 420px">
              {{ m.text }}
              <div v-if="m.error" class="muted" style="font-size: 12px; color: var(--danger)">{{ m.error }}</div>
            </td>
            <td><span class="badge" :class="m.status">{{ STATUS_LABEL[m.status] || m.status }}</span></td>
            <td class="muted" style="white-space: nowrap">{{ fmt(m.sent_at || m.created_at) }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="row" style="justify-content: flex-end; gap: 10px; margin-top: 14px">
      <button class="btn ghost sm" :disabled="offset === 0" @click="prev">‹ Oldingi</button>
      <span class="muted" style="font-size: 13px">{{ offset + 1 }}–{{ Math.min(offset + limit, total) }} / {{ total }}</span>
      <button class="btn ghost sm" :disabled="offset + limit >= total" @click="next">Keyingi ›</button>
    </div>
  </template>
</template>
