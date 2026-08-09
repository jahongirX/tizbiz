// Datetime helpers. API datetimes are UTC 'Y-m-d H:i:s'.
// We store/query in UTC and display in Asia/Tashkent.

const TZ = 'Asia/Tashkent'

// YYYY-MM-DD for a Date, in the given timezone (default local Tashkent).
export function toDateInput(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: TZ,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date)
  const map = Object.fromEntries(parts.map((p) => [p.type, p.value]))
  return `${map.year}-${map.month}-${map.day}`
}

export function todayInput() {
  return toDateInput(new Date())
}

// Add N days to a YYYY-MM-DD string.
export function addDays(dateStr, days) {
  const d = new Date(dateStr + 'T00:00:00Z')
  d.setUTCDate(d.getUTCDate() + days)
  return d.toISOString().slice(0, 10)
}

// Build the UTC 'Y-m-d H:i:s' bounds for a local (Tashkent) day.
// Tashkent is UTC+5 with no DST, so local midnight = UTC 19:00 the previous day.
const TZ_OFFSET_HOURS = 5

function pad(n) {
  return String(n).padStart(2, '0')
}

// Local Tashkent day start -> UTC 'Y-m-d H:i:s'.
export function localDayStartUtc(dateStr) {
  const d = new Date(dateStr + 'T00:00:00Z')
  d.setUTCHours(d.getUTCHours() - TZ_OFFSET_HOURS)
  return utcString(d)
}

// Local Tashkent day end (exclusive: next day start) -> UTC 'Y-m-d H:i:s'.
export function localDayEndUtc(dateStr) {
  return localDayStartUtc(addDays(dateStr, 1))
}

function utcString(d) {
  return (
    `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())} ` +
    `${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}:${pad(d.getUTCSeconds())}`
  )
}

// Parse a value into a Date: a UTC 'Y-m-d H:i:s' string, or a unix timestamp
// (integer seconds — as TimestampBehavior stores created_at/updated_at).
export function parseUtc(value) {
  if (value === null || value === undefined || value === '') return null
  if (typeof value === 'number') return new Date(value * 1000)
  const str = String(value)
  if (/^\d+$/.test(str)) return new Date(Number(str) * 1000) // numeric string = unix seconds
  return new Date(str.replace(' ', 'T') + 'Z')
}

// Show a UTC datetime as Tashkent time "HH:mm".
export function formatTime(utcStr) {
  const d = parseUtc(utcStr)
  if (!d) return ''
  return new Intl.DateTimeFormat('uz-UZ', {
    timeZone: TZ,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(d)
}

// Show a UTC datetime as Tashkent "dd.MM.yyyy HH:mm".
export function formatDateTime(utcStr) {
  const d = parseUtc(utcStr)
  if (!d) return ''
  return new Intl.DateTimeFormat('uz-UZ', {
    timeZone: TZ,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(d)
}

// Show a local time already given as 'Y-m-d H:i:s' (start_local) -> "HH:mm".
export function formatLocalTime(localStr) {
  if (!localStr) return ''
  const m = localStr.match(/(\d{2}):(\d{2})/)
  return m ? `${m[1]}:${m[2]}` : localStr
}

// --- Week / calendar helpers (Tashkent-local, fixed UTC+5) ---

// Minutes-since-local-midnight for a UTC 'Y-m-d H:i:s' string.
export function localMinutes(utcStr) {
  const d = parseUtc(utcStr)
  if (!d) return null
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: TZ,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(d)
  const map = Object.fromEntries(parts.map((p) => [p.type, p.value]))
  return Number(map.hour) * 60 + Number(map.minute)
}

// The Tashkent-local calendar day ('YYYY-MM-DD') a UTC datetime falls on.
export function localDateInput(utcStr) {
  const d = parseUtc(utcStr)
  return d ? toDateInput(d) : ''
}

// Monday ('YYYY-MM-DD') of the ISO week containing the given day.
export function mondayOf(dateStr) {
  const d = new Date(dateStr + 'T00:00:00Z')
  const dow = d.getUTCDay() // 0=Sun..6=Sat
  const diff = dow === 0 ? -6 : 1 - dow
  return addDays(dateStr, diff)
}

// Local Tashkent datetime (dateStr + 'HH:MM') -> UTC 'Y-m-d H:i:s'.
export function localToUtc(dateStr, hhmm) {
  const [h, m] = String(hhmm).split(':').map(Number)
  const d = new Date(dateStr + 'T00:00:00Z')
  d.setUTCHours((h || 0) - TZ_OFFSET_HOURS, m || 0, 0, 0)
  return utcString(d)
}

// "HH:MM" from minutes-since-midnight.
export function minutesToHhmm(min) {
  const h = Math.floor(min / 60)
  const m = min % 60
  return `${pad(h)}:${pad(m)}`
}

// Minutes-since-local-midnight for right now (Tashkent).
export function nowLocalMinutes() {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: TZ,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(new Date())
  const map = Object.fromEntries(parts.map((p) => [p.type, p.value]))
  return Number(map.hour) * 60 + Number(map.minute)
}

const UZ_MONTHS = [
  'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
  'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
]

// Day-of-month number for a 'YYYY-MM-DD' string.
export function dayNum(dateStr) {
  return Number(dateStr.slice(8, 10))
}

// Uzbek month name for a 'YYYY-MM-DD' string.
export function monthName(dateStr) {
  return UZ_MONTHS[Number(dateStr.slice(5, 7)) - 1] || ''
}

// "13 - 19 iyul" / "29 iyun - 5 iyul" for a Mon..Sun pair.
export function formatWeekRange(mondayStr, sundayStr) {
  const m1 = monthName(mondayStr)
  const m2 = monthName(sundayStr)
  if (m1 === m2) return `${dayNum(mondayStr)} - ${dayNum(sundayStr)} ${m2}`
  return `${dayNum(mondayStr)} ${m1} - ${dayNum(sundayStr)} ${m2}`
}
