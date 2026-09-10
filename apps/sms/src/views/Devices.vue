<script setup>
import { ref, reactive, onMounted, onUnmounted } from 'vue'
import { api, ApiError, config } from '@tizbiz/api-client'
import { Plus, Pencil, Trash2, Smartphone, Check, Phone } from 'lucide-vue-next'

// The self-hosted gateway's 3rd-party send base (the sender appends /message).
const DEFAULT_SERVER = `https://gate.${config.rootDomain || 'tizbiz.uz'}/api/3rdparty/v1`

const loading = ref(true)
const devices = ref([])
const available = ref([])
const claiming = ref('')

// Pairing (add-by-number + phone confirmation)
const pairModal = ref(false)
const pairPhone = ref('')
const pairState = ref('form') // form | waiting | error
const pairMsg = ref('')
const pairError = ref('')
let pollTimer = null
let pollDeadline = 0

// Manual (advanced) add / edit
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
onMounted(() => Promise.all([load(), loadAvailable()]))
onUnmounted(stopPolling)

// ---- Pairing ----
function openNew() {
  pairPhone.value = ''
  pairState.value = 'form'
  pairError.value = ''
  pairMsg.value = ''
  pairModal.value = true
}

async function startPairByPhone() {
  const phone = pairPhone.value.trim()
  if (!phone) { pairError.value = 'Telefon raqamini kiriting'; return }
  await requestPair({ phone })
}

// From the "Yangi telefonlar" list — request by device_id.
async function claim(p) {
  claiming.value = p.device_id
  pairModal.value = true
  try {
    await requestPair({ device_id: p.device_id, label: p.name || p.sim_number })
  } finally {
    claiming.value = ''
  }
}

async function requestPair(payload) {
  pairError.value = ''
  try {
    const before = new Set(devices.value.map((d) => d.id))
    const r = await api.post('/v1/sms/devices/claim', payload)
    pairState.value = 'waiting'
    pairMsg.value = (r.name || r.phone || payload.label || 'Telefon')
    startPolling(before)
  } catch (e) {
    pairState.value = 'error'
    pairError.value = e instanceof ApiError ? e.message : 'So‘rov yuborilmadi'
  }
}

function startPolling(beforeIds) {
  stopPolling()
  pollDeadline = Date.now() + 120000 // 2 min
  const tick = async () => {
    try {
      const list = await api.get('/v1/sms/devices')
      const fresh = list.find((d) => !beforeIds.has(d.id))
      if (fresh) {
        devices.value = list
        pairModal.value = false
        stopPolling()
        await loadAvailable()
        return
      }
    } catch { /* keep waiting */ }
    if (Date.now() > pollDeadline) {
      pairState.value = 'error'
      pairError.value = 'Tasdiqlanmadi. Telefondagi ilovada tasdiqlang va qayta urining.'
      stopPolling()
      return
    }
    pollTimer = setTimeout(tick, 3000)
  }
  pollTimer = setTimeout(tick, 3000)
}
function stopPolling() {
  if (pollTimer) { clearTimeout(pollTimer); pollTimer = null }
}
function closePair() {
  stopPolling()
  pairModal.value = false
}

// ---- Manual add / edit ----
function openManual() {
  pairModal.value = false
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

  <div v-if="available.length" class="card" style="margin-bottom: 16px; border: 1px solid var(--brand, #2d7eec)">
    <div class="row" style="align-items: center; gap: 6px; font-weight: 600">
      <Smartphone :size="16" /> Yangi telefonlar
      <span class="muted" style="font-weight: 500; font-size: 12px">— faqat sizning raqamingizga tegishli, qo‘shishga tayyor</span>
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
    Hali server yo‘q. Android telefonga <b>TizBiz SMS</b> ilovasini o‘rnatib, raqamni kiriting —
    keyin shu yerda “Server qo‘shish” tugmasi orqali raqam bo‘yicha ulang.
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

  <!-- Pair-by-number modal -->
  <div v-if="pairModal" class="modal-back" @click.self="closePair">
    <div class="modal">
      <template v-if="pairState === 'form'">
        <h3>Server qo‘shish</h3>
        <p class="muted" style="font-size: 13px; margin: 0 0 14px">
          Telefon raqamini kiriting. Qolgan ma’lumotlar (login, parol, server) shu raqamga
          moslab avtomatik olinadi.
        </p>
        <div v-if="pairError" class="alert err">{{ pairError }}</div>
        <div class="field">
          <label>Telefon raqami</label>
          <input v-model="pairPhone" type="tel" placeholder="+998 90 123 45 67" @keyup.enter="startPairByPhone" />
        </div>
        <div class="row" style="justify-content: space-between; gap: 10px; margin-top: 4px">
          <button class="btn ghost sm" @click="openManual">Qo‘lda kiritish</button>
          <div class="row" style="gap: 10px">
            <button class="btn ghost" @click="closePair">Bekor</button>
            <button class="btn" @click="startPairByPhone"><Phone :size="15" /> Qo‘shish</button>
          </div>
        </div>
      </template>

      <template v-else-if="pairState === 'waiting'">
        <h3>📲 Telefonda tasdiqlang</h3>
        <div class="spinner" style="margin: 10px auto"></div>
        <p style="text-align: center; margin: 6px 0 2px"><b>{{ pairMsg }}</b></p>
        <p class="muted" style="text-align: center; font-size: 13px; margin: 0 0 16px">
          Telefonga tasdiqlash so‘rovi yuborildi. Ilovadagi bildirishnomani oching va
          <b>“Tasdiqlash”</b>ni bosing — shundan so‘ng server ulanadi.
        </p>
        <div class="row" style="justify-content: center">
          <button class="btn ghost" @click="closePair">Bekor</button>
        </div>
      </template>

      <template v-else>
        <h3>Ulanmadi</h3>
        <div class="alert err">{{ pairError }}</div>
        <div class="row" style="justify-content: flex-end; gap: 10px">
          <button class="btn ghost" @click="closePair">Yopish</button>
          <button class="btn" @click="pairState = 'form'">Qayta urinish</button>
        </div>
      </template>
    </div>
  </div>

  <!-- Manual add / edit modal -->
  <div v-if="modal" class="modal-back" @click.self="modal = false">
    <div class="modal">
      <h3>{{ editing ? 'Serverni tahrirlash' : 'Qo‘lda server qo‘shish' }}</h3>
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
