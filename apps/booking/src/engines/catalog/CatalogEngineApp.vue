<script setup>
// Catalog engine (cafe / restaurant / cakes) public storefront — Yandex-Eda
// style: sticky horizontal category tabs, image-first product cards with an
// overlaid +/stepper, and a sticky cart with a total-bearing checkout button.
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
function clearCart() {
  for (const k of Object.keys(cart)) delete cart[k]
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
    clearCart()
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

// ---- Scroll-spy for the category tabs ----
const activeCat = ref(null)
const sections = {}
const tabEls = {}
function setSection(id, el) {
  if (el) sections[id] = el
}
function setTab(id, el) {
  if (el) tabEls[id] = el
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
        if (e.isIntersecting) {
          const id = Number(e.target.dataset.cat)
          activeCat.value = id
          tabEls[id]?.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' })
        }
      }
    },
    { rootMargin: '-12% 0px -80% 0px', threshold: 0 },
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
  <div class="store">
    <div class="store-grid">
      <!-- Menu -->
      <main class="store-main">
        <!-- Sticky category tabs -->
        <nav class="tabs">
          <button
            v-for="c in categories"
            :key="c.id"
            :ref="(el) => setTab(c.id, el)"
            class="tab"
            :class="{ active: activeCat === c.id }"
            @click="scrollTo(c.id)"
          >
            {{ c.name }}
          </button>
        </nav>

        <!-- Hero -->
        <div class="hero">
          <span class="hero-logo">{{ brandInitials }}</span>
          <div class="hero-txt">
            <h1>{{ business.name }}</h1>
            <p>Onlayn buyurtma · tez va qulay</p>
          </div>
        </div>

        <!-- Sections -->
        <section
          v-for="c in categories"
          :key="c.id"
          :ref="(el) => setSection(c.id, el)"
          :data-cat="c.id"
          class="sec"
        >
          <h2>{{ c.name }}</h2>
          <div class="grid">
            <article v-for="it in c.items" :key="it.id" class="card">
              <div class="card-img">
                <img v-if="it.image" :src="it.image" :alt="it.name" />
                <span v-else class="ph">{{ it.name.charAt(0) }}</span>
                <div class="add-wrap">
                  <div v-if="qtyOf(it) > 0" class="stepper">
                    <button aria-label="Kamaytirish" @click="dec(it)">−</button>
                    <span>{{ qtyOf(it) }}</span>
                    <button aria-label="Ko‘paytirish" @click="add(it)">+</button>
                  </div>
                  <button v-else class="add" aria-label="Qo‘shish" @click="add(it)">+</button>
                </div>
              </div>
              <div class="card-price">{{ soms(it.price_tiyin) }}</div>
              <div class="card-name">{{ it.name }}</div>
              <div class="card-portion">1 dona</div>
            </article>
          </div>
        </section>

        <div v-if="!categories.length" class="empty-menu">Menyu hozircha bo‘sh.</div>
      </main>

      <!-- Cart -->
      <aside class="cart">
        <div class="cart-box">
          <div class="cart-h">
            <h3>Savat<span v-if="cartCount" class="badge">{{ cartCount }}</span></h3>
            <button v-if="cartLines.length && panel === 'cart'" class="clear" @click="clearCart">Tozalash</button>
          </div>

          <!-- Cart list -->
          <template v-if="panel === 'cart'">
            <div v-if="!cartLines.length" class="cart-empty">
              <div class="cart-empty-ico">🛍️</div>
              <p>Savat bo‘sh</p>
              <span>Menyudan tanlang</span>
            </div>
            <template v-else>
              <div class="cart-lines">
                <div v-for="l in cartLines" :key="l.item.id" class="cart-line">
                  <div class="cl-thumb">
                    <img v-if="l.item.image" :src="l.item.image" :alt="l.item.name" />
                    <span v-else>{{ l.item.name.charAt(0) }}</span>
                  </div>
                  <div class="cl-main">
                    <div class="cl-name">{{ l.item.name }}</div>
                    <div class="cl-price">{{ soms(l.item.price_tiyin * l.qty) }}</div>
                  </div>
                  <div class="stepper sm">
                    <button @click="dec(l.item)">−</button>
                    <span>{{ l.qty }}</span>
                    <button @click="add(l.item)">+</button>
                  </div>
                </div>
              </div>
              <button class="next-btn" @click="goCheckout">
                <span>Rasmiylashtirish</span>
                <strong>{{ soms(cartTotal) }}</strong>
              </button>
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
            <button class="next-btn" :disabled="submitting" @click="placeOrder">
              <span>{{ submitting ? 'Yuborilmoqda…' : 'Buyurtma berish' }}</span>
              <strong>{{ soms(cartTotal) }}</strong>
            </button>
            <button class="link-btn" @click="panel = 'cart'">← Savatga qaytish</button>
          </template>

          <!-- Done -->
          <template v-else>
            <div class="done">
              <div class="done-ico">✓</div>
              <h4>Buyurtma qabul qilindi!</h4>
              <p class="muted">Buyurtma #{{ placedOrder?.id }} · {{ soms(placedOrder?.total_tiyin) }}</p>
              <p class="muted sm">Tez orada siz bilan bog‘lanamiz.</p>
              <button class="next-btn" @click="reset"><span>Yana buyurtma</span></button>
            </div>
          </template>
        </div>
      </aside>
    </div>
  </div>
</template>

<style scoped>
.store {
  min-height: 100vh;
  background: var(--bg);
}
.store-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 340px;
  gap: 22px;
  max-width: 1180px;
  margin: 0 auto;
  padding: 0 18px 40px;
  align-items: start;
}
.sm {
  font-size: 12px;
}
.muted {
  color: var(--muted);
}

/* Sticky category tabs */
.tabs {
  position: sticky;
  top: 0;
  z-index: 5;
  display: flex;
  gap: 6px;
  overflow-x: auto;
  padding: 14px 0;
  background: var(--bg);
  scrollbar-width: none;
}
.tabs::-webkit-scrollbar {
  display: none;
}
.tab {
  white-space: nowrap;
  border: none;
  background: transparent;
  color: var(--muted);
  padding: 9px 15px;
  border-radius: 11px;
  font-weight: 600;
  font-size: 15px;
  cursor: pointer;
  transition: background 0.15s, color 0.15s;
}
.tab:hover {
  color: var(--text);
  background: var(--surface-2);
}
.tab.active {
  color: var(--brand-ink);
  background: var(--brand);
}

/* Hero */
.hero {
  display: flex;
  align-items: center;
  gap: 16px;
  border-radius: var(--radius);
  background: linear-gradient(120deg, var(--brand), var(--brand-2));
  color: var(--brand-ink);
  padding: 22px 24px;
  margin-bottom: 22px;
  box-shadow: var(--shadow-brand);
}
.hero-logo {
  width: 54px;
  height: 54px;
  flex: 0 0 54px;
  border-radius: 15px;
  background: rgba(255, 255, 255, 0.2);
  display: grid;
  place-items: center;
  font-weight: 800;
  font-size: 20px;
}
.hero-txt h1 {
  margin: 0 0 2px;
  font-size: 26px;
}
.hero-txt p {
  margin: 0;
  opacity: 0.9;
  font-size: 14px;
}

/* Sections */
.sec {
  scroll-margin-top: 64px;
  margin-bottom: 30px;
}
.sec h2 {
  font-size: 22px;
  margin: 0 0 14px;
}
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(196px, 1fr));
  gap: 16px 14px;
}

/* Product card — image first, +/stepper overlaid */
.card {
  display: flex;
  flex-direction: column;
}
.card-img {
  position: relative;
  aspect-ratio: 1 / 1;
  border-radius: 16px;
  overflow: hidden;
  background: #fff;
}
.card-img img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.card-img .ph {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  font-size: 44px;
  font-weight: 800;
  color: var(--brand);
  background: var(--brand-soft);
}
.add-wrap {
  position: absolute;
  right: 10px;
  bottom: 10px;
}
.add {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  border: none;
  background: #fff;
  color: #111;
  font-size: 24px;
  font-weight: 500;
  line-height: 1;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.18);
  display: grid;
  place-items: center;
}
.add:hover {
  background: var(--brand);
  color: var(--brand-ink);
}
.stepper {
  display: flex;
  align-items: center;
  gap: 6px;
  background: #fff;
  border-radius: 999px;
  padding: 4px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.18);
}
.stepper button {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: none;
  background: var(--brand);
  color: var(--brand-ink);
  font-size: 18px;
  font-weight: 700;
  line-height: 1;
  cursor: pointer;
}
.stepper span {
  min-width: 20px;
  text-align: center;
  font-weight: 800;
  color: #111;
}
.card-price {
  font-weight: 800;
  font-size: 17px;
  margin-top: 10px;
}
.card-name {
  font-size: 14px;
  line-height: 1.3;
  margin-top: 3px;
}
.card-portion {
  font-size: 12px;
  color: var(--muted);
  margin-top: 3px;
}

/* Cart */
.cart {
  position: sticky;
  top: 14px;
}
.cart-box {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 18px;
  box-shadow: var(--shadow);
}
.cart-h {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
}
.cart-h h3 {
  margin: 0;
  font-size: 19px;
  display: flex;
  align-items: center;
  gap: 8px;
}
.badge {
  background: var(--brand);
  color: var(--brand-ink);
  border-radius: 999px;
  padding: 1px 9px;
  font-size: 12px;
  font-weight: 700;
}
.clear {
  border: none;
  background: transparent;
  color: var(--muted);
  cursor: pointer;
  font-size: 13px;
}
.clear:hover {
  color: var(--danger);
}
.cart-empty {
  text-align: center;
  color: var(--muted);
  padding: 26px 6px;
}
.cart-empty-ico {
  font-size: 34px;
}
.cart-empty p {
  margin: 8px 0 2px;
  font-weight: 600;
  color: var(--text);
}
.cart-empty span {
  font-size: 13px;
}
.cart-lines {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-bottom: 14px;
}
.cart-line {
  display: grid;
  grid-template-columns: 44px 1fr auto;
  gap: 10px;
  align-items: center;
}
.cl-thumb {
  width: 44px;
  height: 44px;
  border-radius: 10px;
  overflow: hidden;
  background: #fff;
  display: grid;
  place-items: center;
  font-weight: 700;
  color: var(--brand);
}
.cl-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.cl-name {
  font-size: 13px;
  font-weight: 600;
  line-height: 1.2;
}
.cl-price {
  font-size: 12px;
  color: var(--muted);
  margin-top: 2px;
}
.next-btn {
  width: 100%;
  border: none;
  background: var(--brand);
  color: var(--brand-ink);
  font-weight: 700;
  padding: 14px 16px;
  border-radius: 14px;
  cursor: pointer;
  font-size: 15px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}
.next-btn:disabled {
  opacity: 0.6;
  cursor: default;
}
.link-btn {
  width: 100%;
  border: none;
  background: transparent;
  color: var(--muted);
  padding: 12px;
  margin-top: 4px;
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
  border-radius: 12px;
  padding: 11px 13px;
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
  margin-bottom: 10px;
}
.done {
  text-align: center;
  padding: 8px 4px;
}
.done-ico {
  width: 50px;
  height: 50px;
  margin: 0 auto 10px;
  border-radius: 50%;
  background: var(--success-soft);
  color: var(--success);
  display: grid;
  place-items: center;
  font-size: 26px;
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

/* Responsive: cart drops below the menu */
@media (max-width: 900px) {
  .store-grid {
    grid-template-columns: 1fr;
  }
  .cart {
    position: static;
    order: -1;
  }
}
</style>
