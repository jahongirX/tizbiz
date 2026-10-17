<script setup>
// Big month calendar for the rental / wedding-hall engine. Free days are
// selectable; already-booked days (from the public booked-days endpoint) and
// past days are shown but disabled. One event per day — the whole point of the
// hall calendar is "pick a free date".
import { ref, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { isoDate } from '../format.js'

const props = defineProps({
  slug: { type: String, required: true },
  selectedDate: { type: [String, null], default: null },
  // Chosen session ('morning' | 'evening'); a day is only unavailable when THIS
  // session is taken (a hall can host both a morning and an evening event).
  session: { type: String, default: '' },
})
const emit = defineEmits(['select', 'back'])

const DOW = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya']
const MON_FULL = [
  'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
  'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
]

// Fallback window until the server answers; booked-days then returns the real
// bookable window (min_date / max_date / lead_min = the business's
// booking_lead_min and booking_horizon_days, the same rules the server enforces).
const FALLBACK_HORIZON_DAYS = 120
const today = new Date()
today.setHours(0, 0, 0, 0)
const todayIso = isoDate(today)
const fallbackMax = new Date(today)
fallbackMax.setDate(fallbackMax.getDate() + FALLBACK_HORIZON_DAYS)
const minIso = ref(todayIso)
const maxIso = ref(isoDate(fallbackMax))
const leadMin = ref(0)
const maxDate = computed(() => {
  const [y, m, d] = maxIso.value.split('-').map(Number)
  return new Date(y, m - 1, d)
})

// Session start hour (local) as the server defines it: morning 10, evening 18, none 10.
function sessionStartHour() {
  return props.session === 'evening' ? 18 : 10
}
// The chosen session on this day starts before now + lead → not bookable.
function tooSoon(iso) {
  const [y, m, d] = iso.split('-').map(Number)
  const start = new Date(y, m - 1, d, sessionStartHour(), 0, 0, 0)
  return start.getTime() < Date.now() + leadMin.value * 60000
}

// Visible month (year + 0-based month), starts on today's month.
const view = ref({ y: today.getFullYear(), m: today.getMonth() })

// Map of ISO date → array of taken sessions, e.g. {"2026-09-20": ["morning"]}.
const booked = ref({})
const loading = ref(false)
const error = ref('')

// A date is unavailable when the chosen session is taken (or, if no session was
// given, when anything at all is booked that day).
function isBookedFor(iso) {
  const taken = booked.value[iso]
  if (!taken || !taken.length) return false
  if (!props.session) return true
  return taken.includes(props.session)
}

async function loadBooked() {
  loading.value = true
  error.value = ''
  try {
    // No `to`: the server defaults it to the business's booking horizon.
    const q = new URLSearchParams({ from: todayIso })
    const res = await api.get(`/v1/site/${encodeURIComponent(props.slug)}/booked-days?${q}`)
    booked.value = res && typeof res.booked === 'object' && !Array.isArray(res.booked) ? res.booked : {}
    const isIso = (v) => typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v)
    if (res && isIso(res.max_date)) maxIso.value = res.max_date
    if (res && isIso(res.min_date)) minIso.value = res.min_date > todayIso ? res.min_date : todayIso
    if (res && Number.isFinite(res.lead_min)) leadMin.value = Math.max(0, res.lead_min)
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Band kunlarni yuklab bo‘lmadi.'
  } finally {
    loading.value = false
  }
}
onMounted(loadBooked)

// Monday-first weeks covering the visible month.
const weeks = computed(() => {
  const { y, m } = view.value
  const first = new Date(y, m, 1)
  // JS: 0=Sun..6=Sat → shift to Mon-first (0=Mon..6=Sun).
  const lead = (first.getDay() + 6) % 7
  const daysInMonth = new Date(y, m + 1, 0).getDate()
  const cells = []
  for (let i = 0; i < lead; i++) cells.push(null)
  for (let d = 1; d <= daysInMonth; d++) {
    const date = new Date(y, m, d)
    const iso = isoDate(date)
    const past = iso < minIso.value || tooSoon(iso)
    const beyond = iso > maxIso.value
    const isBooked = isBookedFor(iso)
    cells.push({
      d,
      iso,
      disabled: past || beyond || isBooked,
      booked: isBooked && !past && !beyond,
      today: iso === todayIso,
    })
  }
  while (cells.length % 7 !== 0) cells.push(null)
  const out = []
  for (let i = 0; i < cells.length; i += 7) out.push(cells.slice(i, i + 7))
  return out
})

const monthLabel = computed(() => `${MON_FULL[view.value.m]} ${view.value.y}`)

const canPrev = computed(() => {
  const { y, m } = view.value
  return y > today.getFullYear() || (y === today.getFullYear() && m > today.getMonth())
})
const canNext = computed(() => {
  const { y, m } = view.value
  const last = new Date(maxDate.value.getFullYear(), maxDate.value.getMonth(), 1)
  const cur = new Date(y, m, 1)
  return cur < last
})
function prev() {
  if (!canPrev.value) return
  const m = view.value.m - 1
  view.value = m < 0 ? { y: view.value.y - 1, m: 11 } : { y: view.value.y, m }
}
function next() {
  if (!canNext.value) return
  const m = view.value.m + 1
  view.value = m > 11 ? { y: view.value.y + 1, m: 0 } : { y: view.value.y, m }
}
function pick(cell) {
  if (!cell || cell.disabled) return
  emit('select', cell.iso)
}
</script>

<template>
  <div>
    <div class="step-head">
      <button class="back" aria-label="Orqaga" @click="emit('back')">‹</button>
      <h2>Sanani tanlang</h2>
    </div>

    <div class="cal-nav">
      <button class="cal-arrow" :disabled="!canPrev" aria-label="Oldingi oy" @click="prev">‹</button>
      <div class="cal-month">{{ monthLabel }}</div>
      <button class="cal-arrow" :disabled="!canNext" aria-label="Keyingi oy" @click="next">›</button>
    </div>

    <div v-if="error" class="alert">{{ error }}</div>

    <div class="cal-grid cal-dow">
      <div v-for="d in DOW" :key="d" class="cal-dowc">{{ d }}</div>
    </div>

    <div class="cal-body" :class="{ loading }">
      <div v-for="(w, wi) in weeks" :key="wi" class="cal-grid">
        <template v-for="(c, ci) in w">
          <div v-if="!c" :key="`e${ci}`" class="cal-cell empty"></div>
          <button
            v-else
            :key="`d${ci}`"
            class="cal-cell"
            :class="{
              selected: c.iso === selectedDate,
              disabled: c.disabled,
              booked: c.booked,
              today: c.today,
            }"
            :disabled="c.disabled"
            @click="pick(c)"
          >
            <span class="cal-day">{{ c.d }}</span>
            <span v-if="c.booked" class="cal-tag">band</span>
          </button>
        </template>
      </div>
    </div>

    <div class="cal-legend">
      <span class="lg"><i class="dot free"></i> Bo‘sh</span>
      <span class="lg"><i class="dot busy"></i> Band</span>
    </div>
  </div>
</template>

<style scoped>
.cal-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: 6px 0 12px;
}
.cal-month {
  font-weight: 700;
  font-size: 17px;
}
.cal-arrow {
  width: 40px;
  height: 40px;
  border-radius: 12px;
  border: 1px solid var(--line, #2a2d3a);
  background: var(--card, #171a24);
  color: inherit;
  font-size: 20px;
  cursor: pointer;
}
.cal-arrow:disabled {
  opacity: 0.3;
  cursor: default;
}
.cal-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 6px;
}
.cal-dow {
  margin-bottom: 6px;
}
.cal-dowc {
  text-align: center;
  font-size: 12px;
  color: var(--muted, #8b90a3);
  padding: 4px 0;
}
.cal-body {
  display: flex;
  flex-direction: column;
  gap: 6px;
  transition: opacity 0.15s;
}
.cal-body.loading {
  opacity: 0.5;
}
.cal-cell {
  position: relative;
  aspect-ratio: 1 / 1;
  border-radius: 12px;
  border: 1px solid var(--line, #2a2d3a);
  background: var(--card, #171a24);
  color: inherit;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  cursor: pointer;
  padding: 0;
}
.cal-cell.empty {
  border: none;
  background: transparent;
  cursor: default;
}
.cal-cell.today {
  border-color: var(--brand, #8b5cf6);
}
.cal-cell.selected {
  background: var(--brand, #8b5cf6);
  border-color: var(--brand, #8b5cf6);
  color: var(--brand-ink, #fff);
  font-weight: 700;
}
.cal-cell.disabled {
  opacity: 0.32;
  cursor: not-allowed;
}
.cal-cell.booked {
  background: repeating-linear-gradient(
    -45deg,
    color-mix(in srgb, var(--brand, #8b5cf6) 12%, transparent),
    color-mix(in srgb, var(--brand, #8b5cf6) 12%, transparent) 5px,
    transparent 5px,
    transparent 10px
  );
  text-decoration: line-through;
}
.cal-tag {
  font-size: 9px;
  color: var(--muted, #8b90a3);
  line-height: 1;
}
.cal-legend {
  display: flex;
  gap: 18px;
  justify-content: center;
  margin-top: 14px;
  font-size: 13px;
  color: var(--muted, #8b90a3);
}
.cal-legend .lg {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}
.cal-legend .dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  display: inline-block;
}
.cal-legend .dot.free {
  background: var(--brand, #8b5cf6);
}
.cal-legend .dot.busy {
  background: color-mix(in srgb, var(--brand, #8b5cf6) 30%, transparent);
}
</style>
