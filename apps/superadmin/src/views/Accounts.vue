<script setup>
import { ref, reactive, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { Plus, Pencil, Trash2, KeyRound, Copy, RefreshCw } from 'lucide-vue-next'

const loading = ref(true)
const items = ref([])

const modal = ref(false)
const editing = ref(null)
const form = reactive({ name: '', phone: '+998', password: '', quota_monthly: 0, note: '', is_active: true })
const saving = ref(false)
const error = ref('')

async function load() {
  loading.value = true
  try {
    const res = await api.get('/v1/superadmin/sms-accounts')
    items.value = res.items || []
  } finally {
    loading.value = false
  }
}
onMounted(load)

function openNew() {
  editing.value = null
  Object.assign(form, { name: '', phone: '+998', password: '', quota_monthly: 0, note: '', is_active: true })
  error.value = ''
  modal.value = true
}
function openEdit(a) {
  editing.value = a
  Object.assign(form, {
    name: a.name || '',
    phone: a.phone || '',
    password: '',
    quota_monthly: a.quota_monthly,
    note: a.note || '',
    is_active: a.is_active,
  })
  error.value = ''
  modal.value = true
}

async function save() {
  error.value = ''
  if (!form.name.trim()) { error.value = 'Nom kiriting'; return }
  if (!editing.value && form.password.length < 5) { error.value = 'Parol kamida 5 ta belgi'; return }
  saving.value = true
  try {
    if (editing.value) {
      await api.patch('/v1/superadmin/sms-accounts/' + editing.value.id, {
        name: form.name.trim(),
        quota_monthly: Number(form.quota_monthly) || 0,
        is_active: form.is_active,
        note: form.note.trim(),
      })
    } else {
      await api.post('/v1/superadmin/sms-accounts', {
        name: form.name.trim(),
        phone: form.phone.trim(),
        password: form.password,
        quota_monthly: Number(form.quota_monthly) || 0,
        note: form.note.trim(),
      })
    }
    modal.value = false
    await load()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Saqlab bo‘lmadi'
  } finally {
    saving.value = false
  }
}

async function resetPassword(a) {
  const p = prompt(`"${a.name}" uchun yangi parol (kamida 5 ta belgi):`)
  if (!p) return
  try {
    await api.post('/v1/superadmin/sms-accounts/' + a.id + '/password', { password: p })
    alert('✓ Parol yangilandi')
  } catch (e) {
    alert(e instanceof ApiError ? e.message : 'Xatolik')
  }
}

async function remove(a) {
  if (!confirm(`"${a.name}" SMS akkauntini o‘chirasizmi?\n(login qoladi, faqat SMS ruxsati olib tashlanadi)`)) return
  await api.del('/v1/superadmin/sms-accounts/' + a.id)
  await load()
}

const copiedId = ref(null)
async function copyKey(a) {
  if (!a.api_key) return
  try {
    await navigator.clipboard.writeText(a.api_key)
    copiedId.value = a.id
    setTimeout(() => (copiedId.value = null), 1500)
  } catch { /* clipboard blocked */ }
}

async function regenKey(a) {
  if (!confirm(`"${a.name}" uchun yangi API kalit yaratilsinmi?\nEski kalit ishlamay qoladi.`)) return
  try {
    const res = await api.post('/v1/superadmin/sms-accounts/' + a.id + '/apikey')
    a.api_key = res.api_key
    await copyKey(a)
    alert('✓ Yangi kalit yaratildi va nusxalandi')
  } catch (e) {
    alert(e instanceof ApiError ? e.message : 'Xatolik')
  }
}

const quotaText = (a) => (a.quota_monthly > 0 ? `${a.usage} / ${a.quota_monthly}` : `${a.usage} / ∞`)
</script>

<template>
  <div class="page-head">
    <h2>SMS Akkauntlar <span class="muted" style="font-size: 15px; font-weight: 500">({{ items.length }})</span></h2>
    <button class="btn" @click="openNew"><Plus :size="16" /> Akkaunt yaratish</button>
  </div>

  <div v-if="loading" class="spinner"></div>

  <div v-else-if="!items.length" class="card empty">
    Hali SMS akkaunt yo‘q. Har mijozga login/parol yarating — ular sms.tizbiz.uz'ga kirib o‘z panelidan foydalanadi.
  </div>

  <div v-else class="table-wrap">
    <table class="table">
      <thead>
        <tr><th>Nom</th><th>Login (telefon)</th><th>API kalit</th><th>Kvota (bu oy)</th><th>Holat</th><th>Izoh</th><th></th></tr>
      </thead>
      <tbody>
        <tr v-for="a in items" :key="a.id">
          <td style="font-weight: 600">{{ a.name }}</td>
          <td class="muted" style="white-space: nowrap">{{ a.phone }}</td>
          <td>
            <button
              v-if="a.api_key"
              class="keychip"
              :title="'Nusxa olish: ' + a.api_key"
              @click="copyKey(a)"
            >
              <Copy :size="12" />
              <span>{{ copiedId === a.id ? 'Nusxalandi ✓' : a.api_key.slice(0, 10) + '…' }}</span>
            </button>
            <span v-else class="muted">—</span>
          </td>
          <td :style="{ color: a.remaining === 0 ? 'var(--danger)' : 'inherit' }">
            {{ quotaText(a) }}
          </td>
          <td>
            <span class="badge" :class="a.is_active ? 'online' : 'offline'">
              {{ a.is_active ? 'Faol' : 'Bloklangan' }}
            </span>
          </td>
          <td class="muted">{{ a.note || '—' }}</td>
          <td>
            <div class="row" style="gap: 6px; justify-content: flex-end">
              <button class="btn ghost sm" title="Yangi API kalit" @click="regenKey(a)"><RefreshCw :size="14" /></button>
              <button class="btn ghost sm" title="Parolni tiklash" @click="resetPassword(a)"><KeyRound :size="14" /></button>
              <button class="btn ghost sm" title="Tahrirlash" @click="openEdit(a)"><Pencil :size="14" /></button>
              <button class="btn ghost sm" style="color: var(--danger)" title="O‘chirish" @click="remove(a)"><Trash2 :size="14" /></button>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
  </div>

  <!-- Create / edit modal -->
  <div v-if="modal" class="modal-back" @click.self="modal = false">
    <div class="modal">
      <h3>{{ editing ? 'Akkauntni tahrirlash' : 'Yangi SMS akkaunt' }}</h3>
      <div v-if="error" class="alert err">{{ error }}</div>

      <div class="field">
        <label>Nom (mijoz / kompaniya)</label>
        <input v-model="form.name" placeholder="Aziza Tortlari" />
      </div>

      <div class="row" style="gap: 12px">
        <div class="field" style="flex: 1">
          <label>Login (telefon)</label>
          <input v-model="form.phone" :disabled="!!editing" placeholder="+998901234567" />
        </div>
        <div class="field" style="flex: 1">
          <label>Oylik kvota (0 = cheksiz)</label>
          <input v-model.number="form.quota_monthly" type="number" min="0" placeholder="0" />
        </div>
      </div>

      <div v-if="!editing" class="field">
        <label>Parol</label>
        <input v-model="form.password" type="text" placeholder="kamida 5 ta belgi" />
      </div>

      <label v-if="editing" class="row" style="gap: 8px; margin: 4px 0 12px; cursor: pointer">
        <input v-model="form.is_active" type="checkbox" style="width: auto" /> <span>Faol</span>
      </label>

      <div class="field">
        <label>Izoh (ixtiyoriy)</label>
        <input v-model="form.note" placeholder="Eslatma" />
      </div>

      <div class="row" style="justify-content: flex-end; gap: 10px">
        <button class="btn ghost" @click="modal = false">Bekor</button>
        <button class="btn" :disabled="saving" @click="save">{{ saving ? 'Saqlanmoqda…' : 'Saqlash' }}</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.keychip {
  display: inline-flex; align-items: center; gap: 5px;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px;
  padding: 3px 8px; border-radius: 6px; cursor: pointer;
  border: 1px solid var(--border, #e2e8f0); background: rgba(127, 127, 127, 0.06); color: inherit;
}
.keychip:hover { background: rgba(127, 127, 127, 0.14); }
</style>
