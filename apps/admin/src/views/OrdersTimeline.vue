<script setup>
/**
 * Catalog (cafe / tort) "Jadval": a read-only weekly timeline of when orders
 * came in. No appointments, no "+ Yangi yozuv" — each order is a block at its
 * created time so the owner sees, per day, at what time how many orders arrived.
 */
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import {
  todayInput,
  addDays,
  mondayOf,
  localMinutes,
  localDateInput,
  minutesToHhmm,
  nowLocalMinutes,
  formatWeekRange,
  formatTime,
  dayNum,
} from '../lib/datetime'
import Modal from '../components/Modal.vue'
import { selectedDate, setSelectedDate } from '../composables/useCalendar'

const HOUR_PX = 56
const DEFAULT_START = 8 * 60
const DEFAULT_END = 21 * 60
const BLOCK_MIN = 30 // visual height for a point-in-time order

const WEEKDAYS = ['Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba']

const STATUS = [
  { v: 'new', l: 'Yangi', c: '#3b82f6' },
  { v: 'confirmed', l: 'Tasdiqlangan', c: '#8b5cf6' },
  { v: 'preparing', l: 'Tayyorlanmoqda', c: '#f59e0b' },
  { v: 'ready', l: 'Tayyor', c: '#10b981' },
  { v: 'delivered', l: 'Yetkazildi', c: '#6b7280' },
  { v: 'cancelled', l: 'Bekor qilingan', c: '#ef4444' },
]
const statusOf = (v) => STATUS.find((s) => s.v === v) || { l: v, c: '#6b7280' }
const soms = (t) => Math.round((Number(t) || 0) / 100).toLocaleString('ru-RU') + " so'm"

/* ---------- state ---------- */
const orders = ref([])
const loading = ref(false)
const error = ref('')
const anchor = ref(selectedDate.value)
const today = ref(todayInput())
const nowMin = ref(nowLocalMinutes())
let nowTimer = null

/* ---------- week model ---------- */
const monday = computed(() => mondayOf(anchor.value))
const weekDays = computed(() => {
  const days = []
  for (let i = 0; i < 7; i++) {
    const date = addDays(monday.value, i)
    days.push({ index: i, date, name: WEEKDAYS[i], isToday: date === today.value })
  }
  return days
})
const weekRangeLabel = computed(() => formatWeekRange(monday.value, addDays(monday.value, 6)))

/* ---------- order blocks per day ---------- */
const blocksByDay = computed(() => {
  const map = {}
  for (let i = 0; i < 7; i++) map[i] = []
  for (const o of orders.value) {
    const date = localDateInput(o.created_at)
    const day = weekDays.value.findIndex((d) => d.date === date)
    if (day < 0) continue
    const startMin = localMinutes(o.created_at)
    if (startMin == null) continue
    map[day].push({ order: o, startMin, endMin: startMin + BLOCK_MIN, lane: 0, lanes: 1 })
  }
  for (let i = 0; i < 7; i++) layoutLanes(map[i])
  return map
})

const dayCount = (i) => blocksByDay.value[i].length
const daySum = (i) => blocksByDay.value[i].reduce((s, b) => s + (b.order.total_tiyin || 0), 0)
const weekCount = computed(() => weekDays.value.reduce((s, d) => s + dayCount(d.index), 0))
const weekSum = computed(() => weekDays.value.reduce((s, d) => s + daySum(d.index), 0))

/* ---------- vertical range ---------- */
const range = computed(() => {
  let min = DEFAULT_START
  let max = DEFAULT_END
  for (let i = 0; i < 7; i++) {
    for (const b of blocksByDay.value[i]) {
      min = Math.min(min, b.startMin)
      max = Math.max(max, b.endMin)
    }
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
  () => weekDays.value.some((d) => d.isToday) && nowMin.value >= range.value.start && nowMin.value <= range.value.end,
)
const minToTop = (min) => ((min - range.value.start) / 60) * HOUR_PX

function layoutLanes(dayBlocks) {
  dayBlocks.sort((a, b) => a.startMin - b.startMin || a.endMin - b.endMin)
  let cluster = []
  let clusterEnd = -1
  const flush = () => {
    const laneEnds = []
    for (const b of cluster) {
      let placed = false
      for (let i = 0; i < laneEnds.length; i++) {
        if (laneEnds[i] <= b.startMin) { b.lane = i; laneEnds[i] = b.endMin; placed = true; break }
      }
      if (!placed) { b.lane = laneEnds.length; laneEnds.push(b.endMin) }
    }
    for (const b of cluster) b.lanes = laneEnds.length
    cluster = []
  }
  for (const b of dayBlocks) {
    if (cluster.length && b.startMin >= clusterEnd) { flush(); clusterEnd = -1 }
    cluster.push(b)
    clusterEnd = Math.max(clusterEnd, b.endMin)
  }
  if (cluster.length) flush()
}

function blockStyle(b) {
  const top = minToTop(b.startMin)
  const height = Math.max(((b.endMin - b.startMin) / 60) * HOUR_PX, 44)
  const w = 100 / b.lanes
  return { top: top + 'px', height: height - 2 + 'px', left: `calc(${b.lane * w}% + 2px)`, width: `calc(${w}% - 4px)` }
}

/* ---------- data ---------- */
async function load() {
  loading.value = true
  error.value = ''
  try {
    orders.value = await api.get('/v1/orders')
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Buyurtmalarni yuklab bo\'lmadi'
    orders.value = []
  } finally {
    loading.value = false
  }
}

/* ---------- navigation (shared with sidebar MiniCalendar) ---------- */
watch(selectedDate, (d) => { anchor.value = d })
const prevWeek = () => setSelectedDate(addDays(selectedDate.value, -7))
const nextWeek = () => setSelectedDate(addDays(selectedDate.value, 7))
const goToday = () => setSelectedDate(todayInput())

/* ---------- detail ---------- */
const detail = ref(null)
const openDetail = (o) => { detail.value = o }

onMounted(() => {
  load()
  nowTimer = setInterval(() => { nowMin.value = nowLocalMinutes(); today.value = todayInput() }, 60000)
})
onBeforeUnmount(() => { if (nowTimer) clearInterval(nowTimer) })
</script>

<template>
  <div class="tt">
    <div class="page-head">
      <div>
        <h1>Jadval</h1>
        <p class="muted">Buyurtmalar oqimi — qaysi kuni, qaysi vaqtda nechta buyurtma keldi</p>
      </div>
      <div class="ot-week muted">{{ weekCount }} ta · <strong>{{ soms(weekSum) }}</strong></div>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <!-- Toolbar (no staff selector, no create) -->
    <div class="tt-toolbar card">
      <div class="tt-nav">
        <button class="btn btn-sm" aria-label="Oldingi hafta" @click="prevWeek">‹</button>
        <button class="btn btn-sm" @click="goToday">Bugun</button>
        <button class="btn btn-sm" aria-label="Keyingi hafta" @click="nextWeek">›</button>
        <span class="tt-range">{{ weekRangeLabel }}</span>
      </div>
    </div>

    <div class="tt-scroll card">
      <div class="tt-inner">
        <!-- header -->
        <div class="tt-head">
          <div class="tt-gutter-head"></div>
          <div v-for="d in weekDays" :key="d.date" class="tt-day-head" :class="{ today: d.isToday }">
            <span class="dh-name">{{ d.name }}</span>
            <span class="dh-num">{{ dayNum(d.date) }}</span>
            <span v-if="dayCount(d.index)" class="dh-count">{{ dayCount(d.index) }}</span>
          </div>
        </div>

        <div v-if="loading" class="tt-loading"><span class="spinner"></span></div>

        <!-- body -->
        <div class="tt-body" :style="{ height: gridHeight + 'px' }">
          <div class="tt-gutter">
            <div v-for="m in hourMarks" :key="m" class="tt-hour-label" :style="{ top: minToTop(m) + 'px' }">
              {{ minutesToHhmm(m) }}
            </div>
          </div>

          <div v-for="d in weekDays" :key="d.date" class="tt-col" :class="{ today: d.isToday }">
            <div v-for="m in hourMarks" :key="'l' + m" class="tt-line" :style="{ top: minToTop(m) + 'px' }"></div>

            <div v-if="showNowLine && d.isToday" class="tt-now" :style="{ top: minToTop(nowMin) + 'px' }"></div>

            <button
              v-for="b in blocksByDay[d.index]"
              :key="b.order.id"
              type="button"
              class="ot-block"
              :style="{ ...blockStyle(b), '--c': statusOf(b.order.status).c }"
              @click="openDetail(b.order)"
            >
              <span class="ob-time">{{ formatTime(b.order.created_at) }}</span>
              <span class="ob-main">#{{ b.order.id }} · {{ soms(b.order.total_tiyin) }}</span>
              <span class="ob-cust">{{ b.order.customer_name || '—' }}</span>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- detail -->
    <Modal v-if="detail" :title="`Buyurtma #${detail.id}`" @close="detail = null">
      <div class="od-head">
        <span class="badge" :style="{ background: statusOf(detail.status).c + '22', color: statusOf(detail.status).c }">
          {{ statusOf(detail.status).l }}
        </span>
        <span class="muted">{{ formatTime(detail.created_at) }}</span>
      </div>
      <div class="od-cust">
        <strong>{{ detail.customer_name || 'Mijoz' }}</strong>
        <a v-if="detail.customer_phone" :href="`tel:${detail.customer_phone}`">{{ detail.customer_phone }}</a>
      </div>
      <ul class="od-items">
        <li v-for="i in detail.items" :key="i.id">
          <span>{{ i.name }} × {{ i.qty }}</span>
          <span class="muted">{{ soms(i.price_tiyin * i.qty) }}</span>
        </li>
      </ul>
      <p v-if="detail.note" class="od-note">📝 {{ detail.note }}</p>
      <div class="od-total"><span>Jami</span><strong>{{ soms(detail.total_tiyin) }}</strong></div>
      <template #footer>
        <button class="btn" @click="detail = null">Yopish</button>
        <RouterLink class="btn btn-primary" to="/orders">Buyurtmalarga o'tish</RouterLink>
      </template>
    </Modal>
  </div>
</template>

<style scoped>
.page-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; }
.page-head h1 { margin: 0 0 2px; }
.ot-week { font-size: 14px; white-space: nowrap; }
.ot-week strong { color: var(--text); }

.tt-toolbar { display: flex; align-items: center; gap: 18px; flex-wrap: wrap; padding: 12px 16px; margin: 12px 0 16px; }
.tt-nav { display: flex; align-items: center; gap: 8px; }
.tt-nav .btn { padding: 6px 12px; }
.tt-range { font-weight: 650; font-size: 15px; margin-left: 6px; white-space: nowrap; }

.tt-scroll { padding: 0; overflow-x: auto; }
.tt-inner { min-width: 720px; }
.tt-head {
  display: grid;
  grid-template-columns: 56px repeat(7, minmax(96px, 1fr));
  position: sticky; top: 0; z-index: 3;
  background: var(--surface); border-bottom: 1px solid var(--border);
}
.tt-gutter-head { border-right: 1px solid var(--border); }
.tt-day-head {
  display: flex; align-items: center; gap: 7px; justify-content: center;
  padding: 10px 4px; border-right: 1px solid var(--border); font-size: 13px;
}
.tt-day-head:last-child { border-right: none; }
.tt-day-head .dh-name { font-weight: 600; }
.tt-day-head .dh-num { color: var(--text-muted); font-weight: 600; }
.tt-day-head .dh-count {
  background: var(--primary); color: #fff; font-size: 11px; font-weight: 700;
  min-width: 18px; text-align: center; padding: 1px 6px; border-radius: 999px;
}
.tt-day-head.today { color: var(--primary); background: var(--primary-soft); }
.tt-day-head.today .dh-num { color: var(--primary); }

.tt-loading { display: flex; justify-content: center; padding: 30px; }
.tt-body { display: grid; grid-template-columns: 56px repeat(7, minmax(96px, 1fr)); position: relative; }
.tt-gutter { position: relative; border-right: 1px solid var(--border); }
.tt-hour-label { position: absolute; right: 6px; transform: translateY(-50%); font-size: 11.5px; color: var(--text-muted); font-variant-numeric: tabular-nums; }
.tt-col { position: relative; border-right: 1px solid var(--border); }
.tt-col:last-child { border-right: none; }
.tt-col.today { background: color-mix(in srgb, var(--primary-soft) 45%, transparent); }
.tt-line { position: absolute; left: 0; right: 0; border-top: 1px solid var(--border); pointer-events: none; }
.tt-now { position: absolute; left: 0; right: 0; height: 2px; background: var(--danger); z-index: 4; pointer-events: none; }
.tt-now::before { content: ''; position: absolute; left: -3px; top: -3px; width: 8px; height: 8px; border-radius: 50%; background: var(--danger); }

/* order block */
.ot-block {
  position: absolute;
  display: flex; flex-direction: column; gap: 1px; overflow: hidden;
  text-align: left; padding: 3px 6px;
  border: 1px solid color-mix(in srgb, var(--c) 45%, transparent);
  border-left: 3px solid var(--c);
  border-radius: 6px;
  background: color-mix(in srgb, var(--c) 14%, var(--surface));
  color: var(--text);
  font: inherit; cursor: pointer; z-index: 2; transition: filter 0.12s;
}
.ot-block:hover { filter: brightness(1.05); z-index: 5; }
.ob-time { font-size: 11px; font-weight: 700; color: var(--c); line-height: 1.2; }
.ob-main { font-size: 11.5px; font-weight: 600; line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ob-cust { font-size: 11px; opacity: 0.8; line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

/* detail modal */
.od-head { display: flex; align-items: center; gap: 10px; margin-bottom: 12px; }
.od-cust { display: flex; flex-direction: column; gap: 2px; margin-bottom: 14px; }
.od-cust strong { font-size: 16px; }
.od-cust a { color: var(--primary); font-size: 14px; }
.od-items { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 8px; border-top: 1px solid var(--border); padding-top: 12px; }
.od-items li { display: flex; justify-content: space-between; gap: 10px; font-size: 14px; }
.od-note { margin: 12px 0 0; padding: 10px 12px; background: color-mix(in srgb, var(--warning) 12%, transparent); border-radius: 8px; font-size: 13px; }
.od-total { display: flex; justify-content: space-between; align-items: center; margin-top: 14px; padding-top: 12px; border-top: 2px solid var(--border); }
.od-total strong { font-size: 20px; }
</style>
