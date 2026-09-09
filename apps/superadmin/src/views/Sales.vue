<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'

const TARIFF_PRICE = { start: 290000, pro: 590000, expert: 990000 }

const items = ref([])
const accounts = ref([])
const loading = ref(true)
const fmt = (n) => new Intl.NumberFormat('ru-RU').format(n || 0)
const dt = (t) => (t ? new Date(t * 1000).toLocaleDateString('ru-RU') : '—')
const total = computed(() => items.value.reduce((s, x) => s + (x.amount || 0), 0))
const todayISO = () => new Date().toISOString().slice(0, 10)

// new-contract modal
const open = ref(false)
const saving = ref(false)
const err = ref('')
const form = reactive({ account_id: '', name: '', phone: '', tariff: 'expert', amount: 990000, period_months: 12, starts_at: todayISO(), note: '' })

async function load() {
  loading.value = true
  try {
    const [sales, acc] = await Promise.all([
      api.get('/v1/superadmin/sales'),
      api.get('/v1/superadmin/sms-accounts').catch(() => ({ items: [] })),
    ])
    items.value = sales
    accounts.value = acc.items || []
  } finally { loading.value = false }
}
onMounted(load)

function openNew() {
  Object.assign(form, { account_id: '', name: '', phone: '', tariff: 'expert', amount: 990000, period_months: 12, starts_at: todayISO(), note: '' })
  err.value = ''
  open.value = true
}
function onAccount() {
  const a = accounts.value.find((x) => String(x.id) === String(form.account_id))
  if (a) { form.name = a.name || ''; form.phone = a.phone || '' }
}
function onTariff() { if (TARIFF_PRICE[form.tariff] != null) form.amount = TARIFF_PRICE[form.tariff] }

async function save() {
  err.value = ''
  if (!form.name.trim() && !form.phone.trim()) { err.value = 'Mijoz nomi yoki telefonini kiriting'; return }
  saving.value = true
  try {
    await api.post('/v1/superadmin/sales', {
      account_id: form.account_id || null,
      name: form.name.trim(),
      phone: form.phone.trim(),
      tariff: form.tariff,
      amount: Number(form.amount) || 0,
      period_months: Number(form.period_months) || 12,
      starts_at: form.starts_at || null,
      note: form.note.trim(),
    })
    open.value = false
    await load()
  } catch (e) {
    err.value = e instanceof ApiError ? e.message : 'Saqlab bo‘lmadi'
  } finally { saving.value = false }
}

async function remove(s) {
  if (!confirm('Shartnomani o‘chirasizmi?')) return
  await api.del('/v1/superadmin/sales/' + s.id)
  await load()
}

// Expiry badge from server-computed days_left.
function badge(s) {
  const d = s.days_left
  if (d == null) return { t: '—', c: 'muted' }
  if (d <= 0) return { t: 'Tugagan', c: 'b-red' }
  if (d <= 5) return { t: d + ' kun qoldi', c: 'b-red' }
  if (d <= 15) return { t: d + ' kun qoldi', c: 'b-orange' }
  if (d <= 30) return { t: d + ' kun qoldi', c: 'b-yellow' }
  return { t: 'Faol', c: 'b-green' }
}
</script>

<template>
  <div class="page-head" style="display:flex; align-items:center; justify-content:space-between">
    <h2>Shartnomalar <span class="muted" style="font-size:15px;font-weight:500">({{ items.length }})</span></h2>
    <button class="btn" @click="openNew">+ Yangi shartnoma</button>
  </div>

  <div class="card" style="margin-bottom:16px">
    <b style="font-size:22px">{{ fmt(total) }} so‘m</b> <span class="muted">— jami daromad</span>
  </div>

  <div v-if="loading" class="spinner"></div>
  <div v-else-if="!items.length" class="card empty">Hali shartnoma yo‘q. “+ Yangi shartnoma” yoki Arizalar bo‘limidan yarating.</div>

  <div v-else class="table-wrap">
    <table class="table">
      <thead><tr><th>Mijoz</th><th>Telefon</th><th>Tarif</th><th>Summa</th><th>Amal qiladi</th><th>Holat</th><th>Sana</th><th></th></tr></thead>
      <tbody>
        <tr v-for="s in items" :key="s.id">
          <td style="font-weight:600">{{ s.name || '—' }}</td>
          <td class="muted" style="white-space:nowrap">{{ s.phone || '—' }}</td>
          <td class="muted" style="text-transform:capitalize">{{ s.tariff || '—' }}</td>
          <td style="font-weight:600; white-space:nowrap">{{ fmt(s.amount) }} so‘m</td>
          <td class="muted" style="white-space:nowrap; font-size:12px">{{ dt(s.starts_at) }} – {{ dt(s.ends_at) }}<span class="muted" style="opacity:.7"> · {{ s.period_months }} oy</span></td>
          <td><span class="pill" :class="badge(s).c">{{ badge(s).t }}</span></td>
          <td class="muted" style="white-space:nowrap; font-size:12px">{{ dt(s.created_at) }}</td>
          <td><button class="btn ghost sm" style="color:var(--danger,#ef5350)" @click="remove(s)">🗑</button></td>
        </tr>
      </tbody>
    </table>
  </div>

  <!-- New contract modal -->
  <div v-if="open" class="modal-back" @click.self="open = false">
    <div class="modal">
      <h3>Yangi shartnoma</h3>
      <div v-if="err" class="alert err">{{ err }}</div>
      <div class="field"><label>Akkaunt (ixtiyoriy)</label>
        <select v-model="form.account_id" @change="onAccount">
          <option value="">— qo‘lda kiritish —</option>
          <option v-for="a in accounts" :key="a.id" :value="a.id">{{ a.name || a.phone }} ({{ a.phone }})</option>
        </select>
      </div>
      <div class="row" style="gap:12px">
        <div class="field" style="flex:1"><label>Mijoz</label><input v-model="form.name" placeholder="Nomi" /></div>
        <div class="field" style="flex:1"><label>Telefon</label><input v-model="form.phone" placeholder="+998…" /></div>
      </div>
      <div class="row" style="gap:12px">
        <div class="field" style="flex:1"><label>Tarif</label>
          <select v-model="form.tariff" @change="onTariff">
            <option value="start">Start</option><option value="pro">Pro</option><option value="expert">Expert</option>
          </select>
        </div>
        <div class="field" style="flex:1"><label>Summa (so‘m)</label><input v-model="form.amount" type="number" /></div>
      </div>
      <div class="row" style="gap:12px">
        <div class="field" style="flex:1"><label>Muddat (oy)</label><input v-model="form.period_months" type="number" /></div>
        <div class="field" style="flex:1"><label>Boshlanish sanasi</label><input v-model="form.starts_at" type="date" /></div>
      </div>
      <div class="field"><label>Izoh</label><input v-model="form.note" placeholder="ixtiyoriy" /></div>
      <div class="row" style="justify-content:flex-end; gap:10px">
        <button class="btn ghost" @click="open = false">Bekor</button>
        <button class="btn" :disabled="saving" @click="save">{{ saving ? '…' : 'Saqlash' }}</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.pill { display:inline-block; padding:3px 10px; border-radius:999px; font-size:12px; font-weight:600; white-space:nowrap; }
.b-green { background:#10331f; color:#4ade80; }
.b-yellow { background:#33300f; color:#facc15; }
.b-orange { background:#3a260f; color:#fb923c; }
.b-red { background:#3a1414; color:#f87171; }
</style>
