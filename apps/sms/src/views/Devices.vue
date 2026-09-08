<script setup>
import { ref, reactive, onMounted } from 'vue'
import { api, ApiError, config } from '@tizbiz/api-client'
import { Plus, Pencil, Trash2, Smartphone, Check } from 'lucide-vue-next'

// The self-hosted gateway's 3rd-party send base (the sender appends /message).
const DEFAULT_SERVER = `https://gate.${config.rootDomain || 'tizbiz.uz'}/api/3rdparty/v1`

const loading = ref(true)
const devices = ref([])
const available = ref([])
const claiming = ref('')

const modal = ref(false)
const editing = ref(null)
const form = reactive({ name: '', server: '', login: '', password: '', is_active: true })
const saving = ref(false)
const error = ref('')

async function load() {
  loading.value = true
  try {
    devices.value = await api.get('/v1/sms/devices')
  } finally {
    loading.value = false
  }
}
async function loadAvailable() {
  available.value = await api.get('/v1/sms/devices/available').catch(() => [])
}
async function claim(p) {
  claiming.value = p.device_id
  try {
    await api.post('/v1/sms/devices/claim', { device_id: p.device_id })
    await Promise.all([load(), loadAvailable()])
  } catch (e) {
    alert(e instanceof ApiError ? e.message : 'Qo‘shib bo‘lmadi')
  } finally {
    claiming.value = ''
  }
}
onMounted(() => Promise.all([load(), loadAvailable()]))

function openNew() {
  editing.value = null
  Object.assign(form, { name: '', server: DEFAULT_SERVER, login: '', password: '', is_active: true })
  error.value = ''
  modal.value = true
}
function openEdit(d) {
  editing.value = d
  Object.assign(form, { name: d.name, server: d.server || '', login: d.login || '', password: '', is_active: d.is_active })
  error.value = ''
  modal.value = true
}

async function save() {
  error.value = ''
  if (!form.name.trim()) { error.value = 'Nom kiriting'; return }
  saving.value = true
  try {
    const payload = {
      name: form.name.trim(),
      server: form.server.trim(),
      login: form.login.trim(),
      is_active: form.is_active,
    }
    if (form.password.trim()) payload.password = form.password.trim()
    if (editing.value) await api.patch('/v1/sms/devices/' + editing.value.id, payload)
    else await api.post('/v1/sms/devices', payload)
    modal.value = false
    await load()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Saqlab bo‘lmadi'
  } finally {
    saving.value = false
  }
}

async function remove(d) {
  if (!confirm(`"${d.name}" serverini o‘chirasizmi?`)) return
  await api.del('/v1/sms/devices/' + d.id)
  await load()
}
</script>

<template>
  <div class="page-head">
    <h2>Serverlar</h2>
    <button class="btn" @click="openNew"><Plus :size="16" /> Server qo‘shish</button>
  </div>

  <!-- Phones that announced themselves from the app — attach with one click -->
  <div v-if="available.length" class="card" style="margin-bottom: 16px; border: 1px solid var(--brand, #2d7eec)">
    <div class="row" style="align-items: center; gap: 6px; font-weight: 600">
      <Smartphone :size="16" /> Yangi telefonlar
      <span class="muted" style="font-weight: 500; font-size: 12px">— ilovada ro‘yxatdan o‘tgan, qo‘shishga tayyor</span>
    </div>
    <div class="table-wrap" style="margin-top: 10px">
      <table class="table">
        <thead><tr><th>Nom</th><th>SIM raqam</th><th>ID</th><th></th></tr></thead>
        <tbody>
          <tr v-for="p in available" :key="p.device_id">
            <td style="font-weight: 600">{{ p.name || 'Telefon' }}</td>
            <td class="muted">{{ p.sim_number || '—' }}</td>
            <td class="muted" style="font-size: 12px">{{ String(p.device_id).slice(0, 10) }}…</td>
            <td>
              <div class="row" style="justify-content: flex-end">
                <button class="btn sm" :disabled="claiming === p.device_id" @click="claim(p)">
                  <Check :size="14" /> {{ claiming === p.device_id ? '…' : 'Qo‘shish' }}
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>

  <div v-if="loading" class="spinner"></div>

  <div v-else-if="!devices.length" class="card empty">
    Hali server yo‘q. Android telefonga "SMS Gateway" ilovasini o‘rnatib, uning login/parolini shu yerga qo‘shing.
  </div>

  <div v-else class="table-wrap">
    <table class="table">
      <thead>
        <tr><th>Nom</th><th>Server</th><th>Login</th><th>Holat</th><th>Faol</th><th></th></tr>
      </thead>
      <tbody>
        <tr v-for="d in devices" :key="d.id">
          <td style="font-weight: 600">{{ d.name }}</td>
          <td class="muted">{{ d.server || 'Cloud (default)' }}</td>
          <td class="muted">{{ d.login || '—' }}<span v-if="!d.has_password" class="muted"> · parol yo‘q</span></td>
          <td><span class="badge" :class="d.status">{{ d.status === 'online' ? 'Online' : 'Offline' }}</span></td>
          <td>{{ d.is_active ? '✓' : '—' }}</td>
          <td>
            <div class="row" style="gap: 6px; justify-content: flex-end">
              <button class="btn ghost sm" @click="openEdit(d)"><Pencil :size="14" /></button>
              <button class="btn ghost sm" style="color: var(--danger)" @click="remove(d)"><Trash2 :size="14" /></button>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
  </div>

  <!-- Add/edit modal -->
  <div v-if="modal" class="modal-back" @click.self="modal = false">
    <div class="modal">
      <h3>{{ editing ? 'Serverni tahrirlash' : 'Yangi server' }}</h3>
      <div v-if="error" class="alert err">{{ error }}</div>
      <div class="field">
        <label>Nom</label>
        <input v-model="form.name" placeholder="POCO F3" />
      </div>
      <div class="field">
        <label>Server URL</label>
        <input v-model="form.server" :placeholder="DEFAULT_SERVER" />
        <p class="muted" style="font-size: 11px; margin: 6px 0 0">
          Odatda o‘zgartirmaysiz. Telefon ekranidagi <b>gate.tizbiz.uz:443</b> emas — to‘liq manzil kerak
          (avtomatik to‘g‘rilanadi).
        </p>
      </div>
      <div class="row" style="gap: 12px">
        <div class="field" style="flex: 1"><label>Login</label><input v-model="form.login" placeholder="username" /></div>
        <div class="field" style="flex: 1"><label>Parol</label><input v-model="form.password" type="password" :placeholder="editing ? '••• (o‘zgartirmaslik uchun bo‘sh)' : 'parol'" /></div>
      </div>
      <label class="row" style="gap: 8px; margin: 4px 0 16px; cursor: pointer">
        <input v-model="form.is_active" type="checkbox" style="width: auto" /> <span>Faol</span>
      </label>
      <div class="row" style="justify-content: flex-end; gap: 10px">
        <button class="btn ghost" @click="modal = false">Bekor</button>
        <button class="btn" :disabled="saving" @click="save">{{ saving ? 'Saqlanmoqda…' : 'Saqlash' }}</button>
      </div>
    </div>
  </div>
</template>
