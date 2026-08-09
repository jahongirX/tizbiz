<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import {
  todayInput,
  addDays,
  mondayOf,
  localDayStartUtc,
  localDayEndUtc,
  localDateInput,
  localMinutes,
  minutesToHhmm,
  nowLocalMinutes,
  formatWeekRange,
  formatTime,
  dayNum,
} from '../lib/datetime'
import Modal from '../components/Modal.vue'
import AppointmentForm from '../components/AppointmentForm.vue'
import { selectedDate, setSelectedDate } from '../composables/useCalendar'

const HOUR_PX = 56
const SNAP_MIN = 30
const DEFAULT_START = 8 * 60
const DEFAULT_END = 21 * 60

const WEEKDAYS = ['Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba']
const WEEKDAYS_SHORT = ['Du', 'Se', 'Cho', 'Pay', 'Ju', 'Sha', 'Yak']

const STATUSES = [
  { v: 'pending', l: 'Kutilmoqda' },
  { v: 'confirmed', l: 'Tasdiqlangan' },
  { v: 'arrived', l: 'Keldi' },
  { v: 'completed', l: 'Yakunlandi' },
  { v: 'no_show', l: 'Kelmadi' },
  { v: 'canceled', l: 'Bekor qilindi' },
]
const statusLabel = Object.fromEntries(STATUSES.map((s) => [s.v, s.l]))

// Sensible forward transitions from each status.
const TRANSITIONS = {
  pending: ['confirmed', 'arrived', 'no_show', 'canceled'],
  confirmed: ['arrived', 'no_show', 'canceled'],
  arrived: ['completed', 'no_show'],
  completed: [],
  no_show: ['pending'],
  canceled: ['pending'],
}

/* ---------- state ---------- */
const staff = ref([])
const services = ref([])
const staffId = ref(null)
const loadingStaff = ref(true)
const loading = ref(false)
const error = ref('')

const anchor = ref(selectedDate.value) // any day within the shown week; mirrors the shared calendar date
const workingHours = ref([]) // normalized [{col, startMin, endMin}]
const appointments = ref([])

const today = ref(todayInput())
const nowMin = ref(nowLocalMinutes())
let nowTimer = null

/* ---------- week model ---------- */
const monday = computed(() => mondayOf(anchor.value))
const weekDays = computed(() => {
  const days = []
  for (let i = 0; i < 7; i++) {
    const date = addDays(monday.value, i)
    days.push({ index: i, date, name: WEEKDAYS[i], short: WEEKDAYS_SHORT[i], isToday: date === today.value })
  }
  return days
})
const weekRangeLabel = computed(() => formatWeekRange(monday.value, addDays(monday.value, 6)))

/* Visible vertical range (minutes), derived from working hours + appointments. */
const range = computed(() => {
  let min = DEFAULT_START
  let max = DEFAULT_END
  for (const w of workingHours.value) {
    min = Math.min(min, w.startMin)
    max = Math.max(max, w.endMin)
  }
  for (const a of appointments.value) {
    const s = localMinutes(a.starts_at)
    let e = localMinutes(a.ends_at)
    if (s == null) continue
    if (e == null || e <= s) e = s + (Number(a.service_duration) || 30)
    min = Math.min(min, s)
    max = Math.max(max, e)
  }
  min = Math.max(0, Math.floor(min / 60) * 60)
  max = Math.min(1440, Math.ceil(max / 60) * 60)
  if (max - min < 120) max = Math.min(1440, min + 120)
  return { start: min, end: max }
})
const gridHeight = computed(() => ((range.value.end - range.value.start) / 60) * HOUR_PX)
const hourMarks = computed(() => {
  const marks = []
  for (let m = range.value.start; m <= range.value.end; m += 60) marks.push(m)
  return marks
})
const showNowLine = computed(
  () =>
    weekDays.value.some((d) => d.isToday) &&
    nowMin.value >= range.value.start &&
    nowMin.value <= range.value.end,
)
function minToTop(min) {
  return ((min - range.value.start) / 60) * HOUR_PX
}

/* Working-hours band per day column (by weekday). */
function bandFor(dayIndex) {
  // dayIndex 0=Mon..6=Sun -> our normalized col is the same 0..6.
  const w = workingHours.value.find((x) => x.col === dayIndex)
  if (!w) return null
  return {
    top: minToTop(w.startMin),
    height: ((w.endMin - w.startMin) / 60) * HOUR_PX,
    label: `${minutesToHhmm(w.startMin)} - ${minutesToHhmm(w.endMin)}`,
  }
}

/* Appointment blocks, laid out per day with overlap lanes. */
const blocksByDay = computed(() => {
  const map = {}
  for (let i = 0; i < 7; i++) map[i] = []
  for (const a of appointments.value) {
    const date = localDateInput(a.starts_at)
    const day = weekDays.value.findIndex((d) => d.date === date)
    if (day < 0) continue
    const startMin = localMinutes(a.starts_at)
    if (startMin == null) continue
    let endMin = localMinutes(a.ends_at)
    if (endMin == null || endMin <= startMin) endMin = startMin + (Number(a.service_duration) || 30)
    map[day].push({ appt: a, startMin, endMin, lane: 0, lanes: 1 })
  }
  for (let i = 0; i < 7; i++) layoutLanes(map[i])
  return map
})

function layoutLanes(dayBlocks) {
  dayBlocks.sort((a, b) => a.startMin - b.startMin || a.endMin - b.endMin)
  let cluster = []
  let clusterEnd = -1
  const flush = () => {
    const laneEnds = []
    for (const b of cluster) {
      let placed = false
      for (let i = 0; i < laneEnds.length; i++) {
        if (laneEnds[i] <= b.startMin) {
          b.lane = i
          laneEnds[i] = b.endMin
          placed = true
          break
        }
      }
      if (!placed) {
        b.lane = laneEnds.length
        laneEnds.push(b.endMin)
      }
    }
    for (const b of cluster) b.lanes = laneEnds.length
    cluster = []
  }
  for (const b of dayBlocks) {
    if (cluster.length && b.startMin >= clusterEnd) {
      flush()
      clusterEnd = -1
    }
    cluster.push(b)
    clusterEnd = Math.max(clusterEnd, b.endMin)
  }
  if (cluster.length) flush()
}

function blockStyle(b) {
  const top = minToTop(b.startMin)
  const height = Math.max(((b.endMin - b.startMin) / 60) * HOUR_PX, 22)
  const w = 100 / b.lanes
  return {
    top: top + 'px',
    height: height - 2 + 'px',
    left: `calc(${b.lane * w}% + 2px)`,
    width: `calc(${w}% - 4px)`,
  }
}

/* ---------- data loading ---------- */
function hhmmToMin(v) {
  if (!v) return null
  const m = String(v).match(/(\d{1,2}):(\d{2})/)
  return m ? Number(m[1]) * 60 + Number(m[2]) : null
}

function normalizeWorkingHours(rows) {
  const list = Array.isArray(rows) ? rows : rows?.items || rows?.days || []
  const out = []
  for (const r of list) {
    const raw = Number(r.weekday ?? r.day)
    // API: 1=Mon..7=Sun. Be tolerant of 0=Sun too.
    let col
    if (raw === 0 || raw === 7) col = 6
    else col = raw - 1
    if (col < 0 || col > 6) continue
    const s = hhmmToMin(r.start_time || r.start)
    const e = hhmmToMin(r.end_time || r.end)
    if (s == null || e == null || e <= s) continue
    out.push({ col, startMin: s, endMin: e })
  }
  return out
}

async function loadStaff() {
  loadingStaff.value = true
  try {
    const [st, sv] = await Promise.all([
      api.get('/v1/staff'),
      api.get('/v1/services').catch(() => []),
    ])
    const list = Array.isArray(st) ? st : st?.items || []
    staff.value = list
    services.value = Array.isArray(sv) ? sv : sv?.items || []
    if (staffId.value == null) {
      const firstActive = list.find((s) => s.is_active) || list[0]
      staffId.value = firstActive ? firstActive.id : null
    }
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Xodimlarni yuklab bo\'lmadi'
  } finally {
    loadingStaff.value = false
  }
}

async function load() {
  if (!staffId.value) return
  loading.value = true
  error.value = ''
  try {
    const sunday = addDays(monday.value, 6)
    const params = new URLSearchParams()
    params.set('from', localDayStartUtc(monday.value))
    params.set('to', localDayEndUtc(sunday))
    params.set('staff', String(staffId.value))
    const [wh, appts] = await Promise.all([
      api.get(`/v1/staff/${staffId.value}/working-hours`).catch(() => []),
      api.get('/v1/appointments?' + params.toString()),
    ])
    workingHours.value = normalizeWorkingHours(wh)
    appointments.value = Array.isArray(appts) ? appts : appts?.items || []
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Jadvalni yuklab bo\'lmadi'
    appointments.value = []
  } finally {
    loading.value = false
  }
}

/* ---------- navigation ---------- */
// All week/day navigation flows through the shared selectedDate so the sidebar
// MiniCalendar stays in sync. The watcher below mirrors it back into `anchor`,
// which re-derives the visible week without remounting the view.
watch(selectedDate, (d) => {
  anchor.value = d
})

function prevWeek() {
  setSelectedDate(addDays(selectedDate.value, -7))
}
function nextWeek() {
  setSelectedDate(addDays(selectedDate.value, 7))
}
function goToday() {
  setSelectedDate(todayInput())
}

watch([staffId, monday], load)

/* ---------- detail popover ---------- */
const detail = ref(null) // the appointment
const detailError = ref('')
const savingStatus = ref(false)

function openDetail(appt) {
  detail.value = appt
  detailError.value = ''
}
function closeDetail() {
  detail.value = null
}
const detailTransitions = computed(() =>
  detail.value ? TRANSITIONS[detail.value.status] || [] : [],
)

async function setStatus(status) {
  if (!detail.value) return
  savingStatus.value = true
  detailError.value = ''
  try {
    await api.patch('/v1/appointments/' + detail.value.id, { status })
    closeDetail()
    await load()
  } catch (e) {
    detailError.value = e instanceof ApiError ? e.message : 'Holatni o\'zgartirib bo\'lmadi'
  } finally {
    savingStatus.value = false
  }
}

/* ---------- create (rich form) ---------- */
const showCreate = ref(false)
const createInitial = ref({})

function openCreate(dateStr, hhmm) {
  createInitial.value = { staffId: staffId.value, date: dateStr, time: hhmm }
  showCreate.value = true
}

function onColClick(e, dayStr) {
  const rect = e.currentTarget.getBoundingClientRect()
  const y = e.clientY - rect.top
  let min = range.value.start + (y / HOUR_PX) * 60
  min = Math.round(min / SNAP_MIN) * SNAP_MIN
  min = Math.max(range.value.start, Math.min(range.value.end - SNAP_MIN, min))
  openCreate(dayStr, minutesToHhmm(min))
}

async function onCreated() {
  showCreate.value = false
  await load()
}

/* ---------- lifecycle ---------- */
onMounted(async () => {
  await loadStaff()
  await load()
  nowTimer = setInterval(() => {
    nowMin.value = nowLocalMinutes()
    today.value = todayInput()
  }, 60000)
})
onBeforeUnmount(() => {
  if (nowTimer) clearInterval(nowTimer)
})
</script>

<template>
  <div class="tt">
    <div class="page-head">
      <h1>Jadval</h1>
      <button class="btn btn-primary" :disabled="!staffId" @click="openCreate(today, '09:00')">
        + Yangi yozuv
      </button>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div v-if="loadingStaff" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>
    <div v-else-if="!staff.length" class="empty card">
      Avval <RouterLink to="/staff">xodim qo'shing</RouterLink>.
    </div>

    <template v-else>
      <!-- Toolbar -->
      <div class="tt-toolbar card">
        <div class="field tt-staff">
          <label>Xodim</label>
          <select v-model="staffId">
            <option v-for="s in staff" :key="s.id" :value="s.id">
              {{ s.name }}<template v-if="s.specialization"> · {{ s.specialization }}</template>
            </option>
          </select>
        </div>
        <div class="tt-nav">
          <button class="btn btn-sm" aria-label="Oldingi hafta" @click="prevWeek">‹</button>
          <button class="btn btn-sm" @click="goToday">Bugun</button>
          <button class="btn btn-sm" aria-label="Keyingi hafta" @click="nextWeek">›</button>
          <span class="tt-range">{{ weekRangeLabel }}</span>
        </div>
      </div>

      <!-- Calendar -->
      <div class="tt-scroll card">
        <div class="tt-inner">
          <!-- Header row -->
          <div class="tt-head">
            <div class="tt-gutter-head"></div>
            <div
              v-for="d in weekDays"
              :key="d.date"
              class="tt-day-head"
              :class="{ today: d.isToday }"
            >
              <span class="dh-name">{{ d.name }}</span>
              <span class="dh-num">{{ dayNum(d.date) }}</span>
            </div>
          </div>

          <div v-if="loading" class="tt-loading"><span class="spinner"></span></div>

          <!-- Body -->
          <div class="tt-body" :style="{ height: gridHeight + 'px' }">
            <!-- time gutter -->
            <div class="tt-gutter">
              <div
                v-for="m in hourMarks"
                :key="m"
                class="tt-hour-label"
                :style="{ top: minToTop(m) + 'px' }"
              >
                {{ minutesToHhmm(m) }}
              </div>
            </div>

            <!-- day columns -->
            <div
              v-for="d in weekDays"
              :key="d.date"
              class="tt-col"
              :class="{ today: d.isToday }"
              @click="onColClick($event, d.date)"
            >
              <!-- hour grid lines -->
              <div
                v-for="m in hourMarks"
                :key="'l' + m"
                class="tt-line"
                :style="{ top: minToTop(m) + 'px' }"
              ></div>

              <!-- working band -->
              <div
                v-if="bandFor(d.index)"
                class="tt-band"
                :style="{ top: bandFor(d.index).top + 'px', height: bandFor(d.index).height + 'px' }"
              >
                <span class="band-label">{{ bandFor(d.index).label }}</span>
              </div>

              <!-- now line -->
              <div
                v-if="showNowLine && d.isToday"
                class="tt-now"
                :style="{ top: minToTop(nowMin) + 'px' }"
              ></div>

              <!-- appointment blocks -->
              <button
                v-for="b in blocksByDay[d.index]"
                :key="b.appt.id"
                type="button"
                class="tt-appt"
                :class="b.appt.status"
                :style="blockStyle(b)"
                @click.stop="openDetail(b.appt)"
              >
                <span class="ap-time">{{ formatTime(b.appt.starts_at) }}</span>
                <span class="ap-service">{{ b.appt.service_name || 'Xizmat' }}</span>
                <span class="ap-client">{{ b.appt.client_name || '—' }}</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- Detail popover -->
    <Modal v-if="detail" :title="detail.service_name || 'Yozuv'" @close="closeDetail">
      <div v-if="detailError" class="alert alert-error">{{ detailError }}</div>
      <dl class="tt-detail">
        <div>
          <dt>Vaqt</dt>
          <dd>{{ formatTime(detail.starts_at) }}<template v-if="detail.ends_at"> – {{ formatTime(detail.ends_at) }}</template></dd>
        </div>
        <div>
          <dt>Xizmat</dt>
          <dd>{{ detail.service_name || '—' }}</dd>
        </div>
        <div>
          <dt>Mijoz</dt>
          <dd>{{ detail.client_name || '—' }}</dd>
        </div>
        <div>
          <dt>Telefon</dt>
          <dd>
            <a v-if="detail.client_phone" :href="'tel:' + detail.client_phone">{{ detail.client_phone }}</a>
            <span v-else>—</span>
          </dd>
        </div>
        <div>
          <dt>Holat</dt>
          <dd><span class="badge" :class="detail.status">{{ statusLabel[detail.status] || detail.status }}</span></dd>
        </div>
        <div v-if="detail.paid != null">
          <dt>To'lov</dt>
          <dd>{{ detail.paid ? 'To\'langan' : 'To\'lanmagan' }}</dd>
        </div>
      </dl>

      <template #footer>
        <button class="btn" @click="closeDetail">Yopish</button>
        <button
          v-for="s in detailTransitions"
          :key="s"
          class="btn"
          :class="s === 'canceled' || s === 'no_show' ? 'btn-danger' : 'btn-primary'"
          :disabled="savingStatus"
          @click="setStatus(s)"
        >
          {{ statusLabel[s] }}
        </button>
      </template>
    </Modal>

    <!-- Create appointment (rich 3-column form) -->
    <Modal v-if="showCreate" title="Yangi yozuv" wide @close="showCreate = false">
      <AppointmentForm
        :initial="createInitial"
        @created="onCreated"
        @cancel="showCreate = false"
      />
    </Modal>
  </div>
</template>

<style scoped>
/* Widen the create-appointment modal for the 3-column form. */
.tt :deep(.modal.wide) {
  max-width: 1040px;
}

.tt-toolbar {
  display: flex;
  align-items: flex-end;
  gap: 18px;
  flex-wrap: wrap;
  padding: 14px 16px;
  margin-bottom: 16px;
}
.tt-staff {
  margin-bottom: 0;
  min-width: 220px;
}
.tt-nav {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-left: auto;
}
.tt-nav .btn {
  padding: 6px 12px;
}
.tt-range {
  font-weight: 650;
  font-size: 15px;
  margin-left: 6px;
  white-space: nowrap;
}

/* Calendar shell */
.tt-scroll {
  padding: 0;
  overflow-x: auto;
}
.tt-inner {
  min-width: 720px;
}

.tt-head {
  display: grid;
  grid-template-columns: 56px repeat(7, minmax(96px, 1fr));
  position: sticky;
  top: 0;
  z-index: 3;
  background: var(--surface);
  border-bottom: 1px solid var(--border);
}
.tt-gutter-head {
  border-right: 1px solid var(--border);
}
.tt-day-head {
  display: flex;
  align-items: center;
  gap: 7px;
  justify-content: center;
  padding: 10px 4px;
  border-right: 1px solid var(--border);
  font-size: 13px;
}
.tt-day-head:last-child {
  border-right: none;
}
.tt-day-head .dh-name {
  font-weight: 600;
}
.tt-day-head .dh-num {
  color: var(--text-muted);
  font-weight: 600;
}
.tt-day-head.today {
  color: var(--primary);
  background: var(--primary-soft);
}
.tt-day-head.today .dh-num {
  color: var(--primary);
}

.tt-loading {
  display: flex;
  justify-content: center;
  padding: 30px;
}

.tt-body {
  display: grid;
  grid-template-columns: 56px repeat(7, minmax(96px, 1fr));
  position: relative;
}

/* time gutter */
.tt-gutter {
  position: relative;
  border-right: 1px solid var(--border);
}
.tt-hour-label {
  position: absolute;
  right: 6px;
  transform: translateY(-50%);
  font-size: 11.5px;
  color: var(--text-muted);
  font-variant-numeric: tabular-nums;
}

/* day column */
.tt-col {
  position: relative;
  border-right: 1px solid var(--border);
  cursor: pointer;
}
.tt-col:last-child {
  border-right: none;
}
.tt-col.today {
  background: color-mix(in srgb, var(--primary-soft) 45%, transparent);
}
.tt-line {
  position: absolute;
  left: 0;
  right: 0;
  border-top: 1px solid var(--border);
  pointer-events: none;
}

/* working-hours band */
.tt-band {
  position: absolute;
  left: 0;
  right: 0;
  background: color-mix(in srgb, var(--success) 12%, transparent);
  border-top: 1px solid color-mix(in srgb, var(--success) 40%, transparent);
  border-bottom: 1px solid color-mix(in srgb, var(--success) 40%, transparent);
  pointer-events: none;
}
.band-label {
  position: absolute;
  top: 3px;
  left: 5px;
  font-size: 10.5px;
  font-weight: 600;
  color: var(--success);
  opacity: 0.9;
}

/* now line */
.tt-now {
  position: absolute;
  left: 0;
  right: 0;
  height: 2px;
  background: var(--danger);
  z-index: 4;
  pointer-events: none;
}
.tt-now::before {
  content: '';
  position: absolute;
  left: -3px;
  top: -3px;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--danger);
}

/* appointment block */
.tt-appt {
  position: absolute;
  display: flex;
  flex-direction: column;
  gap: 1px;
  overflow: hidden;
  text-align: left;
  padding: 3px 5px;
  border: 1px solid transparent;
  border-left-width: 3px;
  border-radius: 6px;
  font: inherit;
  cursor: pointer;
  z-index: 2;
  transition: filter 0.12s;
}
.tt-appt:hover {
  filter: brightness(1.04);
  z-index: 5;
}
.tt-appt .ap-time {
  font-size: 11px;
  font-weight: 700;
  line-height: 1.2;
}
.tt-appt .ap-service {
  font-size: 11.5px;
  font-weight: 600;
  line-height: 1.2;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.tt-appt .ap-client {
  font-size: 11px;
  opacity: 0.85;
  line-height: 1.2;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* status colors — reuse badge palette */
.tt-appt.pending { background: #fef3c7; color: #92400e; border-color: #92400e; }
.tt-appt.confirmed { background: #dbeafe; color: #1e40af; border-color: #1e40af; }
.tt-appt.arrived { background: #e0e7ff; color: #3730a3; border-color: #3730a3; }
.tt-appt.completed { background: #dcfce7; color: #166534; border-color: #166534; }
.tt-appt.no_show { background: #fee2e2; color: #991b1b; border-color: #991b1b; }
.tt-appt.canceled { background: #f3f4f6; color: #6b7280; border-color: #9ca3af; }
.tt-appt.canceled .ap-service { text-decoration: line-through; }
@media (prefers-color-scheme: dark) {
  .tt-appt.pending { background: #3a2e12; color: #fbbf24; border-color: #fbbf24; }
  .tt-appt.confirmed { background: #14284a; color: #93c5fd; border-color: #60a5fa; }
  .tt-appt.arrived { background: #1e1b4b; color: #a5b4fc; border-color: #818cf8; }
  .tt-appt.completed { background: #14331f; color: #86efac; border-color: #4ade80; }
  .tt-appt.no_show { background: #3a1616; color: #fca5a5; border-color: #f87171; }
  .tt-appt.canceled { background: #262a31; color: #9aa1ac; border-color: #4b5563; }
}

/* detail list */
.tt-detail {
  margin: 0;
  display: grid;
  gap: 10px;
}
.tt-detail > div {
  display: grid;
  grid-template-columns: 90px 1fr;
  gap: 10px;
  align-items: baseline;
}
.tt-detail dt {
  font-size: 12.5px;
  font-weight: 600;
  color: var(--text-muted);
  margin: 0;
}
.tt-detail dd {
  margin: 0;
  font-weight: 550;
}

/* client search dropdown (shared with Appointments look) */
.cli-drop {
  list-style: none;
  margin: 4px 0 0;
  padding: 4px;
  position: absolute;
  z-index: 5;
  left: 0;
  right: 0;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  box-shadow: var(--shadow);
  max-height: 200px;
  overflow-y: auto;
}
.cli-drop li {
  padding: 8px 10px;
  border-radius: 6px;
  cursor: pointer;
}
.cli-drop li:hover {
  background: var(--surface-2);
}

@media (max-width: 860px) {
  .tt-nav {
    margin-left: 0;
    width: 100%;
  }
  .tt-range {
    margin-left: auto;
  }
}
</style>
