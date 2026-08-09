<script setup>
import { ref, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { todayInput, addDays, localDayStartUtc, localDayEndUtc } from '../lib/datetime'
import { formatSom } from '../lib/money'

// Categorical palette (fixed order, never cycled past its length in a way that
// re-colours entities). Primary series uses the app accent (--primary ≈ #3b82f6).
const PALETTE = ['#3b82f6', '#22c55e', '#f59e0b', '#a855f7', '#ef4444', '#14b8a6']

const PERIODS = [
  { days: 7, label: 'Oxirgi 7 kun' },
  { days: 30, label: 'Oxirgi 30 kun' },
  { days: 90, label: 'Oxirgi 90 kun' },
]

const period = ref(30)
const loading = ref(true)
const error = ref('')
const data = ref(null)

// --- date range (UTC day bounds) ---
function range() {
  const to = todayInput()
  const from = addDays(to, -(period.value - 1))
  return { fromDay: from, toDay: to }
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { fromDay, toDay } = range()
    const from = localDayStartUtc(fromDay)
    const to = localDayEndUtc(toDay)
    data.value = await api.get(
      `/v1/analytics/overview?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`,
    )
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Ma\'lumotni yuklab bo\'lmadi'
    data.value = null
  } finally {
    loading.value = false
  }
}

function setPeriod(days) {
  if (period.value === days) return
  period.value = days
  load()
}

onMounted(load)

// --- derived KPIs ---
const appts = computed(() => data.value?.appointments || {})
const revenueTiyin = computed(() => Number(data.value?.revenue_tiyin) || 0)
const totalAppts = computed(() => Number(appts.value.total) || 0)
const nsRate = computed(() => {
  const r = Number(data.value?.no_show_rate)
  return Number.isFinite(r) ? Math.round(r * 10) / 10 : 0
})
const newClients = computed(() => Number(data.value?.clients?.new) || 0)

const hasData = computed(() => {
  if (!data.value) return false
  return totalAppts.value > 0 || revenueTiyin.value > 0 || (series.value.length > 0)
})

const series = computed(() =>
  Array.isArray(data.value?.series) ? data.value.series : [],
)
const topServices = computed(() =>
  Array.isArray(data.value?.top_services) ? data.value.top_services : [],
)
const staffLoad = computed(() =>
  Array.isArray(data.value?.staff_load) ? data.value.staff_load : [],
)

// --- formatting helpers ---
// Compact so'm for tight axis labels: 12 500 000 tiyin -> "125 ming" is wrong; work in so'm.
function compactSom(tiyin) {
  const som = (Number(tiyin) || 0) / 100
  if (som >= 1_000_000) return (som / 1_000_000).toFixed(som >= 10_000_000 ? 0 : 1) + ' mln'
  if (som >= 1_000) return Math.round(som / 1_000) + ' ming'
  return String(Math.round(som))
}

function shortDate(dateStr) {
  // 'YYYY-MM-DD' -> 'DD.MM'
  if (!dateStr || dateStr.length < 10) return dateStr || ''
  return `${dateStr.slice(8, 10)}.${dateStr.slice(5, 7)}`
}

function niceMax(v) {
  if (v <= 0) return 1
  const pow = Math.pow(10, Math.floor(Math.log10(v)))
  const n = v / pow
  const step = n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10
  return step * pow
}

// --- daily revenue chart geometry (area + line) ---
const CW = 760
const REV_H = 200
const APPT_H = 150
const M = { l: 66, r: 14, t: 14, b: 26 }

const xLayout = computed(() => {
  const n = series.value.length
  const plotW = CW - M.l - M.r
  const x = (i) => (n <= 1 ? M.l + plotW / 2 : M.l + (i / (n - 1)) * plotW)
  // choose ~7 x tick indices
  const ticks = []
  const want = Math.min(7, n)
  if (n > 0) {
    const stepI = want <= 1 ? 1 : (n - 1) / (want - 1)
    for (let k = 0; k < want; k++) {
      const i = Math.round(k * stepI)
      ticks.push({ x: x(i), label: shortDate(series.value[i]?.date) })
    }
  }
  return { n, plotW, x, ticks }
})

const revChart = computed(() => {
  const s = series.value
  const { n, x } = xLayout.value
  const top = M.t
  const bottom = REV_H - M.b
  const plotH = bottom - top
  const rawMax = Math.max(1, ...s.map((d) => Number(d.revenue_tiyin) || 0))
  const max = niceMax(rawMax)
  const y = (v) => bottom - (Math.min(v, max) / max) * plotH
  const pts = s.map((d, i) => ({ x: x(i), y: y(Number(d.revenue_tiyin) || 0), d }))
  let line = ''
  let area = ''
  pts.forEach((p, i) => {
    line += (i === 0 ? 'M' : 'L') + p.x.toFixed(1) + ' ' + p.y.toFixed(1) + ' '
  })
  if (pts.length) {
    area = `M${pts[0].x.toFixed(1)} ${bottom} ` +
      pts.map((p) => `L${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(' ') +
      ` L${pts[pts.length - 1].x.toFixed(1)} ${bottom} Z`
  }
  const yTicks = [0, 0.25, 0.5, 0.75, 1].map((f) => ({
    y: bottom - f * plotH,
    label: compactSom(max * f),
  }))
  return { pts, line, area, yTicks, bottom, top, n, max }
})

const apptChart = computed(() => {
  const s = series.value
  const { n, x, plotW } = xLayout.value
  const top = M.t
  const bottom = APPT_H - M.b
  const plotH = bottom - top
  const rawMax = Math.max(1, ...s.map((d) => Number(d.appointments) || 0))
  const max = niceMax(rawMax)
  const bw = Math.max(2, Math.min(26, (plotW / Math.max(n, 1)) * 0.62))
  const bars = s.map((d, i) => {
    const v = Number(d.appointments) || 0
    const h = (Math.min(v, max) / max) * plotH
    return { x: x(i) - bw / 2, y: bottom - h, w: bw, h, v, date: d.date }
  })
  const yTicks = [0, 0.5, 1].map((f) => ({
    y: bottom - f * plotH,
    label: String(Math.round(max * f)),
  }))
  return { bars, yTicks, bottom, top, bw }
})

// --- top services (horizontal bars by revenue) ---
const servicesChart = computed(() => {
  const rows = topServices.value
  const max = Math.max(1, ...rows.map((r) => Number(r.revenue_tiyin) || 0))
  return rows.map((r, i) => ({
    name: r.name || 'Nomsiz',
    count: Number(r.count) || 0,
    revenue: Number(r.revenue_tiyin) || 0,
    pct: ((Number(r.revenue_tiyin) || 0) / max) * 100,
    color: PALETTE[i % PALETTE.length],
  }))
})

// --- staff load (vertical bars by appointment count) ---
const SL_W = 760
const SL_H = 200
const SLM = { l: 34, r: 12, t: 14, b: 46 }
const staffChart = computed(() => {
  const rows = staffLoad.value
  const n = rows.length
  const plotW = SL_W - SLM.l - SLM.r
  const bottom = SL_H - SLM.b
  const top = SLM.t
  const plotH = bottom - top
  const rawMax = Math.max(1, ...rows.map((r) => Number(r.count) || 0))
  const max = niceMax(rawMax)
  const slot = plotW / Math.max(n, 1)
  const bw = Math.max(6, Math.min(56, slot * 0.6))
  const bars = rows.map((r, i) => {
    const v = Number(r.count) || 0
    const h = (v / max) * plotH
    const cx = SLM.l + slot * (i + 0.5)
    const name = r.name || 'Nomsiz'
    return {
      x: cx - bw / 2,
      y: bottom - h,
      w: bw,
      h,
      cx,
      v,
      revenue: Number(r.revenue_tiyin) || 0,
      name,
      short: name.length > 10 ? name.slice(0, 9) + '…' : name,
      color: PALETTE[i % PALETTE.length],
    }
  })
  const yTicks = [0, 0.5, 1].map((f) => ({
    y: bottom - f * plotH,
    label: String(Math.round(max * f)),
  }))
  return { bars, yTicks, bottom, top }
})
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <h1>Analitika</h1>
        <p class="muted mb-0">Biznes ko'rsatkichlari · dinamika</p>
      </div>
      <div class="seg" role="group" aria-label="Davr tanlash">
        <button
          v-for="p in PERIODS"
          :key="p.days"
          class="seg-btn"
          :class="{ active: period === p.days }"
          :aria-pressed="period === p.days"
          @click="setPeriod(p.days)"
        >
          {{ p.label }}
        </button>
      </div>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

    <div v-else-if="!hasData" class="empty card">Bu davr uchun ma'lumot yo'q.</div>

    <template v-else>
      <!-- KPI tiles -->
      <div class="stat-grid" style="margin-bottom: 22px">
        <div class="stat">
          <div class="value" style="color: var(--primary)">{{ formatSom(revenueTiyin) }}</div>
          <div class="label">Daromad</div>
        </div>
        <div class="stat">
          <div class="value">{{ totalAppts }}</div>
          <div class="label">Yozuvlar</div>
        </div>
        <div class="stat">
          <div class="value" style="color: var(--danger)">{{ nsRate }}%</div>
          <div class="label">No-show (kelmadi)</div>
        </div>
        <div class="stat">
          <div class="value" style="color: var(--success)">{{ newClients }}</div>
          <div class="label">Yangi mijozlar</div>
        </div>
      </div>

      <!-- Daily dynamics: revenue (area) + appointments (bars) -->
      <div class="card chart-card" style="margin-bottom: 18px">
        <div class="row between chart-head">
          <h2>Kunlik dinamika</h2>
          <div class="legend">
            <span class="lg"><span class="sw" style="background: var(--primary)"></span> Daromad</span>
            <span class="lg"><span class="sw" style="background: #64748b"></span> Yozuvlar</span>
          </div>
        </div>

        <div v-if="!series.length" class="empty">Ma'lumot yo'q.</div>
        <template v-else>
          <!-- Revenue area -->
          <svg
            class="chart"
            :viewBox="`0 0 ${CW} ${REV_H}`"            role="img"
            aria-label="Kunlik daromad grafigi"
          >
            <title>Kunlik daromad</title>
            <g class="grid">
              <line
                v-for="(t, i) in revChart.yTicks"
                :key="'rg' + i"
                :x1="M.l" :x2="CW - M.r" :y1="t.y" :y2="t.y"
              />
            </g>
            <g class="axis-lbl">
              <text
                v-for="(t, i) in revChart.yTicks"
                :key="'ry' + i"
                :x="M.l - 8" :y="t.y + 3" text-anchor="end"
              >{{ t.label }}</text>
            </g>
            <path :d="revChart.area" class="area-fill" />
            <path :d="revChart.line" class="area-line" />
            <g>
              <circle
                v-for="(p, i) in revChart.pts"
                :key="'rp' + i"
                :cx="p.x" :cy="p.y" r="3.2" class="dot"
              >
                <title>{{ shortDate(p.d.date) }} · {{ formatSom(p.d.revenue_tiyin) }}</title>
              </circle>
            </g>
            <g class="axis-lbl">
              <text
                v-for="(t, i) in xLayout.ticks"
                :key="'rx' + i"
                :x="t.x" :y="REV_H - 8" text-anchor="middle"
              >{{ t.label }}</text>
            </g>
          </svg>

          <!-- Appointments bars -->
          <svg
            class="chart"
            :viewBox="`0 0 ${CW} ${APPT_H}`"            role="img"
            aria-label="Kunlik yozuvlar soni grafigi"
          >
            <title>Kunlik yozuvlar soni</title>
            <g class="grid">
              <line
                v-for="(t, i) in apptChart.yTicks"
                :key="'ag' + i"
                :x1="M.l" :x2="CW - M.r" :y1="t.y" :y2="t.y"
              />
            </g>
            <g class="axis-lbl">
              <text
                v-for="(t, i) in apptChart.yTicks"
                :key="'ay' + i"
                :x="M.l - 8" :y="t.y + 3" text-anchor="end"
              >{{ t.label }}</text>
            </g>
            <g>
              <rect
                v-for="(b, i) in apptChart.bars"
                :key="'ab' + i"
                :x="b.x" :y="b.y" :width="b.w" :height="b.h"
                rx="2" class="appt-bar"
              >
                <title>{{ shortDate(b.date) }} · {{ b.v }} ta yozuv</title>
              </rect>
            </g>
            <g class="axis-lbl">
              <text
                v-for="(t, i) in xLayout.ticks"
                :key="'ax' + i"
                :x="t.x" :y="APPT_H - 8" text-anchor="middle"
              >{{ t.label }}</text>
            </g>
          </svg>
        </template>
      </div>

      <div class="two-col">
        <!-- Top services -->
        <div class="card chart-card">
          <h2>Top xizmatlar</h2>
          <div v-if="!servicesChart.length" class="empty">Ma'lumot yo'q.</div>
          <ul v-else class="hbars" aria-label="Daromad bo'yicha eng ko'p xizmatlar">
            <li v-for="(s, i) in servicesChart" :key="i">
              <div class="hbar-top">
                <span class="hbar-name" :title="s.name">{{ s.name }}</span>
                <span class="hbar-val">{{ formatSom(s.revenue) }}</span>
              </div>
              <div class="hbar-track">
                <div
                  class="hbar-fill"
                  :style="{ width: Math.max(s.pct, 1.5) + '%', background: s.color }"
                  role="img"
                  :aria-label="`${s.name}: ${formatSom(s.revenue)}, ${s.count} ta`"
                ></div>
              </div>
              <div class="hbar-sub muted">{{ s.count }} ta yozuv</div>
            </li>
          </ul>
        </div>

        <!-- Staff load -->
        <div class="card chart-card">
          <h2>Xodimlar yuki</h2>
          <div v-if="!staffChart.bars.length" class="empty">Ma'lumot yo'q.</div>
          <svg
            v-else
            class="chart"
            :viewBox="`0 0 ${SL_W} ${SL_H}`"            role="img"
            aria-label="Xodimlar bo'yicha yozuvlar soni"
          >
            <title>Xodimlar yuki (yozuvlar soni)</title>
            <g class="grid">
              <line
                v-for="(t, i) in staffChart.yTicks"
                :key="'sg' + i"
                :x1="SLM.l" :x2="SL_W - SLM.r" :y1="t.y" :y2="t.y"
              />
            </g>
            <g class="axis-lbl">
              <text
                v-for="(t, i) in staffChart.yTicks"
                :key="'sy' + i"
                :x="SLM.l - 8" :y="t.y + 3" text-anchor="end"
              >{{ t.label }}</text>
            </g>
            <g>
              <rect
                v-for="(b, i) in staffChart.bars"
                :key="'sb' + i"
                :x="b.x" :y="b.y" :width="b.w" :height="b.h"
                rx="3" :fill="b.color" class="staff-bar"
              >
                <title>{{ b.name }} · {{ b.v }} ta · {{ formatSom(b.revenue) }}</title>
              </rect>
              <text
                v-for="(b, i) in staffChart.bars"
                :key="'sbv' + i"
                :x="b.cx" :y="b.y - 5" text-anchor="middle" class="bar-val"
              >{{ b.v }}</text>
            </g>
            <g class="axis-lbl">
              <text
                v-for="(b, i) in staffChart.bars"
                :key="'sbn' + i"
                :x="b.cx" :y="SL_H - 22" text-anchor="middle"
              >{{ b.short }}</text>
            </g>
          </svg>
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
/* segmented period selector */
.seg {
  display: inline-flex;
  border: 1px solid var(--border);
  border-radius: 8px;
  overflow: hidden;
  background: var(--surface);
}
.seg-btn {
  font: inherit;
  font-weight: 600;
  font-size: 12.5px;
  padding: 7px 13px;
  border: none;
  background: transparent;
  color: var(--text-muted);
  cursor: pointer;
  border-left: 1px solid var(--border);
  transition: background 0.15s, color 0.15s;
}
.seg-btn:first-child { border-left: none; }
.seg-btn:hover { background: var(--surface-2); }
.seg-btn.active {
  background: var(--primary);
  color: #fff;
}

.chart-card h2 {
  font-size: 16px;
  margin: 0 0 12px;
}
.chart-head { margin-bottom: 8px; }
.chart-head h2 { margin: 0; }

.legend { display: flex; gap: 14px; flex-wrap: wrap; }
.legend .lg {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  color: var(--text-muted);
}
.legend .sw {
  width: 12px;
  height: 12px;
  border-radius: 3px;
  display: inline-block;
}

.chart {
  width: 100%;
  height: auto;
  display: block;
  overflow: visible;
}
.chart + .chart { margin-top: 6px; }

.grid line {
  stroke: var(--border);
  stroke-width: 1;
  vector-effect: non-scaling-stroke;
}
.axis-lbl text {
  font-size: 11px;
  fill: var(--text-muted);
}
.bar-val {
  font-size: 11px;
  font-weight: 600;
  fill: var(--text);
}

.area-fill {
  fill: var(--primary);
  opacity: 0.16;
}
.area-line {
  fill: none;
  stroke: var(--primary);
  stroke-width: 2;
  stroke-linejoin: round;
  stroke-linecap: round;
  vector-effect: non-scaling-stroke;
}
.dot {
  fill: var(--surface);
  stroke: var(--primary);
  stroke-width: 2;
  vector-effect: non-scaling-stroke;
}
.appt-bar { fill: #64748b; }
.staff-bar { }

/* two-column layout for the lower charts */
.two-col {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 18px;
}
@media (max-width: 860px) {
  .two-col { grid-template-columns: 1fr; }
}

/* horizontal bars (top services) */
.hbars {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.hbar-top {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  font-size: 13px;
  margin-bottom: 5px;
}
.hbar-name {
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.hbar-val {
  color: var(--text-muted);
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}
.hbar-track {
  height: 10px;
  background: var(--surface-2);
  border-radius: 6px;
  overflow: hidden;
}
.hbar-fill {
  height: 100%;
  border-radius: 6px;
  transition: width 0.3s ease;
}
.hbar-sub {
  font-size: 11.5px;
  margin-top: 4px;
}
</style>
