// Shared formatting helpers. Money from the API is in TIYIN (1/100 so'm).

/** 5000000 (tiyin) -> "50 000 so'm" */
export function soms(tiyin) {
  const som = Math.round((Number(tiyin) || 0) / 100)
  return som.toLocaleString('ru-RU').replace(/ /g, ' ') + " so'm"
}

/** Minutes -> human duration, e.g. 90 -> "1 soat 30 daqiqa" */
export function duration(min) {
  const m = Number(min) || 0
  const h = Math.floor(m / 60)
  const r = m % 60
  const parts = []
  if (h) parts.push(h + ' soat')
  if (r || !h) parts.push(r + ' daqiqa')
  return parts.join(' ')
}

/** ISO date (YYYY-MM-DD) for a local Date. */
export function isoDate(d = new Date()) {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

/** Pretty local time out of a slot's start_local ('Y-m-d H:i:s'). */
export function slotTime(startLocal) {
  if (!startLocal) return ''
  const t = String(startLocal).slice(11, 16) // HH:MM
  return t || startLocal
}

const DOW_UZ = ['Yak', 'Dush', 'Sesh', 'Chor', 'Pay', 'Jum', 'Shan']
const MON_UZ = [
  'yan', 'fev', 'mar', 'apr', 'may', 'iyn',
  'iyl', 'avg', 'sen', 'okt', 'noy', 'dek',
]
const MON_UZ_FULL = [
  'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
  'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
]

/** Build N calendar days starting today, as {iso, dow, num, mon, label} for the day strip. */
export function dayStrip(count = 14, from = new Date()) {
  const base = new Date(from.getFullYear(), from.getMonth(), from.getDate())
  const out = []
  for (let i = 0; i < count; i++) {
    const d = new Date(base)
    d.setDate(base.getDate() + i)
    out.push({
      iso: isoDate(d),
      dow: i === 0 ? 'Bugun' : i === 1 ? 'Ertaga' : DOW_UZ[d.getDay()],
      num: d.getDate(),
      mon: MON_UZ[d.getMonth()],
    })
  }
  return out
}

/** Bucket a slot's start hour: 'morning' | 'afternoon' | 'evening'. */
export function slotBucket(startLocal) {
  const h = Number(String(startLocal || '').slice(11, 13)) || 0
  if (h < 12) return 'morning'
  if (h < 17) return 'afternoon'
  return 'evening'
}

/** Pretty local date+time for confirmation, e.g. "18 iyul · 14:30". */
export function prettyLocal(startLocal) {
  if (!startLocal) return ''
  const [date, time] = String(startLocal).split(' ')
  const parts = String(date).split('-')
  const hm = (time || '').slice(0, 5)
  if (parts.length === 3) {
    const day = Number(parts[2])
    const mon = MON_UZ_FULL[Number(parts[1]) - 1] || ''
    return `${day} ${mon} · ${hm}`
  }
  return `${date} · ${hm}`
}
