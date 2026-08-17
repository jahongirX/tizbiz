<script setup>
import { ref, reactive, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { Plus, Trash2 } from 'lucide-vue-next'

const loading = ref(true)
const items = ref([])

const modal = ref(false)
const form = reactive({ phone: '', reason: '' })
const saving = ref(false)
const error = ref('')

function fmt(ts) {
  if (!ts) return '—'
  return new Date(ts * 1000).toLocaleString('uz-UZ', { timeZone: 'Asia/Tashkent', dateStyle: 'short', timeStyle: 'short' })
}

async function load() {
  loading.value = true
  try {
    items.value = await api.get('/v1/sms/blacklist')
  } finally {
    loading.value = false
  }
}
onMounted(load)

function openNew() {
  Object.assign(form, { phone: '', reason: '' })
  error.value = ''
  modal.value = true
}

async function save() {
  error.value = ''
  if (!form.phone.trim()) { error.value = 'Raqam kiriting'; return }
  saving.value = true
  try {
    await api.post('/v1/sms/blacklist', { phone: form.phone.trim(), reason: form.reason.trim() })
    modal.value = false
    await load()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Saqlab bo‘lmadi'
  } finally {
    saving.value = false
  }
}

async function remove(b) {
  if (!confirm(`"${b.phone}" ni qora ro‘yxatdan chiqarasizmi?`)) return
  await api.del('/v1/sms/blacklist/' + b.id)
  await load()
}
</script>

<template>
  <div class="page-head">
    <h2>Qora ro‘yxat <span class="muted" style="font-size: 15px; font-weight: 500">({{ items.length }})</span></h2>
    <button class="btn" @click="openNew"><Plus :size="16" /> Raqam qo‘shish</button>
  </div>

  <p class="muted" style="font-size: 13px; margin: -6px 0 16px">
    Bu ro‘yxatdagi raqamlarga xabar yuborilmaydi — yuborishda avtomatik chetlab o‘tiladi.
  </p>

  <div v-if="loading" class="spinner"></div>

  <div v-else-if="!items.length" class="card empty">Qora ro‘yxat bo‘sh.</div>

  <div v-else class="table-wrap">
    <table class="table">
      <thead>
        <tr><th>Raqam</th><th>Sabab</th><th>Sana</th><th></th></tr>
      </thead>
      <tbody>
        <tr v-for="b in items" :key="b.id">
          <td style="font-weight: 600; white-space: nowrap">{{ b.phone }}</td>
          <td class="muted">{{ b.reason || '—' }}</td>
          <td class="muted" style="white-space: nowrap">{{ fmt(b.created_at) }}</td>
          <td>
            <div class="row" style="gap: 6px; justify-content: flex-end">
              <button class="btn ghost sm" style="color: var(--danger)" @click="remove(b)"><Trash2 :size="14" /></button>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
  </div>

  <!-- Add modal -->
  <div v-if="modal" class="modal-back" @click.self="modal = false">
    <div class="modal">
      <h3>Qora ro‘yxatga qo‘shish</h3>
      <div v-if="error" class="alert err">{{ error }}</div>
      <div class="field">
        <label>Raqam</label>
        <input v-model="form.phone" placeholder="+998901234567" />
      </div>
      <div class="field">
        <label>Sabab (ixtiyoriy)</label>
        <input v-model="form.reason" placeholder="So‘rov bo‘yicha, spam…" />
      </div>
      <div class="row" style="justify-content: flex-end; gap: 10px">
        <button class="btn ghost" @click="modal = false">Bekor</button>
        <button class="btn" :disabled="saving" @click="save">{{ saving ? 'Saqlanmoqda…' : 'Saqlash' }}</button>
      </div>
    </div>
  </div>
</template>
