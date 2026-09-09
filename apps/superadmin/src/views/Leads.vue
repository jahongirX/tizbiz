<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'

const STATUS = { new: 'Yangi', contacted: 'Bog‘lanildi', won: 'Sotildi', lost: 'Rad' }
const TARIFF_PRICE = { start: 290000, pro: 590000, expert: 990000 }

const items = ref([])
const loading = ref(true)
const filter = ref('')

// sale modal
const saleOpen = ref(false)
const saleLead = ref(null)
const todayISO = () => new Date().toISOString().slice(0, 10)
const sale = reactive({ tariff: 'pro', amount: 590000, period_months: 12, starts_at: todayISO(), note: '' })
const saleSaving = ref(false)
const saleErr = ref('')

const shown = computed(() => (filter.value ? items.value.filter((l) => l.status === filter.value) : items.value))
const fmt = (n) => new Intl.NumberFormat('ru-RU').format(n || 0)
const dt = (t) => new Date(t * 1000).toLocaleString('ru-RU', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' })

async function load() {
  loading.value = true
  try { items.value = await api.get('/v1/superadmin/leads') } finally { loading.value = false }
}
onMounted(load)

async function setStatus(l, status) {
  l.status = status
  await api.patch('/v1/superadmin/leads/' + l.id, { status })
}
async function remove(l) {
  if (!confirm('Arizani o‘chirasizmi?')) return
  await api.del('/v1/superadmin/leads/' + l.id)
  await load()
}

function openSale(l) {
  saleLead.value = l
  const t = l.tariff && TARIFF_PRICE[l.tariff] ? l.tariff : 'pro'
  Object.assign(sale, { tariff: t, amount: TARIFF_PRICE[t], period_months: 12, starts_at: todayISO(), note: '' })
  saleErr.value = ''
  saleOpen.value = true
}
function onTariff() { sale.amount = TARIFF_PRICE[sale.tariff] ?? sale.amount }
async function saveSale() {
  saleErr.value = ''
  saleSaving.value = true
  try {
    await api.post('/v1/superadmin/sales', {
      lead_id: saleLead.value.id,
      name: saleLead.value.name,
      phone: saleLead.value.phone,
      tariff: sale.tariff,
      amount: Number(sale.amount) || 0,
      period_months: Number(sale.period_months) || 12,
      starts_at: sale.starts_at || null,
      note: sale.note.trim(),
    })
    saleOpen.value = false
    await load()
  } catch (e) {
    saleErr.value = e instanceof ApiError ? e.message : 'Saqlab bo‘lmadi'
  } finally {
    saleSaving.value = false
  }
}
</script>

<template>
  <div class="page-head"><h2>Arizalar <span class="muted" style="font-size:15px;font-weight:500">({{ items.length }})</span></h2></div>

  <div class="card" style="margin-bottom:16px">
    <div class="row" style="gap:8px; flex-wrap:wrap">
      <button class="btn" :class="filter === '' ? '' : 'ghost'" @click="filter = ''">Barcha</button>
      <button v-for="(lbl, k) in STATUS" :key="k" class="btn" :class="filter === k ? '' : 'ghost'" @click="filter = k">{{ lbl }}</button>
    </div>
  </div>

  <div v-if="loading" class="spinner"></div>
  <div v-else-if="!shown.length" class="card empty">Ariza yo‘q.</div>

  <div v-else class="table-wrap">
    <table class="table">
      <thead><tr><th>Ism</th><th>Telefon</th><th>Biznes</th><th>Tarif</th><th>Holat</th><th>Sana</th><th></th></tr></thead>
      <tbody>
        <tr v-for="l in shown" :key="l.id">
          <td style="font-weight:600">{{ l.name || '—' }}</td>
          <td class="muted" style="white-space:nowrap">{{ l.phone }}</td>
          <td class="muted">{{ l.business || '—' }}</td>
          <td class="muted" style="text-transform:capitalize">{{ l.tariff || '—' }}</td>
          <td>
            <select :value="l.status" @change="setStatus(l, $event.target.value)" style="width:auto">
              <option v-for="(lbl, k) in STATUS" :key="k" :value="k">{{ lbl }}</option>
            </select>
          </td>
          <td class="muted" style="white-space:nowrap; font-size:12px">{{ dt(l.created_at) }}</td>
          <td>
            <div class="row" style="gap:6px; justify-content:flex-end">
              <button class="btn sm" @click="openSale(l)">Shartnoma</button>
              <button class="btn ghost sm" style="color:var(--danger,#ef5350)" @click="remove(l)">🗑</button>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
  </div>

  <!-- Sale modal -->
  <div v-if="saleOpen" class="modal-back" @click.self="saleOpen = false">
    <div class="modal">
      <h3>Shartnoma tuzish</h3>
      <p class="muted" style="font-size:13px; margin:0 0 14px">{{ saleLead?.name }} · {{ saleLead?.phone }}</p>
      <div v-if="saleErr" class="alert err">{{ saleErr }}</div>
      <div class="field"><label>Tarif</label>
        <select v-model="sale.tariff" @change="onTariff">
          <option value="start">Start</option><option value="pro">Pro</option><option value="expert">Expert</option>
        </select>
      </div>
      <div class="row" style="gap:12px">
        <div class="field" style="flex:1"><label>Summa (so‘m)</label><input v-model="sale.amount" type="number" /></div>
        <div class="field" style="flex:1"><label>Muddat (oy)</label><input v-model="sale.period_months" type="number" /></div>
      </div>
      <div class="field"><label>Boshlanish sanasi</label><input v-model="sale.starts_at" type="date" /></div>
      <div class="field"><label>Izoh</label><input v-model="sale.note" placeholder="ixtiyoriy" /></div>
      <div class="row" style="justify-content:flex-end; gap:10px">
        <button class="btn ghost" @click="saleOpen = false">Bekor</button>
        <button class="btn" :disabled="saleSaving" @click="saveSale">{{ saleSaving ? '…' : 'Shartnomani saqlash' }}</button>
      </div>
    </div>
  </div>
</template>
