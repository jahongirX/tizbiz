<script setup>
import { computed, ref, watch, onMounted } from 'vue'
import { api, ApiError, booking } from '@tizbiz/api-client'
import { confirm } from '../composables/useConfirm'

const WEEKDAYS = [
  { n: 1, l: 'Dushanba' },
  { n: 2, l: 'Seshanba' },
  { n: 3, l: 'Chorshanba' },
  { n: 4, l: 'Payshanba' },
  { n: 5, l: 'Juma' },
  { n: 6, l: 'Shanba' },
  { n: 7, l: 'Yakshanba' }, // ISO-8601: 1 = Monday … 7 = Sunday (matches WorkingHours)
]

const staff = ref([])
const staffId = ref(null)
const loadingStaff = ref(true)
const loading = ref(false)
const error = ref('')

const hours = ref(defaultHours())
const savingHours = ref(false)
const hoursSaved = ref(false)

const timeOff = ref([])
const toForm = ref({ starts_at: '', ends_at: '', reason: '' })
const savingOff = ref(false)

// A day holds one or more intervals, so a lunch break is just a gap between
// two of them (09:00-13:00 + 14:00-20:00). The API stores one row per interval.
function defaultHours() {
  return WEEKDAYS.map((d) => ({
    weekday: d.n,
    enabled: d.n >= 1 && d.n <= 6,
    intervals: [{ start: '09:00', end: '18:00' }],
  }))
}

async function loadStaff() {
  loadingStaff.value = true
  try {
    const res = await api.get('/v1/staff')
    staff.value = Array.isArray(res) ? res : res?.items || []
    if (staff.value.length && staffId.value == null) staffId.value = staff.value[0].id
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Xodimlarni yuklab bo\'lmadi'
  } finally {
    loadingStaff.value = false
  }
}

function hhmm(v) {
  if (!v) return ''
  const m = String(v).match(/(\d{1,2}):(\d{2})/)
  return m ? `${m[1].padStart(2, '0')}:${m[2]}` : v
}

async function loadSchedule() {
  if (!staffId.value) return
  loading.value = true
  error.value = ''
  hoursSaved.value = false
  try {
    const [wh, off] = await Promise.all([
      api.get(`/v1/staff/${staffId.value}/working-hours`).catch(() => []),
      api.get(`/v1/staff/${staffId.value}/time-off`).catch(() => []),
    ])
    const rows = Array.isArray(wh) ? wh : wh?.items || wh?.days || []
    hours.value = WEEKDAYS.map((d) => {
      const dayRows = rows
        .filter((r) => Number(r.weekday ?? r.day) === d.n)
        .map((r) => ({
          start: hhmm(r.start || r.start_time || '09:00'),
          end: hhmm(r.end || r.end_time || '18:00'),
        }))
        .sort((a, b) => a.start.localeCompare(b.start))
      return dayRows.length
        ? { weekday: d.n, enabled: true, intervals: dayRows }
        : { weekday: d.n, enabled: false, intervals: [{ start: '09:00', end: '18:00' }] }
    })
    timeOff.value = Array.isArray(off) ? off : off?.items || []
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Jadvalni yuklab bo\'lmadi'
  } finally {
    loading.value = false
  }
}

/** Header checkbox: on = every weekday enabled, off = none. */
const allEnabled = computed({
  get: () => hours.value.length > 0 && hours.value.every((h) => h.enabled),
  set: (on) => hours.value.forEach((h) => (h.enabled = on)),
})
const someEnabled = computed(() => hours.value.some((h) => h.enabled) && !allEnabled.value)

/** Copy the first enabled day's intervals onto every enabled day. */
function applyTimesToAll() {
  const src = hours.value.find((h) => h.enabled) || hours.value[0]
  if (!src) return
  hours.value.forEach((h) => {
    if (h.enabled && h !== src) {
      h.intervals = src.intervals.map((iv) => ({ ...iv }))
    }
  })
}

function addInterval(h) {
  const last = h.intervals[h.intervals.length - 1]
  h.intervals.push({ start: last?.end || '14:00', end: '20:00' })
}

function removeInterval(h, i) {
  h.intervals.splice(i, 1)
  if (!h.intervals.length) h.intervals.push({ start: '09:00', end: '18:00' })
}

/** Split a single working block into morning + afternoon around a lunch hour. */
function addBreak(h) {
  if (h.intervals.length !== 1) return
  const [iv] = h.intervals
  h.intervals = [
    { start: iv.start, end: '13:00' },
    { start: '14:00', end: iv.end },
  ]
}

const hasBreak = (h) => h.intervals.length > 1

async function saveHours() {
  savingHours.value = true
  error.value = ''
  hoursSaved.value = false
  try {
    await booking.saveWorkingHours(staffId.value, hours.value)
    hoursSaved.value = true
    setTimeout(() => (hoursSaved.value = false), 2500)
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Saqlab bo\'lmadi'
  } finally {
    savingHours.value = false
  }
}

async function addTimeOff() {
  if (!toForm.value.starts_at) return
  savingOff.value = true
  error.value = ''
  try {
    await api.post(`/v1/staff/${staffId.value}/time-off`, {
      starts_at: toForm.value.starts_at,
      ends_at: toForm.value.ends_at || toForm.value.starts_at,
      reason: toForm.value.reason.trim() || null,
    })
    toForm.value = { starts_at: '', ends_at: '', reason: '' }
    await loadSchedule()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Qo\'shib bo\'lmadi'
  } finally {
    savingOff.value = false
  }
}

async function removeTimeOff(t) {
  if (!(await confirm({ message: 'Dam olish davri o\'chirilsinmi?', danger: true, confirmText: 'O‘chirish' }))) return
  try {
    await api.del(`/v1/staff/${staffId.value}/time-off/${t.id}`)
    await loadSchedule()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'O\'chirib bo\'lmadi'
  }
}

watch(staffId, loadSchedule)
onMounted(async () => {
  await loadStaff()
  await loadSchedule()
})
</script>

<template>
  <div>
    <div class="page-head">
      <h1>Ish jadvali</h1>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div v-if="loadingStaff" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>
    <div v-else-if="!staff.length" class="empty card">
      Avval <RouterLink to="/staff">xodim qo'shing</RouterLink>.
    </div>

    <template v-else>
      <div class="field" style="max-width: 320px">
        <label>Xodim</label>
        <select v-model="staffId">
          <option v-for="s in staff" :key="s.id" :value="s.id">{{ s.name }}</option>
        </select>
      </div>

      <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

      <div v-else class="grid">
        <section class="card">
          <div class="hours-head">
            <h2 style="font-size: 16px; margin: 0">Haftalik ish vaqti</h2>
            <div class="row" style="gap: 12px">
              <label class="row check-all" style="gap: 8px; margin: 0; cursor: pointer">
                <input
                  v-model="allEnabled"
                  type="checkbox"
                  style="width: auto"
                  :indeterminate="someEnabled"
                />
                <span>Barcha kunlar</span>
              </label>
              <button type="button" class="btn btn-sm" @click="applyTimesToAll">
                Vaqtni hammasiga qo'llash
              </button>
            </div>
          </div>
          <div class="hours">
            <div v-for="(h, i) in hours" :key="h.weekday" class="day-row" :class="{ off: !h.enabled }">
              <label class="day" style="cursor: pointer">
                <input v-model="h.enabled" type="checkbox" style="width: auto" />
                <span>{{ WEEKDAYS[i].l }}</span>
              </label>

              <div class="ivs">
                <div v-for="(iv, k) in h.intervals" :key="k" class="iv">
                  <input v-model="iv.start" type="time" :disabled="!h.enabled" />
                  <span class="dash">–</span>
                  <input v-model="iv.end" type="time" :disabled="!h.enabled" />
                  <button
                    v-if="h.intervals.length > 1"
                    type="button"
                    class="iv-x"
                    :disabled="!h.enabled"
                    title="Oraliqni o'chirish"
                    @click="removeInterval(h, k)"
                  >
                    ×
                  </button>
                </div>

                <div class="iv-actions">
                  <button
                    v-if="!hasBreak(h)"
                    type="button"
                    class="link-btn"
                    :disabled="!h.enabled"
                    @click="addBreak(h)"
                  >
                    + Tanaffus
                  </button>
                  <button
                    type="button"
                    class="link-btn"
                    :disabled="!h.enabled"
                    @click="addInterval(h)"
                  >
                    + Oraliq
                  </button>
                </div>
              </div>
            </div>
          </div>
          <div class="row" style="margin-top: 16px; gap: 12px">
            <button class="btn btn-primary" :disabled="savingHours" @click="saveHours">
              {{ savingHours ? 'Saqlanmoqda…' : 'Saqlash' }}
            </button>
            <span v-if="hoursSaved" style="color: var(--success); font-weight: 600">✓ Saqlandi</span>
          </div>
        </section>

        <section class="card">
          <h2 style="font-size: 16px">Dam olish / ta'til</h2>

          <div v-if="!timeOff.length" class="muted" style="padding: 8px 0">Yozuvlar yo'q.</div>
          <ul v-else class="off-list">
            <li v-for="t in timeOff" :key="t.id">
              <div>
                <strong>{{ (t.starts_at || '').slice(0, 16).replace('T', ' ') }}</strong>
                <span class="muted"> → {{ (t.ends_at || '').slice(0, 16).replace('T', ' ') }}</span>
                <div v-if="t.reason" class="muted" style="font-size: 12px">{{ t.reason }}</div>
              </div>
              <button class="btn btn-sm btn-danger" @click="removeTimeOff(t)">O'chirish</button>
            </li>
          </ul>

          <form class="off-form" @submit.prevent="addTimeOff">
            <div class="field-row">
              <div class="field">
                <label>Boshlanishi</label>
                <input v-model="toForm.starts_at" type="datetime-local" required />
              </div>
              <div class="field">
                <label>Tugashi</label>
                <input v-model="toForm.ends_at" type="datetime-local" />
              </div>
            </div>
            <div class="field">
              <label>Sabab</label>
              <input v-model="toForm.reason" placeholder="Ta'til, kasallik…" />
            </div>
            <button class="btn" :disabled="savingOff" type="submit">
              {{ savingOff ? 'Qo\'shilmoqda…' : '+ Qo\'shish' }}
            </button>
          </form>
        </section>
      </div>
    </template>
  </div>
</template>

<style scoped>
.grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 18px;
  margin-top: 8px;
}
@media (max-width: 820px) {
  .grid { grid-template-columns: 1fr; }
}
.hours-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 10px;
  margin-bottom: 10px;
}
.check-all {
  font-weight: 550;
  white-space: nowrap;
}
.hours {
  display: flex;
  flex-direction: column;
}
.day-row {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 8px 0;
  border-top: 1px solid var(--border);
}
.day-row:first-child {
  border-top: 0;
}
.day-row.off {
  opacity: 0.55;
}
.hours .day {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 118px;
  padding-top: 7px;
  font-weight: 550;
}
.ivs {
  display: flex;
  flex-direction: column;
  gap: 6px;
  flex: 1;
  min-width: 0;
}
.iv {
  display: flex;
  align-items: center;
  gap: 6px;
}
.hours .dash {
  color: var(--text-muted);
}
.hours input[type='time'] {
  padding: 6px 8px;
  width: auto;
}
.iv-x {
  border: 1px solid var(--border);
  background: transparent;
  color: var(--text-muted);
  border-radius: 6px;
  width: 26px;
  height: 26px;
  line-height: 1;
  cursor: pointer;
}
.iv-x:hover {
  color: var(--danger, #ef4444);
  border-color: currentColor;
}
.iv-actions {
  display: flex;
  gap: 12px;
}
.link-btn {
  border: 0;
  background: none;
  padding: 0;
  color: var(--primary);
  font: inherit;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
}
.link-btn:disabled {
  color: var(--text-muted);
  cursor: default;
}
.off-list {
  list-style: none;
  margin: 8px 0 18px;
  padding: 0;
}
.off-list li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  padding: 10px 0;
  border-bottom: 1px solid var(--border);
}
.off-form {
  border-top: 1px solid var(--border);
  padding-top: 14px;
}
</style>
