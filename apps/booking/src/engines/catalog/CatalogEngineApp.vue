<script setup>
// Catalog engine (cafe / restaurant / cakes) public storefront — Yandex-Market
// style: left category rail, centre product grid, right full-height cart. Data
// comes from the site payload (categories -> items) loaded once by App.vue.
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

// ---- Scroll-spy: highlight the left category on scroll ----
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
    { rootMargin: '-10% 0px -80% 0px', threshold: 0 },
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
    <!-- LEFT: brand + categories -->
    <aside class="rail">
      <div class="brand">
        <span class="brand-logo">{{ brandInitials }}</span>
        <div class="brand-txt">
          <strong>{{ business.name }}</strong>
          <span class="muted sm">Onlayn buyurtma</span>
        </div>
      </div>
      <div class="rail-title">Katalog</div>
      <nav class="rail-nav">
        <button
          v-for="c in categories"
          :key="c.id"
          class="rail-item"
          :class="{ active: activeCat === c.id }"
          @click="scrollTo(c.id)"
        >
          <span class="rail-ico">
            <img v-if="c.image" :src="c.image" alt="" />
            <span v-else>{{ c.name.charAt(0) }}</span>
          </span>
          <span class="rail-name">{{ c.name }}</span>
        </button>
      </nav>
    </aside>

    <!-- MIDDLE: products -->
    <main class="main">
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
            </div>
            <div class="card-price">{{ soms(it.price_tiyin) }}</div>
            <div class="card-name">{{ it.name }}</div>
            <div class="card-portion">1 dona</div>
            <div class="card-foot">
              <div v-if="qtyOf(it) > 0" class="stepper">
                <button aria-label="Kamaytirish" @click="dec(it)">−</button>
                <span>{{ qtyOf(it) }}</span>
                <button aria-label="Ko‘paytirish" @click="add(it)">+</button>
              </div>
              <button v-else class="add" @click="add(it)">
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round">
                  <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
                </svg>
              </button>
            </div>
          </article>
        </div>
      </section>

      <div v-if="!categories.length" class="empty-menu">Menyu hozircha bo‘sh.</div>
    </main>

    <!-- RIGHT: full-height cart -->
    <aside class="cart">
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
          <div class="cart-scroll">
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
          <div class="cart-foot">
            <button class="next-btn" @click="goCheckout">
              <span>Rasmiylashtirish</span>
              <strong>{{ soms(cartTotal) }}</strong>
            </button>
          </div>
        </template>
      </template>

      <!-- Checkout form -->
      <template v-else-if="panel === 'checkout'">
        <div class="cart-scroll">
          <div v-if="orderError" class="alert">{{ orderError }}</div>
          <label class="fl">Ismingiz</label>
          <input v-model="cust.name" class="fi" placeholder="Ism" />
          <label class="fl">Telefon</label>
          <PhoneInput v-model="cust.phone" />
          <label class="fl">Izoh (ixtiyoriy)</label>
          <textarea v-model="note" class="fi" rows="2" placeholder="Manzil yoki izoh"></textarea>
        </div>
        <div class="cart-foot">
          <button class="next-btn" :disabled="submitting" @click="placeOrder">
            <span>{{ submitting ? 'Yuborilmoqda…' : 'Buyurtma berish' }}</span>
            <strong>{{ soms(cartTotal) }}</strong>
          </button>
          <button class="link-btn" @click="panel = 'cart'">← Savatga qaytish</button>
        </div>
      </template>

      <!-- Done -->
      <template v-else>
        <div class="cart-empty">
          <div class="done-ico">✓</div>
          <p>Buyurtma qabul qilindi!</p>
          <span>#{{ placedOrder?.id }} · {{ soms(placedOrder?.total_tiyin) }}</span>
          <button class="next-btn" style="margin-top: 18px" @click="reset"><span>Yana buyurtma</span></button>
        </div>
      </template>
    </aside>
  </div>
</template>

<style scoped>
.store {
  display: grid;
  grid-template-columns: 236px minmax(0, 1fr) 360px;
  align-items: start;
  min-height: 100vh;
  background: var(--bg);
}
.sm {
  font-size: 12px;
}
.muted {
  color: var(--muted);
}

/* LEFT rail */
.rail {
  position: sticky;
  top: 0;
  height: 100vh;
  overflow-y: auto;
  padding: 22px 14px;
  scrollbar-width: thin;
}
.brand {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 0 8px 18px;
}
.brand-logo {
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  border-radius: 13px;
  background: var(--brand);
  color: var(--brand-ink);
  display: grid;
  place-items: center;
  font-weight: 800;
}
.brand-txt {
  display: flex;
  flex-direction: column;
  line-height: 1.25;
}
.brand-txt strong {
  font-size: 15px;
}
.rail-title {
  font-size: 13px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--muted);
  padding: 0 8px 8px;
}
.rail-nav {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.rail-item {
  display: flex;
  align-items: center;
  gap: 11px;
  border: none;
  background: transparent;
  color: var(--text);
  padding: 8px;
  border-radius: 12px;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  text-align: left;
}
.rail-item:hover {
  background: var(--surface);
}
.rail-item.active {
  background: var(--brand-soft);
  color: var(--brand);
}
.rail-ico {
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  border-radius: 10px;
  overflow: hidden;
  background: var(--surface-2);
  display: grid;
  place-items: center;
  font-weight: 700;
  color: var(--brand);
}
.rail-ico img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

/* MIDDLE products */
.main {
  padding: 22px clamp(14px, 2vw, 34px) 44px;
}
.sec {
  scroll-margin-top: 14px;
  margin-bottom: 30px;
}
.sec h2 {
  font-size: 23px;
  margin: 0 0 14px;
}
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(184px, 1fr));
  gap: 14px;
}

/* Product card — dark surface, white image, bottom +/stepper */
.card {
  display: flex;
  flex-direction: column;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 18px;
  padding: 10px;
}
.card-img {
  aspect-ratio: 1 / 1;
  border-radius: 12px;
  overflow: hidden;
  background: #fff;
  margin-bottom: 10px;
}
.card-img img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.card-img .ph {
  width: 100%;
  height: 100%;
  display: grid;
  place-items: center;
  font-size: 40px;
  font-weight: 800;
  color: var(--brand);
  background: var(--brand-soft);
}
.card-price {
  font-weight: 800;
  font-size: 18px;
  padding: 0 2px;
}
.card-name {
  font-size: 14px;
  line-height: 1.3;
  padding: 3px 2px 0;
}
.card-portion {
  font-size: 12px;
  color: var(--muted);
  padding: 3px 2px 0;
}
.card-foot {
  margin-top: 10px;
}
.add {
  width: 100%;
  height: 42px;
  border: none;
  border-radius: 12px;
  background: var(--surface-2);
  color: var(--text);
  display: grid;
  place-items: center;
  cursor: pointer;
  transition: background 0.15s, color 0.15s;
}
.add:hover {
  background: var(--brand);
  color: var(--brand-ink);
}
.stepper {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 42px;
  border-radius: 12px;
  background: var(--brand);
  padding: 4px;
}
.stepper button {
  width: 34px;
  height: 34px;
  border-radius: 9px;
  border: none;
  background: rgba(255, 255, 255, 0.18);
  color: var(--brand-ink);
  font-size: 20px;
  font-weight: 700;
  line-height: 1;
  cursor: pointer;
}
.stepper button:hover {
  background: rgba(255, 255, 255, 0.3);
}
.stepper span {
  font-weight: 800;
  color: var(--brand-ink);
}

/* RIGHT cart — full height */
.cart {
  position: sticky;
  top: 0;
  height: 100vh;
  display: flex;
  flex-direction: column;
  background: var(--surface);
  border-left: 1px solid var(--border);
}
.cart-h {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px 20px 14px;
  flex-shrink: 0;
}
.cart-h h3 {
  margin: 0;
  font-size: 20px;
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
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  color: var(--muted);
  padding: 20px;
}
.cart-empty-ico {
  font-size: 46px;
  margin-bottom: 6px;
}
.cart-empty p {
  margin: 6px 0 2px;
  font-weight: 700;
  font-size: 17px;
  color: var(--text);
}
.done-ico {
  width: 58px;
  height: 58px;
  margin-bottom: 8px;
  border-radius: 50%;
  background: var(--success-soft);
  color: var(--success);
  display: grid;
  place-items: center;
  font-size: 30px;
  font-weight: 800;
}
.cart-scroll {
  flex: 1;
  overflow-y: auto;
  padding: 0 20px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.cart-line {
  display: grid;
  grid-template-columns: 48px 1fr auto;
  gap: 10px;
  align-items: center;
}
.cl-thumb {
  width: 48px;
  height: 48px;
  border-radius: 11px;
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
.cart-foot {
  flex-shrink: 0;
  padding: 14px 20px calc(18px + env(safe-area-inset-bottom));
  border-top: 1px solid var(--border);
}
.next-btn {
  width: 100%;
  border: none;
  background: var(--brand);
  color: var(--brand-ink);
  font-weight: 700;
  padding: 15px 18px;
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
  margin: 8px 0 4px;
}
.fi {
  width: 100%;
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 11px 13px;
  background: var(--bg);
  color: var(--text);
  font: inherit;
}
.alert {
  background: var(--warning-soft);
  color: var(--warning);
  border-radius: 10px;
  padding: 9px 12px;
  font-size: 13px;
}
.empty-menu {
  color: var(--muted);
  padding: 40px;
  text-align: center;
}

/* Responsive: cart drops to a full-width block below the menu */
@media (max-width: 1040px) {
  .store {
    grid-template-columns: 210px minmax(0, 1fr);
  }
  .cart {
    grid-column: 1 / -1;
    position: static;
    height: auto;
    border-left: none;
    border-top: 1px solid var(--border);
  }
  .cart-empty {
    min-height: 180px;
  }
}
@media (max-width: 720px) {
  .store {
    grid-template-columns: 1fr;
  }
  .rail {
    position: static;
    height: auto;
  }
  .rail-nav {
    flex-direction: row;
    flex-wrap: wrap;
  }
}
</style>
