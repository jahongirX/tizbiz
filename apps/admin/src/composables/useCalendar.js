// Shared, app-wide selected calendar date.
// Single reactive source of truth linking the sidebar MiniCalendar and the
// Timetable week view. Stored as a 'YYYY-MM-DD' string in Asia/Tashkent.
import { ref } from 'vue'
import { todayInput } from '../lib/datetime'

// Module-level singleton so every import shares the same reactive value.
const selectedDate = ref(todayInput())

// Set the selected date. Accepts a 'YYYY-MM-DD' string; ignores empty/no-op.
function setSelectedDate(d) {
  if (typeof d === 'string' && d && d !== selectedDate.value) {
    selectedDate.value = d
  }
}

export function useCalendar() {
  return { selectedDate, setSelectedDate }
}

export { selectedDate, setSelectedDate }
