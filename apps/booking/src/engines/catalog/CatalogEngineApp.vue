<script setup>
// Catalog engine (cafe / restaurant / cakes) public storefront — Yandex-Eda
// style: category menu on the left, product grid in the middle, cart on the
// right with checkout -> POST /v1/orders. Data comes from the site payload
// (categories -> items) loaded once by the parent App.vue.
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

// ---- Checkout ----
const panel = ref('cart') // cart | checkout | done
const cust = reactive({ name: '', phone: '' })
const note = ref('')
const submitting = ref(false)
const orderError = ref('')
const placedOrder = ref(null)

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
    for (const k of Object.keys(cart)) delete cart[k]
  } catch (e) {
    orderError.value = e instanceof ApiError ? e.message : 'Buyurtma yuborishda xatolik'
  } finally {
    submitting.value = false
  }
}

function reset() {
  panel.value = 'cart'
  placedOrder.value = null
  cust.name = ''
  cust.phone = ''
  note.value = ''
}

// ---- Scroll-spy for the category menu ----
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
    { rootMargin: '-15% 0px -75% 0px', threshold: 0 },
  )
  Object.values(sections).forEach((el) => observer.observe(el))
})
onBeforeUnmount(() => observer?.disconnect())

const brandInitials = computed(() =>
  String(business.value?.name || '?')
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p[0])
    .join('')
    .toUpperCase(),
)
</script>

<template>
  <div class="cat-shell">
    <!-- Left: category menu -->
    <aside class="cat-menu">
      <div class="cat-brand">
        <span class="cat-logo">{{ brandInitials }}</span>
        <div class="cat-brand-txt">
          <strong>{{ business.name }}</strong>
          <span class="muted sm">Menyu</span>
        </div>
      </div>
      <nav class="cat-nav">
        <button
          v-for="c in categories"
          :key="c.id"
          class="cat-nav-item"
          :class="{ active: activeCat === c.id }"
          @click="scrollTo(c.id)"
        >
          {{ c.name }}
        </button>
      </nav>
    </aside>

    <!-- Middle: hero + product sections -->
    <main class="cat-main">
      <div class="cat-hero">
        <div class="cat-hero-body">
          <h1>{{ business.name }}</h1>
          <p>Onlayn buyurtma · tez va qulay</p>
        </div>
      </div>

      <section
        v-for="c in categories"
        :key="c.id"
        :ref="(el) => setSection(c.id, el)"
        :data-cat="c.id"
        class="cat-section"
      >
        <h2>{{ c.name }}</h2>
        <div class="cat-grid">
          <article v-for="it in c.items" :key="it.id" class="prod">
            <div class="prod-thumb">
              <img v-if="it.image" :src="it.image" :alt="it.name" />
              <span v-else>{{ it.name.charAt(0) }}</span>
            </div>
            <div class="prod-body">
              <div class="prod-name">{{ it.name }}</div>
              <div class="prod-price">{{ soms(it.price_tiyin) }}</div>
            </div>
            <div class="prod-action">
              <div v-if="qtyOf(it) > 0" class="stepper">
                <button aria-label="Kamaytirish" @click="dec(it)">−</button>
                <span>{{ qtyOf(it) }}</span>
                <button aria-label="Ko‘paytirish" @click="add(it)">+</button>
              </div>
              <button v-else class="add-btn" @click="add(it)">Qo‘shish</button>
            </div>
          </article>
        </div>
      </section>

      <div v-if="!categories.length" class="empty-menu">Menyu hozircha bo‘sh.</div>
    </main>

    <!-- Right: cart -->
    <aside class="cat-cart">
      <div class="cart-card">
        <div class="cart-head">
          <h3>Savat</h3>
          <span v-if="cartCount" class="badge">{{ cartCount }}</span>
        </div>

        <!-- Cart list -->
        <template v-if="panel === 'cart'">
          <div v-if="!cartLines.length" class="cart-empty">
            <div class="cart-empty-ico">🛒</div>
            Savat bo‘sh — menyudan tanlang.
          </div>
          <template v-else>
            <div class="cart-lines">
              <div v-for="l in cartLines" :key="l.item.id" class="cart-line">
                <div class="cl-name">{{ l.item.name }}</div>
                <div class="stepper sm">
                  <button @click="dec(l.item)">−</button>
                  <span>{{ l.qty }}</span>
                  <button @click="add(l.item)">+</button>
                </div>
                <div class="cl-price">{{ soms(l.item.price_tiyin * l.qty) }}</div>
              </div>
            </div>
            <div class="cart-total"><span>Jami</span><strong>{{ soms(cartTotal) }}</strong></div>
            <button class="checkout-btn" @click="goCheckout">Rasmiylashtirish</button>
          </template>
        </template>

        <!-- Checkout form -->
        <template v-else-if="panel === 'checkout'">
          <div v-if="orderError" class="alert">{{ orderError }}</div>
          <label class="fl">Ismingiz</label>
          <input v-model="cust.name" class="fi" placeholder="Ism" />
          <label class="fl">Telefon</label>
          <PhoneInput v-model="cust.phone" />
          <label class="fl">Izoh (ixtiyoriy)</label>
          <textarea v-model="note" class="fi" rows="2" placeholder="Manzil yoki izoh"></textarea>
          <div class="cart-total"><span>Jami</span><strong>{{ soms(cartTotal) }}</strong></div>
          <button class="checkout-btn" :disabled="submitting" @click="placeOrder">
            {{ submitting ? 'Yuborilmoqda…' : 'Buyurtma berish' }}
          </button>
          <button class="link-btn" @click="panel = 'cart'">← Savatga qaytish</button>
        </template>

        <!-- Done -->
        <template v-else>
          <div class="done">
            <div class="done-ico">✓</div>
            <h4>Buyurtma qabul qilindi!</h4>
            <p class="muted">
              Buyurtma #{{ placedOrder?.id }} · {{ soms(placedOrder?.total_tiyin) }}
            </p>
            <p class="muted sm">Tez orada siz bilan bog‘lanamiz.</p>
            <button class="checkout-btn" @click="reset">Yana buyurtma</button>
          </div>
        </template>
      </div>
    </aside>
  </div>
</template>

<style scoped>
.cat-shell {
  display: grid;
  grid-template-columns: 210px minmax(0, 1fr) 320px;
  gap: 18px;
  max-width: 1200px;
  margin: 0 auto;
  padding: 18px;
  align-items: start;
}
.sm {
  font-size: 12px;
}
.muted {
  color: var(--muted);
}

/* Left menu */
.cat-menu {
  position: sticky;
  top: 18px;
}
.cat-brand {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 14px;
}
.cat-logo {
  width: 40px;
  height: 40px;
  border-radius: 12px;
  background: var(--brand);
  color: var(--brand-ink);
  display: grid;
  place-items: center;
  font-weight: 800;
}
.cat-brand-txt {
  display: flex;
  flex-direction: column;
  line-height: 1.2;
}
.cat-nav {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.cat-nav-item {
  text-align: left;
  border: none;
  background: transparent;
  color: var(--text);
  padding: 9px 12px;
  border-radius: 10px;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
}
.cat-nav-item:hover {
  background: var(--surface-2);
}
.cat-nav-item.active {
  background: var(--brand-soft);
  color: var(--brand);
}

/* Middle */
.cat-hero {
  border-radius: var(--radius);
  background: linear-gradient(135deg, var(--brand), var(--brand-2));
  color: var(--brand-ink);
  padding: 32px 26px;
  margin-bottom: 20px;
  box-shadow: var(--shadow-brand);
}
.cat-hero-body h1 {
  margin: 0 0 4px;
  font-size: 28px;
}
.cat-hero-body p {
  margin: 0;
  opacity: 0.9;
}
.cat-section {
  scroll-margin-top: 12px;
  margin-bottom: 26px;
}
.cat-section h2 {
  font-size: 20px;
  margin: 0 0 12px;
}
.cat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(215px, 1fr));
  gap: 12px;
}
.prod {
  display: flex;
  flex-direction: column;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  padding: 12px;
  box-shadow: var(--shadow-sm);
}
.prod-thumb {
  height: 120px;
  border-radius: 10px;
  background: var(--brand-soft);
  color: var(--brand);
  display: grid;
  place-items: center;
  font-size: 34px;
  font-weight: 800;
  margin-bottom: 10px;
  overflow: hidden;
}
.prod-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.prod-body {
  flex: 1;
}
.prod-name {
  font-weight: 600;
  font-size: 14px;
  line-height: 1.25;
}
.prod-price {
  color: var(--muted);
  font-weight: 700;
  margin-top: 4px;
}
.prod-action {
  margin-top: 10px;
}
.add-btn {
  width: 100%;
  border: 1px solid var(--brand);
  background: var(--brand-soft);
  color: var(--brand);
  font-weight: 700;
  padding: 8px;
  border-radius: 9px;
  cursor: pointer;
}
.add-btn:hover {
  background: var(--brand);
  color: var(--brand-ink);
}
.stepper {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}
.stepper button {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  border: none;
  background: var(--brand);
  color: var(--brand-ink);
  font-size: 18px;
  font-weight: 700;
  cursor: pointer;
  line-height: 1;
}
.stepper span {
  font-weight: 700;
  min-width: 20px;
  text-align: center;
}
.stepper.sm button {
  width: 26px;
  height: 26px;
  font-size: 15px;
}

/* Cart */
.cat-cart {
  position: sticky;
  top: 18px;
}
.cart-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 16px;
  box-shadow: var(--shadow);
}
.cart-head {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;
}
.cart-head h3 {
  margin: 0;
  font-size: 17px;
}
.badge {
  background: var(--brand);
  color: var(--brand-ink);
  border-radius: 999px;
  padding: 1px 8px;
  font-size: 12px;
  font-weight: 700;
}
.cart-empty {
  text-align: center;
  color: var(--muted);
  padding: 20px 6px;
  font-size: 14px;
}
.cart-empty-ico {
  font-size: 30px;
  margin-bottom: 6px;
}
.cart-lines {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-bottom: 12px;
}
.cart-line {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 4px 8px;
  align-items: center;
}
.cl-name {
  font-size: 13px;
  font-weight: 600;
  grid-column: 1 / -1;
}
.cl-price {
  text-align: right;
  font-weight: 700;
  font-size: 13px;
}
.cart-total {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 0;
  border-top: 1px solid var(--border);
  font-size: 15px;
}
.checkout-btn {
  width: 100%;
  border: none;
  background: var(--brand);
  color: var(--brand-ink);
  font-weight: 700;
  padding: 12px;
  border-radius: 11px;
  cursor: pointer;
  font-size: 15px;
}
.checkout-btn:disabled {
  opacity: 0.6;
  cursor: default;
}
.link-btn {
  width: 100%;
  border: none;
  background: transparent;
  color: var(--muted);
  padding: 10px;
  margin-top: 6px;
  cursor: pointer;
}
.fl {
  display: block;
  font-size: 12px;
  color: var(--muted);
  margin: 10px 0 4px;
}
.fi {
  width: 100%;
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 10px 12px;
  background: var(--surface);
  color: var(--text);
  font: inherit;
}
.alert {
  background: var(--warning-soft);
  color: var(--warning);
  border-radius: 10px;
  padding: 9px 12px;
  font-size: 13px;
  margin-bottom: 8px;
}
.done {
  text-align: center;
  padding: 8px 4px;
}
.done-ico {
  width: 48px;
  height: 48px;
  margin: 0 auto 10px;
  border-radius: 50%;
  background: var(--success-soft);
  color: var(--success);
  display: grid;
  place-items: center;
  font-size: 24px;
  font-weight: 800;
}
.done h4 {
  margin: 0 0 6px;
}
.empty-menu {
  color: var(--muted);
  padding: 40px;
  text-align: center;
}

/* Responsive: collapse to a single column, cart drops to the bottom. */
@media (max-width: 920px) {
  .cat-shell {
    grid-template-columns: 1fr;
  }
  .cat-menu {
    position: static;
  }
  .cat-nav {
    flex-direction: row;
    flex-wrap: wrap;
  }
  .cat-cart {
    position: static;
  }
}
</style>
