<script setup>
/**
 * Catalog (cafe / tort) "Jadval": a weekly calendar of incoming orders.
 * Hours run down the left; each order sits in its hour cell. Busy hours grow
 * taller (CSS-grid rows size to the tallest cell) so EVERY order shows even
 * when many land in the same hour — no cramped lanes, days stay aligned.
 */
import { ref, computed, watch, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import {
  todayInput,
  addDays,
  mondayOf,
  localMinutes,
  localDateInput,
  formatWeekRange,
  formatTime,
  dayNum,
} from '../lib/datetime'
import Modal from '../components/Modal.vue'
import { selectedDate, setSelectedDate } from '../composables/useCalendar'

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
const hh = (h) => String(h).padStart(2, '0') + ':00'

const orders = ref([])
const loading = ref(false)
const error = ref('')
const anchor = ref(selectedDate.value)
const today = ref(todayInput())

const monday = computed(() => mondayOf(anchor.value))
// The visible week as a unix-seconds window (Tashkent is a fixed UTC+5).
const weekFrom = computed(() => Math.floor(Date.parse(monday.value + 'T00:00:00+05:00') / 1000))
const weekTo = computed(() => weekFrom.value + 7 * 86400)
const weekDays = computed(() => {
  const days = []
  for (let i = 0; i < 7; i++) {
    const date = addDays(monday.value, i)
    days.push({ index: i, date, name: WEEKDAYS[i], isToday: date === today.value })
  }
  return days
})
const weekRangeLabel = computed(() => formatWeekRange(monday.value, addDays(monday.value, 6)))

// Orders bucketed by [day][hour], each bucket sorted by minute.
const byDayHour = computed(() => {
  const m = {}
  for (let i = 0; i < 7; i++) m[i] = {}
  for (const o of orders.value) {
    const day = weekDays.value.findIndex((d) => d.date === localDateInput(o.created_at))
    if (day < 0) continue
    const mins = localMinutes(o.created_at)
    if (mins == null) continue
    const h = Math.floor(mins / 60)
    ;(m[day][h] ??= []).push({ o, mins })
  }
  for (let i = 0; i < 7; i++) {
    for (const h in m[i]) m[i][h].sort((a, b) => a.mins - b.mins)
  }
  return m
})
const cellOrders = (day, h) => (byDayHour.value[day][h] || [])

// Visible hour range: 9..21 by default, widened to fit the data.
const hours = computed(() => {
  let min = 9
  let max = 21
  for (const o of orders.value) {
    if (weekDays.value.findIndex((d) => d.date === localDateInput(o.created_at)) < 0) continue
    const mins = localMinutes(o.created_at)
    if (mins == null) continue
    const h = Math.floor(mins / 60)
    if (h < min) min = h
    if (h > max) max = h
  }
  const arr = []
  for (let h = min; h <= max; h++) arr.push(h)
  return arr
})

const dayCount = (i) => orders.value.filter((o) => weekDays.value[i]?.date === localDateInput(o.created_at)).length
const daySum = (i) => orders.value.reduce((s, o) => s + (weekDays.value[i]?.date === localDateInput(o.created_at) ? (o.total_tiyin || 0) : 0), 0)
const weekCount = computed(() => weekDays.value.reduce((s, d) => s + dayCount(d.index), 0))
const weekSum = computed(() => weekDays.value.reduce((s, d) => s + daySum(d.index), 0))

async function load() {
  loading.value = true
  error.value = ''
  try {
    // Fetch exactly the week on screen so a busy catalog (30-40/day) isn't
    // capped to the API's "latest" slice — every day of the week fills in.
    orders.value = await api.get(`/v1/orders?from=${weekFrom.value}&to=${weekTo.value}`)
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Buyurtmalarni yuklab bo\'lmadi'
    orders.value = []
  } finally {
    loading.value = false
  }
}

watch(selectedDate, (d) => { anchor.value = d })
// Reload whenever the visible week changes.
watch(monday, () => load())
const prevWeek = () => setSelectedDate(addDays(selectedDate.value, -7))
const nextWeek = () => setSelectedDate(addDays(selectedDate.value, 7))
const goToday = () => setSelectedDate(todayInput())

const detail = ref(null)
const openDetail = (o) => { detail.value = o }

onMounted(load)
</script>

<template>
  <div class="ot">
    <div class="page-head">
      <div>
        <h1>Jadval</h1>
        <p class="muted">Buyurtmalar oqimi — qaysi kuni, qaysi vaqtda nechta buyurtma keldi</p>
      </div>
      <div class="ot-week muted">{{ weekCount }} ta · <strong>{{ soms(weekSum) }}</strong></div>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div class="ot-toolbar card">
      <div class="ot-nav">
        <button class="btn btn-sm" aria-label="Oldingi hafta" @click="prevWeek">‹</button>
        <button class="btn btn-sm" @click="goToday">Bugun</button>
        <button class="btn btn-sm" aria-label="Keyingi hafta" @click="nextWeek">›</button>
        <span class="ot-range">{{ weekRangeLabel }}</span>
      </div>
      <span v-if="loading" class="muted" style="font-size: 13px">Yuklanmoqda…</span>
    </div>

    <div class="cal card">
      <div class="cal-scroll">
        <div class="cal-inner">
          <!-- header -->
          <div class="cal-head">
            <div class="corner"></div>
            <div v-for="d in weekDays" :key="d.date" class="dh" :class="{ today: d.isToday }">
              <span class="dh-name">{{ d.name }}</span>
              <span class="dh-num">{{ dayNum(d.date) }}</span>
              <span v-if="dayCount(d.index)" class="dh-count">{{ dayCount(d.index) }}</span>
            </div>
          </div>

          <!-- body: one grid row per hour, auto-sized to its tallest cell -->
          <div class="cal-grid">
            <template v-for="h in hours" :key="h">
              <div class="hlabel">{{ hh(h) }}</div>
              <div
                v-for="d in weekDays"
                :key="d.date + '-' + h"
                class="hcell"
                :class="{ today: d.isToday }"
              >
                <article
                  v-for="row in cellOrders(d.index, h)"
                  :key="row.o.id"
                  class="chip"
                  :style="{ '--c': statusOf(row.o.status).c }"
                  :title="statusOf(row.o.status).l"
                  @click="openDetail(row.o)"
                >
                  <div class="ch-l1"><span class="ch-time">{{ formatTime(row.o.created_at) }}</span><span class="ch-id">#{{ row.o.id }}</span></div>
                  <div class="ch-l2">{{ soms(row.o.total_tiyin) }}</div>
                  <div class="ch-l3">{{ row.o.customer_name || '—' }}<template v-if="row.o.customer_phone"> · {{ row.o.customer_phone }}</template></div>
                </article>
              </div>
            </template>
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

.ot-toolbar { display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; padding: 12px 16px; margin: 12px 0 16px; }
.ot-nav { display: flex; align-items: center; gap: 8px; }
.ot-nav .btn { padding: 6px 12px; }
.ot-range { font-weight: 650; font-size: 15px; margin-left: 6px; white-space: nowrap; }

.cal { padding: 0; overflow: hidden; }
.cal-scroll { max-height: calc(100vh - 240px); overflow: auto; }
.cal-inner { min-width: 820px; }

.cal-head {
  display: grid;
  grid-template-columns: 56px repeat(7, minmax(0, 1fr));
  position: sticky;
  top: 0;
  z-index: 3;
  background: var(--surface);
  border-bottom: 1px solid var(--border);
}
.corner { border-right: 1px solid var(--border); }
.dh {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 9px 6px;
  border-left: 1px solid var(--border);
  font-size: 13px;
}
.dh-name { font-weight: 600; }
.dh-num { color: var(--text-muted); font-weight: 600; }
.dh-count {
  background: var(--primary); color: #fff; font-size: 11px; font-weight: 700;
  min-width: 18px; text-align: center; padding: 1px 6px; border-radius: 999px;
}
.dh.today { color: var(--primary); background: var(--primary-soft); }
.dh.today .dh-num { color: var(--primary); }

.cal-grid { display: grid; grid-template-columns: 56px repeat(7, minmax(0, 1fr)); }
.hlabel {
  border-top: 1px solid var(--border);
  border-right: 1px solid var(--border);
  padding: 5px 6px 0;
  text-align: right;
  font-size: 11.5px;
  color: var(--text-muted);
  font-variant-numeric: tabular-nums;
}
.hcell {
  border-top: 1px solid var(--border);
  border-left: 1px solid var(--border);
  padding: 4px;
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-height: 42px;
}
.hcell.today { background: color-mix(in srgb, var(--primary-soft) 40%, transparent); }

/* one order chip = one row inside its hour cell */
.chip {
  background: var(--surface);
  border: 1px solid var(--border);
  border-left: 3px solid var(--c);
  border-radius: 7px;
  padding: 5px 8px;
  cursor: pointer;
  transition: box-shadow 0.12s ease, transform 0.06s ease;
}
.chip:hover { box-shadow: 0 3px 10px rgba(0, 0, 0, 0.16); transform: translateY(-1px); }
.ch-l1 { display: flex; align-items: baseline; justify-content: space-between; gap: 6px; }
.ch-time { font-size: 12px; font-weight: 700; color: var(--c); }
.ch-id { font-size: 11px; color: var(--text-muted); }
.ch-l2 { font-size: 13px; font-weight: 700; margin-top: 1px; }
.ch-l3 { font-size: 11px; color: var(--text-muted); margin-top: 1px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

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
