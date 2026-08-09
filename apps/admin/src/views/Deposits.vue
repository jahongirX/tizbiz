<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { api, ApiError } from '@navbat/api-client'
import { somToTiyin, formatSom } from '../lib/money'
import { formatDateTime } from '../lib/datetime'
import Modal from '../components/Modal.vue'
import { Wallet, ArrowDownCircle, ArrowUpCircle, RotateCcw, Search } from 'lucide-vue-next'

// ---- List state ----
const loading = ref(true)
const error = ref('')
const rows = ref([])
const meta = ref({ page: 1, per_page: 20, total: 0, pages: 1 })

const search = ref('')
const page = ref(1)
let searchTimer = null

// ---- Transaction type metadata ----
const txTypes = [
  { key: 'topup', label: "To'ldirish", icon: ArrowDownCircle },
  { key: 'spend', label: 'Yechish', icon: ArrowUpCircle },
  { key: 'refund', label: 'Qaytarish', icon: RotateCcw },
]
const typeLabels = { topup: "To'ldirish", spend: 'Yechish', refund: 'Qaytarish' }

// ---- Add deposit modal ----
const showAdd = ref(false)
const saving = ref(false)
const addError = ref('')
const addForm = ref(blankAdd())
const clientSearch = ref('')
const clientResults = ref([])
const clientSearching = ref(false)
let clientTimer = null

// ---- Detail (ledger) modal ----
const showDetail = ref(false)
const detailLoading = ref(false)
const detailError = ref('')
const detail = ref(null)

function blankAdd() {
  return { client_id: '', client_name: '', client_phone: '', amount_som: '', type: 'topup', reason: '' }
}

// ---- Loading list ----
async function load() {
  loading.value = true
  error.value = ''
  try {
    const params = new URLSearchParams()
    const q = search.value.trim()
    if (q) params.set('search', q)
    params.set('page', String(page.value))
    params.set('per_page', String(meta.value.per_page || 20))
    const res = await api.get('/v1/deposits/balances?' + params.toString())
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

function onSearch() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => {
    page.value = 1
    load()
  }, 300)
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

// ---- Add deposit ----
function openAdd(preset) {
  addForm.value = blankAdd()
  clientSearch.value = ''
  clientResults.value = []
  addError.value = ''
  if (preset) {
    addForm.value.client_id = preset.client_id
    addForm.value.client_name = preset.name || ''
    addForm.value.client_phone = preset.phone || ''
    clientSearch.value = preset.name || preset.phone || ''
  }
  showAdd.value = true
}

function onClientSearch() {
  // Typing invalidates a previously picked client.
  addForm.value.client_id = ''
  clearTimeout(clientTimer)
  const q = clientSearch.value.trim()
  if (!q) {
    clientResults.value = []
    return
  }
  clientTimer = setTimeout(async () => {
    clientSearching.value = true
    try {
      const res = await api.get('/v1/clients?search=' + encodeURIComponent(q) + '&per_page=8')
      clientResults.value = Array.isArray(res?.data) ? res.data : Array.isArray(res) ? res : []
    } catch {
      clientResults.value = []
    } finally {
      clientSearching.value = false
    }
  }, 300)
}

function pickClient(c) {
  addForm.value.client_id = c.id
  addForm.value.client_name = c.name || ''
  addForm.value.client_phone = c.phone || ''
  clientSearch.value = c.name || c.phone || ''
  clientResults.value = []
}

async function saveAdd() {
  addError.value = ''
  if (!addForm.value.client_id) {
    addError.value = 'Mijozni tanlang'
    return
  }
  const amount = somToTiyin(addForm.value.amount_som)
  if (!(amount > 0)) {
    addError.value = 'Summani kiriting'
    return
  }
  saving.value = true
  try {
    const payload = {
      client_id: addForm.value.client_id,
      amount_tiyin: amount,
      type: addForm.value.type,
      reason: addForm.value.reason.trim() || null,
    }
    await api.post('/v1/deposits', payload)
    showAdd.value = false
    await load()
    // If the ledger modal is open for this client, refresh it.
    if (showDetail.value && detail.value?.client_id === payload.client_id) {
      await openDetail({ client_id: payload.client_id })
    }
  } catch (e) {
    addError.value = e instanceof ApiError ? e.message : 'Saqlab bo\'lmadi'
  } finally {
    saving.value = false
  }
}

// ---- Detail / ledger ----
async function openDetail(row) {
  showDetail.value = true
  detailLoading.value = true
  detailError.value = ''
  detail.value = { client_id: row.client_id, name: row.name, phone: row.phone, balance_tiyin: row.balance_tiyin, transactions: [] }
  try {
    const res = await api.get('/v1/deposits/' + row.client_id)
    const d = res?.data || res || {}
    detail.value = {
      client_id: d.client_id ?? row.client_id,
      name: d.name ?? row.name,
      phone: d.phone ?? row.phone,
      balance_tiyin: d.balance_tiyin ?? row.balance_tiyin ?? 0,
      transactions: Array.isArray(d.transactions) ? d.transactions : [],
    }
  } catch (e) {
    detailError.value = e instanceof ApiError ? e.message : 'Yuklab bo\'lmadi'
  } finally {
    detailLoading.value = false
  }
}

onMounted(load)
</script>

<template>
  <div>
    <RouterLink to="/loyalty" class="back-link">← Loyallik</RouterLink>

    <div class="page-head">
      <h1>Mijoz depozitlari</h1>
      <button class="btn btn-primary" @click="openAdd(null)">
        <Wallet :size="16" style="vertical-align: -3px; margin-right: 4px" /> Depozit qo'shish
      </button>
    </div>

    <div class="toolbar">
      <div class="field mb-0" style="max-width: 340px; flex: 1">
        <input v-model="search" placeholder="Qidiruv: mijoz / telefon…" @input="onSearch" />
      </div>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>
    <div v-else-if="!rows.length" class="empty card">
      Depozitli mijoz topilmadi. <a href="#" @click.prevent="openAdd(null)">Depozit qo'shing</a>.
    </div>

    <template v-else>
      <div class="table-wrap">
        <table class="data">
          <thead>
            <tr>
              <th>Mijoz</th>
              <th>Telefon</th>
              <th style="text-align: right">Balans</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="r in rows"
              :key="r.client_id"
              style="cursor: pointer"
              @click="openDetail(r)"
            >
              <td><strong>{{ r.name || '—' }}</strong></td>
              <td>{{ r.phone || '—' }}</td>
              <td style="text-align: right">
                <strong :style="{ color: (r.balance_tiyin || 0) < 0 ? 'var(--danger)' : 'var(--primary)' }">
                  {{ formatSom(r.balance_tiyin) }}
                </strong>
              </td>
              <td style="text-align: right; white-space: nowrap" @click.stop>
                <button class="btn btn-sm btn-ghost" @click="openDetail(r)">Tarix</button>
                <button class="btn btn-sm btn-ghost" @click="openAdd(r)">Amal</button>
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

    <!-- ============ Add deposit modal ============ -->
    <Modal v-if="showAdd" title="Depozit amali" @close="showAdd = false">
      <form @submit.prevent="saveAdd">
        <div v-if="addError" class="alert alert-error">{{ addError }}</div>

        <div class="field">
          <label>Mijoz</label>
          <div class="client-pick">
            <div class="search-in">
              <Search :size="15" class="search-ic" />
              <input
                v-model="clientSearch"
                placeholder="Ism yoki telefon bo'yicha qidiring…"
                autocomplete="off"
                @input="onClientSearch"
              />
            </div>
            <div v-if="addForm.client_id" class="picked">
              ✓ {{ addForm.client_name }}
              <span v-if="addForm.client_phone" class="muted">· {{ addForm.client_phone }}</span>
            </div>
            <ul v-else-if="clientResults.length" class="results">
              <li v-for="c in clientResults" :key="c.id" @click="pickClient(c)">
                <strong>{{ c.name }}</strong>
                <span class="muted">{{ c.phone || '' }}</span>
              </li>
            </ul>
            <div v-else-if="clientSearching" class="muted" style="font-size: 12px; margin-top: 6px">Qidirilmoqda…</div>
            <div
              v-else-if="clientSearch.trim() && !clientSearching"
              class="muted"
              style="font-size: 12px; margin-top: 6px"
            >
              Mijoz topilmadi.
            </div>
          </div>
        </div>

        <div class="field">
          <label>Amal turi</label>
          <div class="segs" style="flex-wrap: wrap">
            <button
              v-for="t in txTypes"
              :key="t.key"
              type="button"
              class="seg"
              :class="{ active: addForm.type === t.key }"
              @click="addForm.type = t.key"
            >
              <component :is="t.icon" :size="14" style="vertical-align: -2px; margin-right: 3px" />
              {{ t.label }}
            </button>
          </div>
        </div>

        <div class="field">
          <label>Summa (so'm)</label>
          <input v-model="addForm.amount_som" type="number" min="0" step="1000" placeholder="100000" />
        </div>

        <div class="field">
          <label>Izoh (ixtiyoriy)</label>
          <input v-model="addForm.reason" placeholder="Sabab…" />
        </div>
      </form>
      <template #footer>
        <button class="btn" @click="showAdd = false">Bekor</button>
        <button class="btn btn-primary" :disabled="saving" @click="saveAdd">
          {{ saving ? 'Saqlanmoqda…' : 'Saqlash' }}
        </button>
      </template>
    </Modal>

    <!-- ============ Detail / ledger modal ============ -->
    <Modal
      v-if="showDetail"
      :title="detail?.name || 'Depozit'"
      wide
      @close="showDetail = false"
    >
      <p class="muted mb-0">{{ detail?.phone || 'Telefon yo\'q' }}</p>

      <div class="bal-box">
        <div>
          <div class="muted" style="font-size: 12px">Joriy balans</div>
          <div
            style="font-size: 24px; font-weight: 700"
            :style="{ color: (detail?.balance_tiyin || 0) < 0 ? 'var(--danger)' : 'var(--primary)' }"
          >
            {{ formatSom(detail?.balance_tiyin || 0) }}
          </div>
        </div>
        <button v-if="detail" class="btn btn-sm btn-primary" @click="openAdd(detail)">+ Amal</button>
      </div>

      <div v-if="detailError" class="alert alert-error">{{ detailError }}</div>
      <div v-if="detailLoading" class="loading-block"><span class="spinner"></span></div>

      <template v-else>
        <h3 style="font-size: 14px; margin-top: 18px">Harakatlar tarixi</h3>
        <div v-if="!detail?.transactions?.length" class="muted" style="font-size: 13px">Harakatlar yo'q.</div>
        <ul v-else class="hist">
          <li v-for="(t, i) in detail.transactions" :key="i">
            <div>
              <span class="badge" :class="(t.delta_tiyin || 0) >= 0 ? 'completed' : 'no_show'">
                {{ typeLabels[t.type] || t.type }}
              </span>
              <span v-if="t.reason" class="muted" style="font-size: 12px; margin-left: 8px">{{ t.reason }}</span>
              <div class="muted" style="font-size: 12px; margin-top: 2px">{{ formatDateTime(t.created_at) }}</div>
            </div>
            <strong :style="{ color: (t.delta_tiyin || 0) >= 0 ? 'var(--success)' : 'var(--danger)' }">
              {{ (t.delta_tiyin || 0) >= 0 ? '+' : '' }}{{ formatSom(t.delta_tiyin) }}
            </strong>
          </li>
        </ul>
      </template>

      <template #footer>
        <button class="btn" @click="showDetail = false">Yopish</button>
      </template>
    </Modal>
  </div>
</template>

<style scoped>
.back-link {
  display: inline-block;
  margin-bottom: 12px;
  font-size: 13px;
  font-weight: 600;
  color: var(--text-muted);
  text-decoration: none;
}
.back-link:hover {
  color: var(--primary);
}

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
  border: none;
  background: transparent;
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

/* ---- Client picker ---- */
.client-pick {
  position: relative;
}
.search-in {
  position: relative;
}
.search-ic {
  position: absolute;
  left: 10px;
  top: 50%;
  transform: translateY(-50%);
  color: var(--text-muted);
  pointer-events: none;
}
.search-in input {
  padding-left: 32px;
}
.picked {
  margin-top: 6px;
  font-size: 13px;
  font-weight: 600;
  color: var(--success);
}
.results {
  list-style: none;
  margin: 6px 0 0;
  padding: 4px;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: var(--surface);
  box-shadow: var(--shadow);
  max-height: 220px;
  overflow-y: auto;
}
.results li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  padding: 8px 10px;
  border-radius: 7px;
  cursor: pointer;
  font-size: 13px;
}
.results li:hover {
  background: var(--surface-2);
}

/* ---- Balance box + ledger ---- */
.bal-box {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: var(--surface-2);
  border-radius: 10px;
  padding: 14px 16px;
  margin-top: 14px;
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
