<script setup>
// Public tenant SPA shell ({slug}.tizbiz.uz). It loads the site payload once,
// reads the business `engine` and renders that engine's layout (stage 6). Adding
// a vertical = one entry in ENGINES + a component under ./engines/<key>/ ; the
// slot engine is the current online-booking flow. Engines are lazy-loaded so a
// visitor only downloads the layout their business actually uses.
import { ref, reactive, computed, onMounted, defineAsyncComponent } from 'vue'
import { api, config, ApiError } from '@tizbiz/api-client'
import { inTelegram, applyTelegramChrome } from './telegram'

const ENGINES = {
  slot: defineAsyncComponent(() => import('./engines/slot/SlotEngineApp.vue')),
  // Medical shares the web-catalog storefront (blue-themed), like food.
  medical: defineAsyncComponent(() => import('./engines/catalog/CatalogEngineApp.vue')),
  catalog: defineAsyncComponent(() => import('./engines/catalog/CatalogEngineApp.vue')),
}

// Per-engine brand palette layered on the shared TizBiz theme. Medical = blue,
// catalog = orange, rental = purple; slot keeps the default indigo.
const THEMES = {
  slot: { brand: '#5850ec', brand2: '#7c6cff', ink: '#ffffff', soft: '#eceafe', softDark: '#21243a' },
  medical: { brand: '#2563eb', brand2: '#38bdf8', ink: '#ffffff', soft: '#e6efff', softDark: '#12213f' },
  catalog: { brand: '#f2721c', brand2: '#fb9a3c', ink: '#ffffff', soft: '#fff0e3', softDark: '#2a1a0d' },
  rental: { brand: '#8b5cf6', brand2: '#a78bfa', ink: '#ffffff', soft: '#f1ebff', softDark: '#221a3a' },
}

// White or dark ink depending on the brand colour's luminance (WCAG-ish).
function contrastInk(hex) {
  const m = /^#([0-9a-f]{6})$/i.exec(hex || '')
  if (!m) return '#ffffff'
  const n = parseInt(m[1], 16)
  const [r, g, b] = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => {
    const c = v / 255
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
  })
  const lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
  return lum > 0.45 ? '#14172a' : '#ffffff'
}

// Per-engine default theme, overridden by the business's own brand colours.
function applyTheme(engine, business) {
  const t = THEMES[engine] || THEMES.slot
  const isDark = typeof window !== 'undefined'
    && window.matchMedia('(prefers-color-scheme: dark)').matches
  const root = document.documentElement.style

  const brand = business?.brand_color || t.brand
  const custom = !!business?.brand_color
  const brand2 =
    business?.brand_color_2 ||
    (custom ? `color-mix(in srgb, ${brand} 78%, #ffffff)` : t.brand2)
  const ink = custom ? contrastInk(brand) : t.ink
  const soft = custom
    ? `color-mix(in srgb, ${brand} 15%, ${isDark ? '#0c0e15' : '#ffffff'})`
    : isDark ? t.softDark : t.soft

  root.setProperty('--brand', brand)
  root.setProperty('--brand-2', brand2)
  root.setProperty('--brand-ink', ink)
  root.setProperty('--brand-soft', soft)
}

const slug =
  config.tenantSlug || new URLSearchParams(location.search).get('slug') || 'demo'

const loading = ref(true)
const notFound = ref(false)
const loadError = ref('')
const payload = ref(null)

const engineKey = computed(() => payload.value?.engine || 'slot')
const engineComp = computed(() => ENGINES[engineKey.value] || ENGINES.slot)

// Telegram Mini App context handed to the engine (guest defaults outside Telegram).
const tg = reactive({ inTelegram, profile: null })

onMounted(async () => {
  try {
    const data = await api.get(`/v1/site/${encodeURIComponent(slug)}`)
    if (!data.business) notFound.value = true
    else {
      payload.value = data
      applyTheme(data.engine || 'slot', data.business)
      const brand = getComputedStyle(document.documentElement).getPropertyValue('--brand').trim()
      applyTelegramChrome(brand)
      // Inside Telegram: identify the user (name + previously shared phone).
      if (inTelegram) {
        try {
          tg.profile = await api.post('/v1/telegram/webapp-auth', { slug, init_data: config.telegramInitData })
        } catch (_) {
          /* fall back to guest checkout */
        }
      }
    }
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) notFound.value = true
    else loadError.value = e instanceof ApiError ? e.message : 'Sahifani yuklab bo‘lmadi.'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <!-- Loading -->
  <div v-if="loading" class="center">
    <div>
      <div class="spinner"></div>
      <p class="note">Yuklanmoqda…</p>
    </div>
  </div>

  <!-- Not found -->
  <div v-else-if="notFound" class="center">
    <div>
      <div style="font-size: 44px">🔍</div>
      <h2>Biznes topilmadi</h2>
      <p class="note">"{{ slug }}" manzili bo‘yicha biznes mavjud emas.</p>
    </div>
  </div>

  <!-- Load error -->
  <div v-else-if="loadError" class="center">
    <div>
      <div style="font-size: 44px">⚠️</div>
      <h2>Xatolik</h2>
      <p class="note">{{ loadError }}</p>
    </div>
  </div>

  <!-- Engine layout -->
  <component
    v-else
    :is="engineComp"
    :slug="slug"
    :business="payload.business"
    :services="payload.services || []"
    :staff="payload.staff || []"
    :payload="payload"
    :tg="tg"
  />
</template>
