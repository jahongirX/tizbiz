// Money helpers. The API always speaks TIYIN (integer, 1/100 so'm).
// UI collects and displays SO'M.

export function tiyinToSom(tiyin) {
  const n = Number(tiyin) || 0
  return n / 100
}

export function somToTiyin(som) {
  const n = Number(som) || 0
  return Math.round(n * 100)
}

// 5000000 (tiyin) -> "50 000 so'm"
export function formatSom(tiyin) {
  const som = Math.round(tiyinToSom(tiyin))
  const sign = som < 0 ? '-' : ''
  const s = String(Math.abs(som)).replace(/\B(?=(\d{3})+(?!\d))/g, ' ')
  return `${sign}${s} so'm`
}
