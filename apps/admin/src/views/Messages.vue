<script setup>
// What the shop actually sent to clients: booking confirmations and reminders,
// with the channel each one went through and whether it arrived.
import { ref, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { RouterLink } from 'vue-router'
import { formatDateTime } from '../lib/datetime'

const CHANNELS = [
  { key: '', label: 'Barcha kanallar' },
  { key: 'sms', label: 'SMS' },
  { key: 'telegram', label: 'Telegram' },
]
const STATUSES = [
  { key: '', label: 'Barcha holatlar' },
  { key: 'queued', label: 'Navbatda' },
  { key: 'sent', label: 'Yuborildi' },
  { key: 'failed', label: 'Yuborilmadi' },
]

const channelLabels = { sms: 'SMS', telegram: 'Telegram' }
const templateLabels = { confirmation: 'Tasdiq', reminder: 'Eslatma' }
const statusLabels = { queued: 'Navbatda', sent: 'Yuborildi', failed: 'Yuborilmadi' }
const statusClass = { sent: 'completed', failed: 'canceled', queued: 'confirmed' }

const rows = ref([])
const meta = ref({ page: 1, pages: 1, total: 0 })
const filters = ref({ channel: '', status: '' })
const loading = ref(true)
const error = ref('')

async function load(page = 1) {
  loading.value = true
  error.value = ''
  try {
    const params = new URLSearchParams({ page: String(page) })
    if (filters.value.channel) params.set('channel', filters.value.channel)
    if (filters.value.status) params.set('status', filters.value.status)
    const res = await api.get('/v1/notifications?' + params.toString())
    rows.value = res?.data || res || []
    meta.value = res?.meta || { page, pages: 1, total: rows.value.length }
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Yuklab bo\'lmadi'
  } finally {
    loading.value = false
  }
}

function stamp(unix) {
  if (!unix) return '—'
  // The API returns unix seconds; formatDateTime speaks the UTC string shape.
  return formatDateTime(new Date(unix * 1000).toISOString().slice(0, 19).replace('T', ' '))
}

onMounted(() => load())
</script>

<template>
  <div>
    <div class="page-head">
      <h1>Xabarlar</h1>
      <RouterLink to="/settings" class="btn btn-sm">Sozlamalar</RouterLink>
    </div>

    <p class="muted" style="margin-top: -6px; margin-bottom: 16px">
      Mijozlarga yuborilgan tasdiq va eslatma xabarlari. Mijozda ulangan Telegram bo‘lsa
      Telegram orqali, aks holda SMS bilan ketadi.
    </p>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div class="toolbar">
      <select v-model="filters.channel" style="max-width: 200px" @change="load(1)">
        <option v-for="c in CHANNELS" :key="c.key" :value="c.key">{{ c.label }}</option>
      </select>
      <select v-model="filters.status" style="max-width: 200px" @change="load(1)">
        <option v-for="s in STATUSES" :key="s.key" :value="s.key">{{ s.label }}</option>
      </select>
      <button class="btn btn-sm" style="margin-left: auto" @click="load(meta.page)">Yangilash</button>
    </div>

    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

    <div v-else-if="!rows.length" class="empty card">
      Hali xabar yuborilmagan. Tasdiq va eslatmani
      <RouterLink to="/settings">Sozlamalar</RouterLink> da yoqasiz.
    </div>

    <div v-else class="table-wrap">
      <table class="data cards">
        <thead>
          <tr>
            <th>Vaqt</th>
            <th>Mijoz</th>
            <th>Turi</th>
            <th>Kanal</th>
            <th>Holat</th>
            <th>Yuborilgan</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in rows" :key="r.id">
            <td>{{ stamp(r.created_at) }}</td>
            <td>
              <strong>{{ r.client_name || '—' }}</strong>
              <div class="muted" style="font-size: 12px">{{ r.client_phone || '' }}</div>
            </td>
            <td data-label="Turi">{{ templateLabels[r.template] || r.template }}</td>
            <td data-label="Kanal">{{ channelLabels[r.channel] || r.channel }}</td>
            <td data-label="Holat">
              <span class="badge" :class="statusClass[r.status] || ''">
                {{ statusLabels[r.status] || r.status }}
              </span>
            </td>
            <td data-label="Yuborilgan">{{ stamp(r.sent_at) }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="meta.pages > 1" class="row" style="gap: 8px; margin-top: 14px; justify-content: center">
      <button class="btn btn-sm" :disabled="meta.page <= 1" @click="load(meta.page - 1)">‹</button>
      <span class="muted" style="font-size: 13px">{{ meta.page }} / {{ meta.pages }}</span>
      <button class="btn btn-sm" :disabled="meta.page >= meta.pages" @click="load(meta.page + 1)">›</button>
    </div>
  </div>
</template>

<style scoped>
.toolbar {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  margin-bottom: 14px;
}
</style>
