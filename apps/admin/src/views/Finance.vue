<script setup>
import { ref, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { formatSom } from '../lib/money'
import { formatDateTime, todayInput, addDays } from '../lib/datetime'

// ---- Period ----
const from = ref(addDays(todayInput(), -29))
const to = ref(todayInput())

const presets = [
  { key: 7, label: '7 kun' },
  { key: 30, label: '30 kun' },
  { key: 90, label: '90 kun' },
]

function setPreset(days) {
  to.value = todayInput()
  from.value = addDays(to.value, -(days - 1))
  page.value = 1
  loadAll()
}

// ---- Filters ----
const provider = ref('')
const type = ref('')
const status = ref('')

const providerOptions = [
  { key: '', label: 'Barcha provayderlar' },
  { key: 'cash', label: 'Naqd' },
  { key: 'payme', label: 'Payme' },
  { key: 'click', label: 'Click' },
]
const typeOptions = [
  { key: '', label: 'Barcha turlar' },
  { key: 'sale', label: 'Xizmat to‘lovi' },
  { key: 'deposit', label: 'Depozit' },
  { key: 'refund', label: 'Qaytarish' },
  { key: 'float', label: 'Ustama' },
]
const statusOptions = [
  { key: '', label: 'Barcha holatlar' },
  { key: 'created', label: 'Yaratildi' },
  { key: 'pending', label: 'Kutilmoqda' },
  { key: 'paid', label: "To'langan" },
  { key: 'canceled', label: 'Bekor qilindi' },
  { key: 'refunded', label: 'Qaytarildi' },
]

// ---- Label maps ----
const providerLabels = { cash: 'Naqd', payme: 'Payme', click: 'Click' }
const typeLabels = { sale: 'Xizmat to‘lovi', deposit: 'Depozit', refund: 'Qaytarish', float: 'Ustama' }
const statusLabels = {
  created: 'Yaratildi',
  pending: 'Kutilmoqda',
  paid: "To'langan",
  canceled: 'Bekor qilindi',
  refunded: 'Qaytarildi',
}
// Reuse the shared .badge palette (appointment statuses) for tx statuses.
const statusBadge = {
  created: 'pending',
  pending: 'pending',
  paid: 'completed',
  canceled: 'canceled',
  refunded: 'no_show',
}

// ---- Summary state ----
const summaryLoading = ref(true)
const summaryError = ref('')
const summary = ref(null)

// ---- Transactions state ----
const txLoading = ref(true)
const txError = ref('')
const rows = ref([])
const meta = ref({ page: 1, per_page: 20, total: 0, pages: 1 })
const page = ref(1)

function rangeParams() {
  const p = new URLSearchParams()
  p.set('from', from.value)
  p.set('to', to.value)
  return p
}

async function loadSummary() {
  summaryLoading.value = true
  summaryError.value = ''
  try {
    summary.value = await api.get('/v1/finance/summary?' + rangeParams().toString())
  } catch (e) {
    summary.value = null
    summaryError.value = e instanceof ApiError ? e.message : 'Yuklab bo\'lmadi'
  } finally {
    summaryLoading.value = false
  }
}

async function loadTransactions() {
  txLoading.value = true
  txError.value = ''
  try {
    const p = rangeParams()
    if (provider.value) p.set('provider', provider.value)
    if (type.value) p.set('type', type.value)
    if (status.value) p.set('status', status.value)
    p.set('page', String(page.value))
    p.set('per_page', String(meta.value.per_page || 20))
    const res = await api.get('/v1/finance/transactions?' + p.toString())
    rows.value = Array.isArray(res?.data) ? res.data : Array.isArray(res) ? res : []
    meta.value = res?.meta || {
      page: page.value,
      per_page: meta.value.per_page || 20,
      total: rows.value.length,
      pages: 1,
    }
  } catch (e) {
    rows.value = []
    txError.value = e instanceof ApiError ? e.message : 'Yuklab bo\'lmadi'
  } finally {
    txLoading.value = false
  }
}

async function loadAll() {
  await Promise.all([loadSummary(), loadTransactions()])
}

function applyPeriod() {
  page.value = 1
  loadAll()
}

function applyFilters() {
  page.value = 1
  loadTransactions()
}

// ---- Pagination ----
const pageNumbers = computed(() => {
  const pages = Math.max(1, meta.value.pages || 1)
  const cur = meta.value.page || page.value
  const out = []
  const lo = Math.max(1, cur - 2)
  const hi = Math.min(pages, cur + 2)
  for (let p = lo; p <= hi; p++) out.push(p)
  return out
})

function goPage(p) {
  const pages = Math.max(1, meta.value.pages || 1)
  if (p < 1 || p > pages || p === (meta.value.page || page.value)) return
  page.value = p
  loadTransactions()
}

onMounted(loadAll)
</script>

<template>
  <div>
    <div class="page-head">
      <h1>Moliya</h1>
      <button class="btn btn-sm" @click="loadAll">Yangilash</button>
    </div>

    <!-- Period selector -->
    <div class="toolbar">
      <div class="segs">
        <button v-for="pr in presets" :key="pr.key" class="seg" @click="setPreset(pr.key)">
          {{ pr.label }}
        </button>
      </div>
      <div class="date-range">
        <input v-model="from" type="date" :max="to" @change="applyPeriod" />
        <span class="muted">—</span>
        <input v-model="to" type="date" :min="from" @change="applyPeriod" />
      </div>
    </div>

    <!-- Summary -->
    <div v-if="summaryError" class="alert alert-error">{{ summaryError }}</div>
    <div v-if="summaryLoading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>
    <template v-else-if="summary">
      <div class="stat-grid" style="margin-bottom: 12px">
        <div class="stat">
          <div class="value" style="color: var(--success)">{{ formatSom(summary.income_tiyin) }}</div>
          <div class="label">Kirim</div>
        </div>
        <div class="stat">
          <div class="value" style="color: var(--danger)">{{ formatSom(summary.refunds_tiyin) }}</div>
          <div class="label">Qaytarilgan</div>
        </div>
        <div class="stat">
          <div class="value" style="color: var(--primary)">{{ formatSom(summary.net_tiyin) }}</div>
          <div class="label">Sof</div>
        </div>
        <div class="stat">
          <div class="value">{{ summary.count ?? 0 }}</div>
          <div class="label">Tranzaksiyalar</div>
        </div>
      </div>

      <div
        v-if="summary.by_provider && summary.by_provider.length"
        class="provider-breakdown"
      >
        <div v-for="p in summary.by_provider" :key="p.provider" class="prov-chip">
          <span class="prov-name">{{ providerLabels[p.provider] || p.provider }}</span>
          <span class="prov-amount">{{ formatSom(p.amount_tiyin) }}</span>
          <span class="muted prov-count">{{ p.count }} ta</span>
        </div>
      </div>
    </template>

    <!-- Transaction filters -->
    <div class="tx-filters">
      <select v-model="provider" @change="applyFilters">
        <option v-for="o in providerOptions" :key="o.key" :value="o.key">{{ o.label }}</option>
      </select>
      <select v-model="type" @change="applyFilters">
        <option v-for="o in typeOptions" :key="o.key" :value="o.key">{{ o.label }}</option>
      </select>
      <select v-model="status" @change="applyFilters">
        <option v-for="o in statusOptions" :key="o.key" :value="o.key">{{ o.label }}</option>
      </select>
    </div>

    <!-- Transactions table -->
    <div v-if="txError" class="alert alert-error">{{ txError }}</div>
    <div v-if="txLoading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>
    <div v-else-if="!rows.length" class="empty card">Tranzaksiyalar topilmadi.</div>
    <template v-else>
      <div class="table-wrap">
        <table class="data">
          <thead>
            <tr>
              <th>Sana</th>
              <th>Provayder</th>
              <th>Turi</th>
              <th>Holat</th>
              <th style="text-align: right">Summa</th>
              <th>Mijoz</th>
              <th>Xizmat</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="t in rows" :key="t.id">
              <td>{{ formatDateTime(t.created_at) || '—' }}</td>
              <td>{{ providerLabels[t.provider] || t.provider || '—' }}</td>
              <td>{{ typeLabels[t.type] || t.type || '—' }}</td>
              <td>
                <span class="badge" :class="statusBadge[t.status] || 'pending'">
                  {{ statusLabels[t.status] || t.status }}
                </span>
              </td>
              <td style="text-align: right">{{ formatSom(t.amount_tiyin) }}</td>
              <td>{{ t.client_name || '—' }}</td>
              <td>{{ t.service_name || '—' }}</td>
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
          <button
            class="btn btn-sm"
            :disabled="(meta.page || 1) >= (meta.pages || 1)"
            @click="goPage((meta.page || 1) + 1)"
          >
            ›
          </button>
        </div>
        <span class="muted">Sahifada: {{ meta.per_page }}</span>
      </div>
    </template>
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
.date-range {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}
.date-range input {
  width: auto;
}

.provider-breakdown {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-bottom: 22px;
}
.prov-chip {
  display: inline-flex;
  align-items: baseline;
  gap: 8px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 8px 14px;
  box-shadow: var(--shadow);
}
.prov-name {
  font-weight: 650;
}
.prov-amount {
  color: var(--primary);
  font-weight: 700;
}
.prov-count {
  font-size: 12px;
}

.tx-filters {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  margin-bottom: 14px;
}
.tx-filters select {
  width: auto;
  min-width: 160px;
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
</style>
