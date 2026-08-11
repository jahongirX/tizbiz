<script setup>
// Catalog engine (cafe / restaurant / cakes / clinic) public storefront.
// Mobile-first, single narrow column — identical framing to the slot engine
// (shared .shell / .brand / .card / .btn / .dock from style.css). Browsing is a
// category-grouped product list; the cart + checkout is a full-screen step-style
// sheet. Data comes from the site payload (categories -> items).
import { ref, reactive, computed, onMounted, onBeforeUnmount } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { soms } from '../../format'
import PhoneInput from '../../components/PhoneInput.vue'

const props = defineProps({
  slug: { type: String, default: '' },
  business: { type: Object, default: null },
  payload: { type: Object, default: () => ({}) },
})

const business = computed(() => props.business || props.payload?.business || {})
const categories = computed(() => props.payload?.categories || [])

const itemById = computed(() => {
  const m = {}
  for (const c of categories.value) for (const it of c.items || []) m[it.id] = it
  return m
})

const brandInitials = computed(() =>
  String(business.value?.name || '?')
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p[0])
    .join('')
    .toUpperCase(),
)
const bizPhone = computed(() => business.value?.phone || business.value?.phone_number || '')
const bizCategory = computed(() => business.value?.category || business.value?.category_name || '')

// ---- Cart (item id -> qty) ----
const cart = reactive({})
const cartLines = computed(() =>
  Object.entries(cart)
    .filter(([, q]) => q > 0)
    .map(([id, q]) => ({ item: itemById.value[id], qty: q }))
    .filter((l) => l.item),
)
const cartCount = computed(() => cartLines.value.reduce((s, l) => s + l.qty, 0))
const cartTotal = computed(() => cartLines.value.reduce((s, l) => s + l.item.price_tiyin * l.qty, 0))

function add(it) {
  cart[it.id] = (cart[it.id] || 0) + 1
}
function dec(it) {
  const q = (cart[it.id] || 0) - 1
  if (q > 0) cart[it.id] = q
  else delete cart[it.id]
}
function qtyOf(it) {
  return cart[it.id] || 0
}
function clearCart() {
  for (const k of Object.keys(cart)) delete cart[k]
}

// ---- Cart sheet + checkout ----
const cartOpen = ref(false)
const panel = ref('cart') // cart | checkout | done
const cust = reactive({ name: '', phone: '' })
const note = ref('')
const submitting = ref(false)
const orderError = ref('')
const placedOrder = ref(null)

function openCart() {
  if (!cartCount.value) return
  panel.value = 'cart'
  cartOpen.value = true
}
function closeCart() {
  cartOpen.value = false
}
function goCheckout() {
  if (cartCount.value > 0) {
    orderError.value = ''
    panel.value = 'checkout'
  }
}

async function placeOrder() {
  orderError.value = ''
  if (!cust.name.trim()) {
    orderError.value = 'Ismingizni kiriting'
    return
  }
  if (cust.phone.replace(/\D/g, '').length < 12) {
    orderError.value = 'Telefon raqamni to‘liq kiriting'
    return
  }
  submitting.value = true
  try {
    const order = await api.post('/v1/orders', {
      slug: props.slug || business.value.slug,
      items: cartLines.value.map((l) => ({ service_id: l.item.id, qty: l.qty })),
      customer: { name: cust.name.trim(), phone: cust.phone.trim() },
      note: note.value.trim() || undefined,
      source: 'site',
    })
    placedOrder.value = order
    panel.value = 'done'
    clearCart()
  } catch (e) {
    orderError.value = e instanceof ApiError ? e.message : 'Buyurtma yuborishda xatolik'
  } finally {
    submitting.value = false
  }
}

function reset() {
  panel.value = 'cart'
  cartOpen.value = false
  placedOrder.value = null
  cust.name = ''
  cust.phone = ''
  note.value = ''
}

// ---- Scroll-spy: highlight the active category chip ----
const activeCat = ref(null)
const sections = {}
function setSection(id, el) {
  if (el) sections[id] = el
}
function scrollTo(id) {
  sections[id]?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  activeCat.value = id
}
let observer = null
onMounted(() => {
  activeCat.value = categories.value[0]?.id ?? null
  observer = new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        if (e.isIntersecting) activeCat.value = Number(e.target.dataset.cat)
      }
    },
    { rootMargin: '-14% 0px -80% 0px', threshold: 0 },
  )
  Object.values(sections).forEach((el) => observer.observe(el))
})
onBeforeUnmount(() => observer?.disconnect())

// ---- Product detail sheet (gallery + description + counter) ----
const detail = ref(null)
const galleryIndex = ref(0)
function openDetail(it) {
  detail.value = it
  galleryIndex.value = 0
}
function closeDetail() {
  detail.value = null
}
const detailImages = computed(() => {
  const it = detail.value
  if (!it) return []
  const g = Array.isArray(it.gallery) ? it.gallery.filter(Boolean) : []
  if (it.image && !g.includes(it.image)) g.unshift(it.image)
  return g.length ? g : it.image ? [it.image] : []
})
</script>

<template>
  <div class="cat-root">
  <!-- BROWSE: same narrow column + branded header as the step engine -->
  <div class="shell">
    <header class="brand">
      <div class="brand-top">
        <div class="brand-logo">{{ brandInitials }}</div>
        <div class="brand-info">
          <h1>{{ business.name }}</h1>
          <div class="sub">Onlayn buyurtma</div>
        </div>
      </div>
      <div v-if="bizCategory || bizPhone" class="brand-chips">
        <span v-if="bizCategory" class="brand-chip">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M20.59 13.41l-7.17 7.17a2 2 0 01-2.83 0L2 12V2h10l8.59 8.59a2 2 0 010 2.82z" />
            <line x1="7" y1="7" x2="7.01" y2="7" />
          </svg>
          {{ bizCategory }}
        </span>
        <a v-if="bizPhone" class="brand-chip" :href="`tel:${bizPhone}`">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07 19.5 19.5 0 01-6-6 19.79 19.79 0 01-3.07-8.67A2 2 0 014.11 2h3a2 2 0 012 1.72c.13.96.36 1.9.7 2.81a2 2 0 01-.45 2.11L8.09 9.91a16 16 0 006 6l1.27-1.27a2 2 0 012.11-.45c.9.34 1.85.57 2.81.7A2 2 0 0122 16.92z" />
          </svg>
          {{ bizPhone }}
        </a>
      </div>
    </header>

    <!-- category chips -->
    <div v-if="categories.length" class="cat-strip">
      <button
        v-for="c in categories"
        :key="c.id"
        class="cat-chip"
        :class="{ on: activeCat === c.id }"
        @click="scrollTo(c.id)"
      >
        {{ c.name }}
      </button>
    </div>

    <!-- product sections -->
    <section
      v-for="c in categories"
      :key="c.id"
      :ref="(el) => setSection(c.id, el)"
      :data-cat="c.id"
      class="prod-sec"
    >
      <h2 class="sec-title">{{ c.name }}</h2>
      <article v-for="it in c.items" :key="it.id" class="card prod">
        <button class="prod-main" @click="openDetail(it)">
          <span class="thumb">
            <img v-if="it.image" :src="it.image" :alt="it.name" />
            <span v-else class="thumb-ph">{{ it.name.charAt(0) }}</span>
          </span>
          <span class="grow">
            <span class="title">{{ it.name }}</span>
            <span class="price">{{ soms(it.price_tiyin) }}</span>
          </span>
        </button>
        <div class="ctrl">
          <div v-if="qtyOf(it) > 0" class="qty">
            <button aria-label="Kamaytirish" @click="dec(it)">−</button>
            <span>{{ qtyOf(it) }}</span>
            <button aria-label="Ko‘paytirish" @click="add(it)">+</button>
          </div>
          <button v-else class="add" aria-label="Qo‘shish" @click="add(it)">
            <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor"
              stroke-width="2.4" stroke-linecap="round">
              <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
            </svg>
          </button>
        </div>
      </article>
    </section>

    <div v-if="!categories.length" class="empty">
      <div class="emo">🍽️</div>
      Menyu hozircha bo‘sh.
    </div>
  </div>

  <!-- fixed bottom dock: go to cart -->
  <div v-if="cartCount && !cartOpen" class="dock">
    <div class="dock-inner">
      <button class="btn cart-cta" @click="openCart">
        <span class="cta-count">{{ cartCount }}</span>
        <span>Savatga o‘tish</span>
        <strong>{{ soms(cartTotal) }}</strong>
      </button>
    </div>
  </div>

  <!-- CART sheet: full-screen, narrow column, step-style -->
  <div v-if="cartOpen" class="sheet">
    <div class="shell">
      <div class="step-head sheet-head">
        <button class="back" aria-label="Orqaga" @click="closeCart">←</button>
        <h2>{{ panel === 'checkout' ? 'Rasmiylashtirish' : panel === 'done' ? 'Tayyor' : 'Savat' }}</h2>
        <button
          v-if="cartLines.length && panel === 'cart'"
          class="clear"
          @click="clearCart"
        >
          Tozalash
        </button>
      </div>

      <!-- cart list -->
      <template v-if="panel === 'cart'">
        <div v-if="!cartLines.length" class="empty">
          <div class="emo">🛍️</div>
          Savat bo‘sh
        </div>
        <template v-else>
          <article v-for="l in cartLines" :key="l.item.id" class="card">
            <span class="thumb sm">
              <img v-if="l.item.image" :src="l.item.image" :alt="l.item.name" />
              <span v-else class="thumb-ph">{{ l.item.name.charAt(0) }}</span>
            </span>
            <div class="grow">
              <div class="title">{{ l.item.name }}</div>
              <div class="meta">{{ soms(l.item.price_tiyin * l.qty) }}</div>
            </div>
            <div class="qty">
              <button aria-label="Kamaytirish" @click="dec(l.item)">−</button>
              <span>{{ l.qty }}</span>
              <button aria-label="Ko‘paytirish" @click="add(l.item)">+</button>
            </div>
          </article>

          <div class="summary">
            <div class="row total">
              <span class="k">Jami</span>
              <span class="v accent">{{ soms(cartTotal) }}</span>
            </div>
          </div>
          <button class="btn" @click="goCheckout">Rasmiylashtirish</button>
        </template>
      </template>

      <!-- checkout form -->
      <template v-else-if="panel === 'checkout'">
        <div v-if="orderError" class="alert">{{ orderError }}</div>
        <div class="field">
          <label>Ismingiz</label>
          <input v-model="cust.name" type="text" placeholder="Ism" />
        </div>
        <div class="field">
          <label>Telefon</label>
          <PhoneInput v-model="cust.phone" />
        </div>
        <div class="field">
          <label>Izoh (ixtiyoriy)</label>
          <input v-model="note" type="text" placeholder="Manzil yoki izoh" />
        </div>
        <div class="summary">
          <div class="row total">
            <span class="k">To‘lov</span>
            <span class="v accent">{{ soms(cartTotal) }}</span>
          </div>
        </div>
        <button class="btn" :disabled="submitting" @click="placeOrder">
          {{ submitting ? 'Yuborilmoqda…' : 'Buyurtma berish' }}
        </button>
        <button class="btn ghost" @click="panel = 'cart'">← Savatga qaytish</button>
      </template>

      <!-- done -->
      <template v-else>
        <div class="done-hero">
          <div class="check">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"
              stroke-linecap="round" stroke-linejoin="round">
              <polyline points="20 6 9 17 4 12" />
            </svg>
          </div>
          <h2>Buyurtma qabul qilindi!</h2>
          <p>#{{ placedOrder?.id }} · {{ soms(placedOrder?.total_tiyin) }}</p>
        </div>
        <button class="btn" @click="reset">Yana buyurtma</button>
      </template>
    </div>
  </div>

  <!-- Product detail sheet: gallery + price + description + counter -->
  <div v-if="detail" class="modal-backdrop" @click.self="closeDetail">
    <div class="modal">
      <button class="modal-x" aria-label="Yopish" @click="closeDetail">✕</button>
      <div class="mg-main">
        <img v-if="detailImages.length" :src="detailImages[galleryIndex]" :alt="detail.name" />
        <span v-else class="thumb-ph big">{{ detail.name.charAt(0) }}</span>
      </div>
      <div v-if="detailImages.length > 1" class="mg-thumbs">
        <button
          v-for="(g, idx) in detailImages"
          :key="idx"
          class="mg-thumb"
          :class="{ on: idx === galleryIndex }"
          @click="galleryIndex = idx"
        >
          <img :src="g" alt="" />
        </button>
      </div>
      <div class="modal-info">
        <div class="modal-price">{{ soms(detail.price_tiyin) }}</div>
        <h3 class="modal-name">{{ detail.name }}</h3>
        <p v-if="detail.description" class="modal-desc">{{ detail.description }}</p>
        <div v-if="qtyOf(detail) > 0" class="qty big">
          <button aria-label="Kamaytirish" @click="dec(detail)">−</button>
          <span>{{ qtyOf(detail) }}</span>
          <button aria-label="Ko‘paytirish" @click="add(detail)">+</button>
        </div>
        <button v-else class="btn" @click="add(detail)">
          Savatga qo‘shish · {{ soms(detail.price_tiyin) }}
        </button>
      </div>
    </div>
  </div>
  </div>
</template>

<style scoped>
/* Single template root that doesn't create a box (fixed/centered children keep
   their viewport-relative behaviour). */
.cat-root {
  display: contents;
}

/* Category chips (horizontal, matches the day-strip idiom) */
.cat-strip {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 2px 2px 12px;
  margin: 0 -2px 6px;
  scrollbar-width: none;
}
.cat-strip::-webkit-scrollbar {
  display: none;
}
.cat-chip {
  flex: 0 0 auto;
  padding: 8px 14px;
  border: 1px solid var(--border);
  border-radius: 999px;
  background: var(--surface);
  color: var(--text);
  font-size: 14px;
  font-weight: 600;
  white-space: nowrap;
  box-shadow: var(--shadow-sm);
}
.cat-chip.on {
  background: var(--brand);
  border-color: var(--brand);
  color: var(--brand-ink);
  box-shadow: var(--shadow-brand);
}

/* Sections */
.prod-sec {
  scroll-margin-top: 96px;
  margin-bottom: 18px;
}
.sec-title {
  font-size: 18px;
  font-weight: 700;
  letter-spacing: -0.01em;
  margin: 4px 2px 12px;
}

/* Product row — built on the shared .card */
.prod {
  justify-content: space-between;
  gap: 10px;
}
.prod-main {
  flex: 1;
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 13px;
  border: none;
  background: transparent;
  padding: 0;
  text-align: left;
  color: var(--text);
}
.thumb {
  width: 56px;
  height: 56px;
  flex: 0 0 auto;
  border-radius: 14px;
  overflow: hidden;
  background: #fff;
  display: grid;
  place-items: center;
}
.thumb.sm {
  width: 46px;
  height: 46px;
  border-radius: 12px;
}
.thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.thumb-ph {
  width: 100%;
  height: 100%;
  display: grid;
  place-items: center;
  font-weight: 800;
  font-size: 20px;
  color: var(--brand);
  background: var(--brand-soft);
}
.thumb-ph.big {
  font-size: 64px;
}
.prod .title {
  font-weight: 650;
  font-size: 15px;
  line-height: 1.25;
}
.prod .price {
  font-weight: 750;
  font-size: 15px;
  margin-top: 3px;
}

/* Add button + stepper */
.ctrl {
  flex: 0 0 auto;
}
.add {
  width: 40px;
  height: 40px;
  border: none;
  border-radius: 12px;
  background: var(--brand-soft);
  color: var(--brand);
  display: grid;
  place-items: center;
  transition: background 0.15s, color 0.15s;
}
.add:active {
  transform: scale(0.94);
}
.qty {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  height: 40px;
  border-radius: 12px;
  background: var(--brand);
  padding: 4px;
}
.qty button {
  width: 32px;
  height: 32px;
  border: none;
  border-radius: 9px;
  background: rgba(255, 255, 255, 0.2);
  color: var(--brand-ink);
  font-size: 19px;
  font-weight: 700;
  line-height: 1;
}
.qty span {
  min-width: 24px;
  text-align: center;
  font-weight: 800;
  color: var(--brand-ink);
}
.qty.big {
  height: 52px;
  border-radius: 14px;
  width: 100%;
  justify-content: space-between;
}
.qty.big button {
  width: 44px;
  height: 44px;
  font-size: 24px;
}

/* Cart dock CTA */
.cart-cta {
  gap: 10px;
}
.cta-count {
  background: rgba(255, 255, 255, 0.22);
  border-radius: 999px;
  padding: 2px 10px;
  font-size: 13px;
}
.cart-cta strong {
  margin-left: auto;
}

/* Cart sheet overlay */
.sheet {
  position: fixed;
  inset: 0;
  z-index: 40;
  overflow-y: auto;
  background: var(--bg);
}
.sheet-head {
  padding-top: calc(14px + env(safe-area-inset-top));
  justify-content: flex-start;
}
.sheet-head h2 {
  flex: 1;
}
.clear {
  border: none;
  background: transparent;
  color: var(--muted);
  font-size: 13px;
}
.summary .row.total .v {
  font-size: 17px;
}

/* Product detail — bottom sheet, single column */
.modal-backdrop {
  position: fixed;
  inset: 0;
  z-index: 100;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: flex-end;
  justify-content: center;
}
.modal {
  position: relative;
  width: 100%;
  max-width: 520px;
  max-height: 92vh;
  overflow-y: auto;
  background: var(--surface);
  border-radius: 24px 24px 0 0;
  padding: 16px 16px calc(20px + env(safe-area-inset-bottom));
}
@media (min-width: 560px) {
  .modal-backdrop {
    align-items: center;
  }
  .modal {
    border-radius: 24px;
  }
}
.modal-x {
  position: absolute;
  top: 14px;
  right: 14px;
  z-index: 2;
  width: 34px;
  height: 34px;
  border-radius: 50%;
  border: none;
  background: rgba(0, 0, 0, 0.45);
  color: #fff;
  font-size: 15px;
}
.mg-main {
  aspect-ratio: 4 / 3;
  border-radius: 18px;
  overflow: hidden;
  background: #fff;
}
.mg-main img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.mg-thumbs {
  display: flex;
  gap: 8px;
  margin-top: 10px;
  flex-wrap: wrap;
}
.mg-thumb {
  width: 58px;
  height: 58px;
  border-radius: 12px;
  overflow: hidden;
  border: 2px solid transparent;
  background: #fff;
  padding: 0;
}
.mg-thumb.on {
  border-color: var(--brand);
}
.mg-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.modal-info {
  padding: 16px 4px 4px;
}
.modal-price {
  font-size: 24px;
  font-weight: 800;
}
.modal-name {
  font-size: 19px;
  margin: 4px 0 8px;
}
.modal-desc {
  color: var(--muted);
  font-size: 14px;
  line-height: 1.6;
  margin: 0 0 18px;
}
</style>
