<script setup>
import { ref, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { somToTiyin, tiyinToSom, formatSom } from '../lib/money'
import { formatDateTime } from '../lib/datetime'
import { confirm } from '../composables/useConfirm'
import Modal from '../components/Modal.vue'

// ---- List state ----
const loading = ref(true)
const error = ref('')
const rows = ref([])
const meta = ref({ page: 1, per_page: 20, total: 0, pages: 1 })

const search = ref('')
const lowOnly = ref(false)
const page = ref(1)
let searchTimer = null

// ---- Summary ----
const summary = ref({ total: 0, low_stock_count: 0, stock_value_tiyin: 0 })

// ---- Create / edit modal ----
const showModal = ref(false)
const saving = ref(false)
const formError = ref('')
const fieldErrors = ref({})
const editing = ref(null)
const form = ref(blank())

// ---- Stock adjust modal ----
const showStock = ref(false)
const stockSaving = ref(false)
const stockError = ref('')
const stockTarget = ref(null)
const stockForm = ref(blankStock())
const movements = ref([])
const movLoading = ref(false)

const stockTypes = [
  { key: 'in', label: 'Kirim' },
  { key: 'out', label: 'Chiqim' },
  { key: 'writeoff', label: 'Hisobdan chiqarish' },
  { key: 'adjust', label: 'Tuzatish' },
]
const typeLabels = {
  in: 'Kirim',
  out: 'Chiqim',
  writeoff: 'Hisobdan chiqarish',
  adjust: 'Tuzatish',
  sale: 'Sotuv',
}

function blank() {
  return {
    name: '',
    unit: 'dona',
    price_som: '',
    cost_som: '',
    stock_qty: 0,
    low_stock: 0,
    is_active: true,
  }
}

function blankStock() {
  return { type: 'in', qty: '', new_qty: '', reason: '' }
}

function isLow(p) {
  return Number(p.stock_qty) <= Number(p.low_stock)
}

// ---- Loading ----
async function loadSummary() {
  try {
    const res = await api.get('/v1/products/summary')
    const s = res?.data || res || {}
    summary.value = {
      total: s.total ?? 0,
      low_stock_count: s.low_stock_count ?? 0,
      stock_value_tiyin: s.stock_value_tiyin ?? 0,
    }
  } catch {
    // Summary is non-critical; leave defaults.
  }
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const params = new URLSearchParams()
    const q = search.value.trim()
    if (q) params.set('search', q)
    if (lowOnly.value) params.set('low_stock', '1')
    params.set('page', String(page.value))
    params.set('per_page', String(meta.value.per_page || 20))
    const res = await api.get('/v1/products?' + params.toString())
    rows.value = Array.isArray(res?.data) ? res.data : Array.isArray(res) ? res : []
    meta.value = res?.meta || {
      page: page.value,
      per_page: meta.value.per_page || 20,
      total: rows.value.length,
      pages: 1,
    }
  } catch (e) {
    rows.value = []
    error.value = e instanceof ApiError ? e.message : 'Yuklab bo\'lmadi'
  } finally {
    loading.value = false
  }
}

function refresh() {
  load()
  loadSummary()
}

function onSearch() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => {
    page.value = 1
    load()
  }, 300)
}

function toggleLow() {
  lowOnly.value = !lowOnly.value
  page.value = 1
  load()
}

// ---- Pagination ----
const pageNumbers = computed(() => {
  const pages = Math.max(1, meta.value.pages || 1)
  const cur = meta.value.page || page.value
  const out = []
  const from = Math.max(1, cur - 2)
  const to = Math.min(pages, cur + 2)
  for (let p = from; p <= to; p++) out.push(p)
  return out
})

function goPage(p) {
  const pages = Math.max(1, meta.value.pages || 1)
  if (p < 1 || p > pages || p === (meta.value.page || page.value)) return
  page.value = p
  load()
}

// ---- API error mapping (422 field errors) ----
function applyApiErrors(e, target) {
  fieldErrors.value = {}
  formError.value = ''
  if (e instanceof ApiError && Array.isArray(e.errors) && e.errors.length) {
    for (const err of e.errors) {
      const field =
        err.field ||
        err.source?.parameter ||
        (err.source?.pointer ? err.source.pointer.split('/').pop() : null)
      const msg = err.detail || err.title || 'Xato'
      if (field) target[field] = msg
    }
    if (!Object.keys(target).length) formError.value = e.message
  } else {
    formError.value = e instanceof ApiError ? e.message : 'Saqlab bo\'lmadi'
  }
}

// ---- Create / edit ----
function openCreate() {
  editing.value = null
  form.value = blank()
  formError.value = ''
  fieldErrors.value = {}
  showModal.value = true
}

function openEdit(p) {
  editing.value = p
  form.value = {
    name: p.name || '',
    unit: p.unit || 'dona',
    price_som: p.price_tiyin ? tiyinToSom(p.price_tiyin) : '',
    cost_som: p.cost_tiyin ? tiyinToSom(p.cost_tiyin) : '',
    stock_qty: p.stock_qty ?? 0,
    low_stock: p.low_stock ?? 0,
    is_active: p.is_active !== false,
  }
  formError.value = ''
  fieldErrors.value = {}
  showModal.value = true
}

async function save() {
  formError.value = ''
  fieldErrors.value = {}
  if (!form.value.name.trim()) {
    fieldErrors.value = { name: 'Mahsulot nomini kiriting' }
    return
  }
  saving.value = true
  try {
    const payload = {
      name: form.value.name.trim(),
      unit: form.value.unit.trim() || 'dona',
      price_tiyin: form.value.price_som === '' ? 0 : somToTiyin(form.value.price_som),
      cost_tiyin: form.value.cost_som === '' ? 0 : somToTiyin(form.value.cost_som),
      stock_qty: Number(form.value.stock_qty) || 0,
      low_stock: Number(form.value.low_stock) || 0,
      is_active: form.value.is_active,
    }
    if (editing.value) {
      await api.patch('/v1/products/' + editing.value.id, payload)
    } else {
      await api.post('/v1/products', payload)
    }
    showModal.value = false
    refresh()
  } catch (e) {
    applyApiErrors(e, fieldErrors.value)
  } finally {
    saving.value = false
  }
}

async function remove(p) {
  if (!(await confirm({ message: `"${p.name}" mahsulotini o'chirilsinmi?`, danger: true, confirmText: 'O‘chirish' }))) return
  try {
    await api.del('/v1/products/' + p.id)
    refresh()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'O\'chirib bo\'lmadi'
  }
}

// ---- Stock adjust ----
function openStock(p) {
  stockTarget.value = p
  stockForm.value = blankStock()
  stockForm.value.new_qty = p.stock_qty ?? 0
  stockError.value = ''
  movements.value = []
  showStock.value = true
  loadMovements(p.id)
}

async function loadMovements(id) {
  movLoading.value = true
  try {
    const res = await api.get('/v1/products/' + id + '/movements')
    movements.value = Array.isArray(res?.data) ? res.data : Array.isArray(res) ? res : []
  } catch {
    movements.value = []
  } finally {
    movLoading.value = false
  }
}

// Signed delta the API expects, derived from the chosen type.
const stockDelta = computed(() => {
  const t = stockForm.value.type
  if (t === 'adjust') {
    const target = Number(stockForm.value.new_qty)
    if (Number.isNaN(target)) return 0
    return target - Number(stockTarget.value?.stock_qty ?? 0)
  }
  const qty = Math.abs(Number(stockForm.value.qty) || 0)
  return t === 'in' ? qty : -qty
})

// Preview the resulting stock level.
const stockResult = computed(
  () => Number(stockTarget.value?.stock_qty ?? 0) + stockDelta.value
)

async function saveStock() {
  stockError.value = ''
  const t = stockForm.value.type
  if (t === 'adjust') {
    if (stockForm.value.new_qty === '' || Number.isNaN(Number(stockForm.value.new_qty))) {
      stockError.value = 'Yangi zaxira miqdorini kiriting'
      return
    }
  } else if (!(Number(stockForm.value.qty) > 0)) {
    stockError.value = 'Miqdorni kiriting'
    return
  }
  if (stockDelta.value === 0) {
    stockError.value = 'Zaxira o\'zgarmadi'
    return
  }
  if ((t === 'out' || t === 'writeoff') && stockResult.value < 0) {
    stockError.value = 'Zaxira manfiy bo\'lib qoladi'
    return
  }
  stockSaving.value = true
  try {
    const payload = {
      delta_qty: stockDelta.value,
      type: t,
      reason: stockForm.value.reason.trim() || null,
    }
    const res = await api.post('/v1/products/' + stockTarget.value.id + '/stock', payload)
    const updated = res?.data || res
    // Sync the row and the modal target in place.
    if (updated && updated.id != null) {
      const row = rows.value.find((r) => r.id === updated.id)
      if (row) Object.assign(row, updated)
      stockTarget.value = { ...stockTarget.value, ...updated }
    }
    stockForm.value = blankStock()
    stockForm.value.new_qty = stockTarget.value.stock_qty ?? 0
    await loadMovements(stockTarget.value.id)
    loadSummary()
  } catch (e) {
    stockError.value = e instanceof ApiError ? e.message : 'Saqlab bo\'lmadi'
  } finally {
    stockSaving.value = false
  }
}

onMounted(() => {
  load()
  loadSummary()
})
</script>

<template>
  <div>
    <div class="page-head">
      <h1>Ombor</h1>
      <button class="btn btn-primary" @click="openCreate">+ Yangi mahsulot</button>
    </div>

    <div class="stat-grid" style="margin-bottom: 22px">
      <div class="stat">
        <div class="value">{{ summary.total }}</div>
        <div class="label">Jami mahsulot</div>
      </div>
      <div class="stat">
        <div class="value" style="color: var(--danger)">{{ summary.low_stock_count }}</div>
        <div class="label">Kam qolgan</div>
      </div>
      <div class="stat">
        <div class="value" style="color: var(--primary)">{{ formatSom(summary.stock_value_tiyin) }}</div>
        <div class="label">Zaxira qiymati</div>
      </div>
    </div>

    <div class="toolbar">
      <div class="field mb-0" style="max-width: 340px; flex: 1">
        <input v-model="search" placeholder="Qidiruv: mahsulot nomi…" @input="onSearch" />
      </div>
      <button class="seg" :class="{ active: lowOnly }" @click="toggleLow">Kam qolgan</button>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>
    <div v-else-if="!rows.length" class="empty card">Mahsulotlar topilmadi.</div>

    <template v-else>
      <div class="table-wrap">
        <table class="data cards">
          <thead>
            <tr>
              <th>Nomi</th>
              <th>Birlik</th>
              <th style="text-align: right">Zaxira</th>
              <th style="text-align: right">Sotish narxi</th>
              <th style="text-align: right">Tannarx</th>
              <th>Faol</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in rows" :key="p.id">
              <td data-label="Nomi"><strong>{{ p.name }}</strong></td>
              <td data-label="Birlik">{{ p.unit || '—' }}</td>
              <td data-label="Zaxira" style="text-align: right">
                {{ p.stock_qty }}
                <span v-if="isLow(p)" class="badge no_show" style="margin-left: 6px">Kam</span>
              </td>
              <td data-label="Sotish narxi" style="text-align: right">{{ formatSom(p.price_tiyin) }}</td>
              <td data-label="Tannarx" style="text-align: right">{{ formatSom(p.cost_tiyin) }}</td>
              <td data-label="Faol">
                <span class="badge" :class="p.is_active !== false ? 'completed' : 'canceled'">
                  {{ p.is_active !== false ? 'Faol' : 'Nofaol' }}
                </span>
              </td>
              <td style="text-align: right; white-space: nowrap">
                <button class="btn btn-sm btn-ghost" @click="openStock(p)">Zaxira</button>
                <button class="btn btn-sm btn-ghost" @click="openEdit(p)">Tahrir</button>
                <button class="btn btn-sm btn-danger" @click="remove(p)">O'chirish</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="pager">
        <span class="muted">Jami: {{ meta.total }}</span>
        <div class="pager-ctrls">
          <button class="btn btn-sm" :disabled="(meta.page || 1) <= 1" @click="goPage((meta.page || 1) - 1)">‹</button>
          <button
            v-for="p in pageNumbers"
            :key="p"
            class="btn btn-sm"
            :class="{ 'btn-primary': p === (meta.page || 1) }"
            @click="goPage(p)"
          >
            {{ p }}
          </button>
          <button class="btn btn-sm" :disabled="(meta.page || 1) >= (meta.pages || 1)" @click="goPage((meta.page || 1) + 1)">›</button>
        </div>
        <span class="muted">Sahifada: {{ meta.per_page }}</span>
      </div>
    </template>

    <!-- Create / edit product -->
    <Modal
      v-if="showModal"
      :title="editing ? 'Mahsulotni tahrirlash' : 'Yangi mahsulot'"
      @close="showModal = false"
    >
      <form @submit.prevent="save">
        <div v-if="formError" class="alert alert-error">{{ formError }}</div>
        <div class="field">
          <label>Nomi</label>
          <input v-model="form.name" placeholder="Shampun" />
          <div v-if="fieldErrors.name" class="field-err">{{ fieldErrors.name }}</div>
        </div>
        <div class="field-row">
          <div class="field">
            <label>Birlik</label>
            <input v-model="form.unit" placeholder="dona / ml / kg" />
            <div v-if="fieldErrors.unit" class="field-err">{{ fieldErrors.unit }}</div>
          </div>
          <div class="field">
            <label>Faol</label>
            <label class="row" style="gap: 8px; cursor: pointer; height: 38px; align-items: center">
              <input v-model="form.is_active" type="checkbox" style="width: auto" />
              <span>Sotuvda ko'rinadi</span>
            </label>
          </div>
        </div>
        <div class="field-row">
          <div class="field">
            <label>Sotish narxi (so'm)</label>
            <input v-model="form.price_som" type="number" min="0" step="1000" placeholder="50000" />
            <div v-if="fieldErrors.price_tiyin" class="field-err">{{ fieldErrors.price_tiyin }}</div>
          </div>
          <div class="field">
            <label>Tannarx (so'm)</label>
            <input v-model="form.cost_som" type="number" min="0" step="1000" placeholder="30000" />
            <div v-if="fieldErrors.cost_tiyin" class="field-err">{{ fieldErrors.cost_tiyin }}</div>
          </div>
        </div>
        <div class="field-row">
          <div class="field">
            <label>Zaxira (miqdor)</label>
            <input v-model.number="form.stock_qty" type="number" step="1" />
            <div v-if="fieldErrors.stock_qty" class="field-err">{{ fieldErrors.stock_qty }}</div>
          </div>
          <div class="field">
            <label>Kam qolgan chegarasi</label>
            <input v-model.number="form.low_stock" type="number" min="0" step="1" />
            <div v-if="fieldErrors.low_stock" class="field-err">{{ fieldErrors.low_stock }}</div>
          </div>
        </div>
      </form>
      <template #footer>
        <button class="btn" @click="showModal = false">Bekor</button>
        <button class="btn btn-primary" :disabled="saving" @click="save">
          {{ saving ? 'Saqlanmoqda…' : 'Saqlash' }}
        </button>
      </template>
    </Modal>

    <!-- Stock adjust + movements -->
    <Modal
      v-if="showStock"
      :title="stockTarget ? 'Zaxira: ' + stockTarget.name : 'Zaxira'"
      wide
      @close="showStock = false"
    >
      <div class="stock-cur">
        Joriy zaxira: <strong>{{ stockTarget?.stock_qty }} {{ stockTarget?.unit }}</strong>
      </div>

      <form @submit.prevent="saveStock">
        <div v-if="stockError" class="alert alert-error">{{ stockError }}</div>
        <div class="field">
          <label>Amal turi</label>
          <div class="segs" style="flex-wrap: wrap">
            <button
              v-for="t in stockTypes"
              :key="t.key"
              type="button"
              class="seg"
              :class="{ active: stockForm.type === t.key }"
              @click="stockForm.type = t.key"
            >
              {{ t.label }}
            </button>
          </div>
        </div>

        <div v-if="stockForm.type === 'adjust'" class="field">
          <label>Yangi zaxira miqdori</label>
          <input v-model.number="stockForm.new_qty" type="number" step="1" />
          <div class="hint">O'zgarish: {{ stockDelta >= 0 ? '+' : '' }}{{ stockDelta }} → {{ stockResult }} {{ stockTarget?.unit }}</div>
        </div>
        <div v-else class="field">
          <label>Miqdor</label>
          <input v-model.number="stockForm.qty" type="number" min="1" step="1" placeholder="0" />
          <div class="hint">
            O'zgarish: {{ stockDelta >= 0 ? '+' : '' }}{{ stockDelta }} → {{ stockResult }} {{ stockTarget?.unit }}
          </div>
        </div>

        <div class="field">
          <label>Izoh (ixtiyoriy)</label>
          <input v-model="stockForm.reason" placeholder="Sabab…" />
        </div>
        <div style="text-align: right">
          <button class="btn btn-primary" :disabled="stockSaving" @click="saveStock">
            {{ stockSaving ? 'Saqlanmoqda…' : 'Qo\'llash' }}
          </button>
        </div>
      </form>

      <h3 style="font-size: 14px; margin-top: 20px">Harakatlar tarixi</h3>
      <div v-if="movLoading" class="loading-block"><span class="spinner"></span></div>
      <div v-else-if="!movements.length" class="muted" style="font-size: 13px">Harakatlar yo'q.</div>
      <ul v-else class="hist">
        <li v-for="(m, i) in movements" :key="m.id || i">
          <div>
            <span class="badge" :class="m.delta_qty >= 0 ? 'completed' : 'no_show'">
              {{ typeLabels[m.type] || m.type }}
            </span>
            <span v-if="m.reason" class="muted" style="font-size: 12px; margin-left: 8px">{{ m.reason }}</span>
            <div class="muted" style="font-size: 12px; margin-top: 2px">{{ formatDateTime(m.created_at) }}</div>
          </div>
          <strong :style="{ color: m.delta_qty >= 0 ? 'var(--success)' : 'var(--danger)' }">
            {{ m.delta_qty >= 0 ? '+' : '' }}{{ m.delta_qty }}
          </strong>
        </li>
      </ul>

      <template #footer>
        <button class="btn" @click="showStock = false">Yopish</button>
      </template>
    </Modal>
  </div>
</template>

<style scoped>
.toolbar {
  display: flex;
  gap: 12px;
  align-items: center;
  flex-wrap: wrap;
  margin-bottom: 16px;
}
.segs {
  display: inline-flex;
  gap: 4px;
  background: var(--surface-2);
  border: 1px solid var(--border);
  border-radius: 9px;
  padding: 3px;
}
.seg {
  font: inherit;
  font-weight: 600;
  font-size: 13px;
  cursor: pointer;
  border: 1px solid var(--border);
  background: var(--surface-2);
  color: var(--text-muted);
  padding: 6px 12px;
  border-radius: 7px;
  transition: background 0.15s, color 0.15s;
  white-space: nowrap;
}
.seg:hover {
  color: var(--text);
}
.seg.active {
  background: var(--surface);
  color: var(--primary);
  box-shadow: var(--shadow);
}
.segs .seg {
  border: none;
  background: transparent;
}

.pager {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
  margin-top: 14px;
  font-size: 13px;
}
.pager-ctrls {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.field-err {
  color: var(--danger);
  font-size: 12px;
  margin-top: 4px;
}
.hint {
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 4px;
}
.stock-cur {
  background: var(--surface-2);
  border-radius: 10px;
  padding: 10px 14px;
  margin-bottom: 14px;
  font-size: 14px;
}

.hist {
  list-style: none;
  margin: 8px 0 0;
  padding: 0;
}
.hist li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  padding: 10px 0;
  border-bottom: 1px solid var(--border);
}
.hist li:last-child {
  border-bottom: none;
}
</style>
