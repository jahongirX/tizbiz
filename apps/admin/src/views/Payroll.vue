<script setup>
import { ref, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { formatSom } from '../lib/money'
import { todayInput } from '../lib/datetime'

// ---- Period (default: this month) ----
function monthBounds() {
  const today = todayInput() // 'YYYY-MM-DD' in Tashkent
  const first = today.slice(0, 8) + '01'
  return { from: first, to: today }
}
const period = ref(monthBounds())

// ---- Data ----
const loading = ref(true)
const error = ref('')
const staff = ref([])
const totals = ref({ revenue_tiyin: 0, earnings_tiyin: 0 })

// ---- Inline commission edit state ----
// Draft value keyed by staff_id; per-row saving / error.
const drafts = ref({})
const savingId = ref(null)
const rowError = ref({})

async function load() {
  loading.value = true
  error.value = ''
  try {
    const params = new URLSearchParams()
    if (period.value.from) params.set('from', period.value.from)
    if (period.value.to) params.set('to', period.value.to)
    const res = await api.get('/v1/payroll?' + params.toString())
    staff.value = Array.isArray(res?.staff) ? res.staff : []
    totals.value = res?.totals || { revenue_tiyin: 0, earnings_tiyin: 0 }
    // Reset drafts to server values.
    const d = {}
    for (const s of staff.value) d[s.staff_id] = s.commission_percent
    drafts.value = d
    rowError.value = {}
  } catch (e) {
    staff.value = []
    totals.value = { revenue_tiyin: 0, earnings_tiyin: 0 }
    error.value = e instanceof ApiError ? e.message : 'Ma\'lumotni yuklab bo\'lmadi'
  } finally {
    loading.value = false
  }
}

function isDirty(s) {
  const draft = Number(drafts.value[s.staff_id])
  return Number.isFinite(draft) && draft !== Number(s.commission_percent)
}

async function saveCommission(s) {
  const draft = Number(drafts.value[s.staff_id])
  if (!Number.isFinite(draft) || draft < 0 || draft > 100) {
    rowError.value = { ...rowError.value, [s.staff_id]: '0–100 oralig\'ida bo\'lsin' }
    return
  }
  savingId.value = s.staff_id
  rowError.value = { ...rowError.value, [s.staff_id]: '' }
  try {
    await api.patch('/v1/staff/' + s.staff_id, { commission_percent: draft })
    await load()
  } catch (e) {
    rowError.value = {
      ...rowError.value,
      [s.staff_id]: e instanceof ApiError ? e.message : 'Saqlab bo\'lmadi',
    }
  } finally {
    savingId.value = null
  }
}

const hasRows = computed(() => staff.value.length > 0)

onMounted(load)
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <h1>Ish haqi</h1>
        <p class="muted mb-0">Xodimlar bo'yicha daromad va komissiya hisob-kitobi.</p>
      </div>
    </div>

    <!-- Period selector -->
    <div class="card period-bar">
      <div class="field mb-0">
        <label>Boshlanish</label>
        <input v-model="period.from" type="date" :max="period.to" />
      </div>
      <div class="field mb-0">
        <label>Tugash</label>
        <input v-model="period.to" type="date" :min="period.from" />
      </div>
      <button class="btn btn-primary" :disabled="loading" @click="load">
        {{ loading ? 'Yuklanmoqda…' : 'Ko\'rsatish' }}
      </button>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

    <template v-else>
      <div v-if="!hasRows" class="empty card">Bu davr uchun ma'lumot yo'q.</div>

      <div v-else class="table-wrap">
        <table class="data">
          <thead>
            <tr>
              <th>Xodim</th>
              <th style="width: 180px">Komissiya (%)</th>
              <th style="text-align: right">Yozuvlar</th>
              <th style="text-align: right">Daromad</th>
              <th style="text-align: right">Ish haqi</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="s in staff" :key="s.staff_id">
              <td><strong>{{ s.name }}</strong></td>
              <td>
                <div class="comm-cell">
                  <input
                    v-model.number="drafts[s.staff_id]"
                    class="comm-input"
                    type="number"
                    min="0"
                    max="100"
                    step="1"
                    :disabled="savingId === s.staff_id"
                    @keyup.enter="saveCommission(s)"
                  />
                  <button
                    v-if="isDirty(s)"
                    class="btn btn-sm btn-primary"
                    :disabled="savingId === s.staff_id"
                    @click="saveCommission(s)"
                  >
                    {{ savingId === s.staff_id ? '…' : 'Saqlash' }}
                  </button>
                </div>
                <div v-if="rowError[s.staff_id]" class="field-err">{{ rowError[s.staff_id] }}</div>
              </td>
              <td style="text-align: right">{{ s.appointments }}</td>
              <td style="text-align: right">{{ formatSom(s.revenue_tiyin) }}</td>
              <td style="text-align: right"><strong>{{ formatSom(s.earnings_tiyin) }}</strong></td>
            </tr>
          </tbody>
          <tfoot>
            <tr class="totals-row">
              <td colspan="3">Jami</td>
              <td style="text-align: right">Jami daromad: {{ formatSom(totals.revenue_tiyin) }}</td>
              <td style="text-align: right">Jami ish haqi: {{ formatSom(totals.earnings_tiyin) }}</td>
            </tr>
          </tfoot>
        </table>
      </div>
    </template>
  </div>
</template>

<style scoped>
.period-bar {
  display: flex;
  align-items: flex-end;
  gap: 14px;
  flex-wrap: wrap;
  margin-bottom: 18px;
}
.field.mb-0 {
  margin-bottom: 0;
}

.comm-cell {
  display: flex;
  align-items: center;
  gap: 8px;
}
.comm-input {
  max-width: 90px;
}

.field-err {
  color: var(--danger);
  font-size: 12px;
  margin-top: 4px;
}

.totals-row td {
  font-weight: 700;
  border-top: 2px solid var(--border);
  background: var(--surface-2);
}
</style>
