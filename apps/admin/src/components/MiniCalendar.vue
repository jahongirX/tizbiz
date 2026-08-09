<script setup>
import { ref, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ChevronLeft, ChevronRight } from 'lucide-vue-next'
import { todayInput, addDays, mondayOf, monthName, dayNum } from '../lib/datetime'
import { selectedDate, setSelectedDate } from '../composables/useCalendar'

const route = useRoute()
const router = useRouter()

// Mon-first weekday initials + Uzbek month names come from datetime helpers.
const WEEKDAY_INITIALS = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya']

const today = todayInput()

// First day ('YYYY-MM-01') of the month currently displayed in the grid.
function firstOfMonth(dateStr) {
  return dateStr.slice(0, 7) + '-01'
}

// The visible month follows selectedDate, but can be paged independently.
const cursor = ref(firstOfMonth(selectedDate.value))

// Keep the visible month in sync when selectedDate jumps to another month.
watch(selectedDate, (d) => {
  if (d.slice(0, 7) !== cursor.value.slice(0, 7)) {
    cursor.value = firstOfMonth(d)
  }
})

function shiftMonth(delta) {
  const d = new Date(firstOfMonth(cursor.value) + 'T00:00:00Z')
  d.setUTCMonth(d.getUTCMonth() + delta, 1)
  cursor.value = d.toISOString().slice(0, 10)
}
function prevMonth() {
  shiftMonth(-1)
}
function nextMonth() {
  shiftMonth(1)
}

const monthLabel = computed(() => {
  const name = monthName(cursor.value)
  const year = cursor.value.slice(0, 4)
  return `${name.charAt(0).toUpperCase()}${name.slice(1)} ${year}`
})

// 6-week grid (42 cells) starting on the Monday on/before the 1st.
const days = computed(() => {
  const start = mondayOf(firstOfMonth(cursor.value))
  const month = cursor.value.slice(0, 7)
  const out = []
  for (let i = 0; i < 42; i++) {
    const date = addDays(start, i)
    out.push({
      date,
      day: dayNum(date),
      inMonth: date.slice(0, 7) === month,
      isToday: date === today,
      isSelected: date === selectedDate.value,
    })
  }
  return out
})

function pick(d) {
  setSelectedDate(d.date)
  // If we are not on the timetable home, jump there so the choice is visible.
  if (route.name !== 'home') router.push('/')
}
</script>

<template>
  <div class="mini-cal">
    <div class="mc-head">
      <button type="button" class="mc-arrow" aria-label="Oldingi oy" @click="prevMonth">
        <ChevronLeft :size="16" />
      </button>
      <span class="mc-title">{{ monthLabel }}</span>
      <button type="button" class="mc-arrow" aria-label="Keyingi oy" @click="nextMonth">
        <ChevronRight :size="16" />
      </button>
    </div>

    <div class="mc-grid mc-weekdays" aria-hidden="true">
      <span v-for="w in WEEKDAY_INITIALS" :key="w" class="mc-wd">{{ w }}</span>
    </div>

    <div class="mc-grid">
      <button
        v-for="d in days"
        :key="d.date"
        type="button"
        class="mc-day"
        :class="{ out: !d.inMonth, today: d.isToday, selected: d.isSelected }"
        :aria-current="d.isToday ? 'date' : undefined"
        :aria-pressed="d.isSelected"
        @click="pick(d)"
      >
        {{ d.day }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.mini-cal {
  padding: 10px;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  background: var(--surface-2);
  width: 100%;
  min-width: 0;
}
.mc-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 6px;
  margin-bottom: 8px;
}
.mc-title {
  font-size: 13px;
  font-weight: 650;
}
.mc-arrow {
  width: 24px;
  height: 24px;
  display: grid;
  place-items: center;
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text);
  border-radius: 6px;
  font-size: 14px;
  line-height: 1;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s;
}
.mc-arrow:hover {
  background: var(--surface-2);
  border-color: var(--primary);
}
.mc-grid {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
  gap: 2px;
}
.mc-weekdays {
  margin-bottom: 4px;
}
.mc-wd {
  text-align: center;
  font-size: 10.5px;
  font-weight: 600;
  color: var(--text-muted);
  padding: 2px 0;
}
.mc-day {
  aspect-ratio: 1 / 1;
  display: grid;
  place-items: center;
  border: 1px solid transparent;
  background: transparent;
  color: var(--text);
  border-radius: 6px;
  font: inherit;
  font-size: 11.5px;
  font-weight: 550;
  cursor: pointer;
  font-variant-numeric: tabular-nums;
  transition: background 0.12s, color 0.12s, border-color 0.12s;
}
.mc-day:hover {
  background: var(--surface);
  border-color: var(--border);
}
.mc-day.out {
  color: var(--text-muted);
  opacity: 0.5;
}
.mc-day.today {
  color: var(--primary);
  font-weight: 700;
}
.mc-day.selected {
  background: var(--primary);
  color: #fff;
  border-color: var(--primary);
}
.mc-day.selected.today {
  color: #fff;
}
</style>
