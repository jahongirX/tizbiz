<script setup>
/**
 * Catalog (cafe / tort) "Jadval": a read-only weekly view of incoming orders.
 * Each day is a column; every order is one full-width row (time + #id, total,
 * customer) sorted by arrival time — readable even on very busy days.
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

const orders = ref([])
const loading = ref(false)
const error = ref('')
const anchor = ref(selectedDate.value)
const today = ref(todayInput())

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

// Orders grouped per weekday, each list sorted by arrival time (earliest first).
const ordersByDay = computed(() => {
  const map = {}
  for (let i = 0; i < 7; i++) map[i] = []
  for (const o of orders.value) {
    const day = weekDays.value.findIndex((d) => d.date === localDateInput(o.created_at))
    if (day >= 0) map[day].push(o)
  }
  for (let i = 0; i < 7; i++) {
    map[i].sort((a, b) => (localMinutes(a.created_at) ?? 0) - (localMinutes(b.created_at) ?? 0))
  }
  return map
})
const dayCount = (i) => ordersByDay.value[i].length
const daySum = (i) => ordersByDay.value[i].reduce((s, o) => s + (o.total_tiyin || 0), 0)
const weekCount = computed(() => weekDays.value.reduce((s, d) => s + dayCount(d.index), 0))
const weekSum = computed(() => weekDays.value.reduce((s, d) => s + daySum(d.index), 0))

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

watch(selectedDate, (d) => { anchor.value = d })
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

    <div class="board">
      <section v-for="d in weekDays" :key="d.date" class="col" :class="{ today: d.isToday }">
        <header class="col-head">
          <span class="ch-name">{{ d.name }}</span>
          <span class="ch-num">{{ dayNum(d.date) }}</span>
          <span v-if="dayCount(d.index)" class="ch-count">{{ dayCount(d.index) }}</span>
        </header>
        <div v-if="dayCount(d.index)" class="col-sub muted">{{ soms(daySum(d.index)) }}</div>

        <div class="col-body">
          <article
            v-for="o in ordersByDay[d.index]"
            :key="o.id"
            class="ocard"
            :style="{ '--c': statusOf(o.status).c }"
            :title="statusOf(o.status).l"
            @click="openDetail(o)"
          >
            <div class="oc-l1"><span class="oc-time">{{ formatTime(o.created_at) }}</span><span class="oc-id">#{{ o.id }}</span></div>
            <div class="oc-l2">{{ soms(o.total_tiyin) }}</div>
            <div class="oc-l3">{{ o.customer_name || '—' }}<template v-if="o.customer_phone"> · {{ o.customer_phone }}</template></div>
          </article>
          <p v-if="!dayCount(d.index)" class="col-empty">Bo‘sh</p>
        </div>
      </section>
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

/* 7 day columns, each an independent scrolling list */
.board {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
  gap: 10px;
  align-items: start;
}
.col {
  min-width: 0;
  display: flex;
  flex-direction: column;
  background: color-mix(in srgb, var(--text-muted) 8%, transparent);
  border: 1px solid var(--border);
  border-radius: 12px;
  overflow: hidden;
}
.col.today { box-shadow: inset 0 0 0 2px var(--primary); }
.col-head {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 9px 10px 2px;
}
.col.today .col-head { color: var(--primary); }
.ch-name { font-weight: 700; font-size: 12.5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ch-num { color: var(--text-muted); font-weight: 600; font-size: 12.5px; }
.col.today .ch-num { color: var(--primary); }
.ch-count {
  margin-left: auto;
  background: var(--primary);
  color: #fff;
  font-size: 11px;
  font-weight: 700;
  min-width: 20px;
  text-align: center;
  padding: 1px 6px;
  border-radius: 999px;
  flex: none;
}
.col-sub { font-size: 11px; padding: 0 10px 2px; }

.col-body {
  display: flex;
  flex-direction: column;
  gap: 7px;
  padding: 8px;
  overflow-y: auto;
  max-height: calc(100vh - 250px);
}
.col-empty {
  text-align: center;
  color: var(--text-muted);
  font-size: 12px;
  padding: 16px 0;
  border: 1px dashed var(--border);
  border-radius: 9px;
  margin: 0;
}

/* One order = one full-width row, 3 lines */
.ocard {
  background: var(--surface);
  border: 1px solid var(--border);
  border-left: 3px solid var(--c);
  border-radius: 8px;
  padding: 8px 10px;
  cursor: pointer;
  transition: box-shadow 0.12s ease, transform 0.06s ease;
}
.ocard:hover { box-shadow: 0 3px 10px rgba(0, 0, 0, 0.16); transform: translateY(-1px); }
.oc-l1 { display: flex; align-items: baseline; justify-content: space-between; gap: 6px; }
.oc-time { font-size: 12.5px; font-weight: 700; color: var(--c); }
.oc-id { font-size: 11.5px; color: var(--text-muted); }
.oc-l2 { font-size: 14px; font-weight: 700; margin-top: 2px; }
.oc-l3 {
  font-size: 11.5px;
  color: var(--text-muted);
  margin-top: 2px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

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

/* Narrow screens: columns scroll horizontally */
@media (max-width: 1024px) {
  .board { display: flex; overflow-x: auto; padding-bottom: 10px; }
  .col { flex: 0 0 240px; }
  .col-body { max-height: calc(100vh - 230px); }
}
@media (max-width: 600px) {
  .col { flex-basis: 82vw; }
}
</style>
