// Telegram Mini App integration for the catalog SPA.
//
// When the storefront runs inside Telegram, window.Telegram.WebApp is present.
// We expand to full height, hand the signed initData to the API client (so the
// backend can identify the user), and expose a small helper the engine uses to
// pre-fill checkout and show order history. In a normal browser everything here
// is a no-op and the site behaves exactly as before.
import { config } from '@tizbiz/api-client'

const tg = typeof window !== 'undefined' ? window.Telegram?.WebApp : null

/** True when we are actually running inside a Telegram client. */
export const inTelegram = !!(tg && tg.initData)

/** Prepare the Mini App: expand, signal ready, wire initData into the API. */
export function initTelegram() {
  if (!tg) return
  try {
    tg.ready()
    tg.expand()
    if (typeof tg.disableVerticalSwipes === 'function') tg.disableVerticalSwipes()
    if (inTelegram) config.telegramInitData = tg.initData
  } catch (_) {
    /* older clients may lack some methods — ignore */
  }
}

/** Tint the Telegram header/background to the brand colour once it is known. */
export function applyTelegramChrome(brandHex) {
  if (!tg) return
  try {
    if (brandHex && typeof tg.setHeaderColor === 'function') tg.setHeaderColor(brandHex)
    if (typeof tg.setBackgroundColor === 'function') {
      const bg = getComputedStyle(document.documentElement).getPropertyValue('--bg').trim()
      if (bg) tg.setBackgroundColor(bg)
    }
  } catch (_) {
    /* colour APIs vary by version — ignore */
  }
}

/** Native haptic tap, when available (e.g. add-to-cart, order placed). */
export function haptic(type = 'light') {
  try {
    tg?.HapticFeedback?.impactOccurred?.(type)
  } catch (_) {
    /* ignore */
  }
}

export { tg }
