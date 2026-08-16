<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { formatSom } from '../lib/money'
import { localToUtc, minutesToHhmm, todayInput } from '../lib/datetime'
import PhoneInput from './PhoneInput.vue'
import {
  Search,
  User,
  Users,
  Clock,
  Calendar,
  Plus,
  Minus,
  X,
  Check,
  Package,
  Scissors,
} from 'lucide-vue-next'

const props = defineProps({
  // { staffId, serviceId, clientId, date, time } — prefill from the clicked
  // empty slot, or from a finished appointment when rebooking the same client.
  initial: { type: Object, default: () => ({}) },
})
const emit = defineEmits(['created', 'cancel'])

/* ---------- status ---------- */
const STATUSES = [
  { v: 'pending', l: 'Kutilmoqda' },
  { v: 'arrived', l: 'Keldi' },
  { v: 'no_show', l: 'Kelmadi' },
  { v: 'confirmed', l: 'Tasdiqlandi' },
]

/* ---------- form state ---------- */
const staff = ref([])
const staffId = ref(props.initial.staffId ?? '')
const date = ref(props.initial.date || todayInput())
const time = ref(props.initial.time || '09:00')
const notes = ref('')
const status = ref('pending')

const tab = ref('services') // 'services' | 'products'

const services = ref([])
const serviceSearch = ref('')
const serviceId = ref(props.initial.serviceId ?? '')

const products = ref([])
const productSearch = ref('')
const cart = ref([]) // [{ id, name, price_tiyin, unit, qty }]

const clientMode = ref('existing') // 'existing' | 'new'
const clientSearch = ref('')
const clientResults = ref([])
const clientSearching = ref(false)
const clientId = ref(props.initial.clientId ?? '')
const selectedClient = ref(props.initial.client || null)
const recentClients = ref([])
const newClient = ref({ name: '', phone: '', email: '' })

const loadingRefs = ref(false)
const submitting = ref(false)
const error = ref('')

/* ---------- derived: chosen service ---------- */
const selectedService = computed(() => services.value.find((s) => s.id === serviceId.value) || null)
const duration = computed(() => Number(selectedService.value?.duration_min) || 0)

const endTime = computed(() => {
  if (!duration.value) return ''
  const [h, m] = String(time.value).split(':').map(Number)
  const start = (h || 0) * 60 + (m || 0)
  return minutesToHhmm((start + duration.value) % 1440)
})

const filteredServices = computed(() => {
  const q = serviceSearch.value.trim().toLowerCase()
  const active = services.value.filter((s) => s.is_active !== false)
  if (!q) return active
  return active.filter((s) => String(s.name || '').toLowerCase().includes(q))
})

/* ---------- totals ---------- */
const productsTotal = computed(() =>
  cart.value.reduce((sum, p) => sum + (Number(p.price_tiyin) || 0) * p.qty, 0),
)
const servicesTotal = computed(() => Number(selectedService.value?.price_tiyin) || 0)
const grandTotal = computed(() => servicesTotal.value + productsTotal.value)

/* ---------- validation ---------- */
const clientReady = computed(() => {
  if (clientMode.value === 'existing') return !!clientId.value
  return !!newClient.value.name.trim() && !!newClient.value.phone.trim()
})
const canSubmit = computed(
  () => !!staffId.value && !!serviceId.value && clientReady.value && !submitting.value,
)

/* ---------- loading ---------- */
async function loadRefs() {
  loadingRefs.value = true
  try {
    const [st, sv] = await Promise.all([
      api.get('/v1/staff').catch(() => []),
      api.get('/v1/services').catch(() => []),
    ])
    staff.value = Array.isArray(st) ? st : st?.items || []
    services.value = Array.isArray(sv) ? sv : sv?.items || []
    if (!staffId.value) {
      const first = staff.value.find((s) => s.is_active) || staff.value[0]
      staffId.value = first ? first.id : ''
    }
  } finally {
    loadingRefs.value = false
  }
}

let productTimer = null
async function loadProducts() {
  try {
    const q = productSearch.value.trim()
    const res = await api.get('/v1/products?search=' + encodeURIComponent(q))
    products.value = Array.isArray(res?.data) ? res.data : Array.isArray(res) ? res : res?.items || []
  } catch (_) {
    products.value = []
  }
}
function onProductSearch() {
  clearTimeout(productTimer)
  productTimer = setTimeout(loadProducts, 300)
}

// Load products lazily the first time the Tovarlar tab is opened.
const productsLoaded = ref(false)
watch(tab, (t) => {
  if (t === 'products' && !productsLoaded.value) {
    productsLoaded.value = true
    loadProducts()
  }
})

let clientTimer = null
function onClientSearch() {
  clientId.value = ''
  selectedClient.value = null
  clearTimeout(clientTimer)
  clientTimer = setTimeout(async () => {
    const q = clientSearch.value.trim()
    if (!q) {
      clientResults.value = []
      return
    }
    clientSearching.value = true
    try {
      const res = await api.get('/v1/clients?search=' + encodeURIComponent(q))
      clientResults.value = Array.isArray(res) ? res : res?.items || res?.data || []
    } catch (_) {
      clientResults.value = []
    } finally {
      clientSearching.value = false
    }
  }, 300)
}

async function loadRecentClients() {
  try {
    const res = await api.get('/v1/clients')
    const list = Array.isArray(res) ? res : res?.items || res?.data || []
    recentClients.value = list.slice(0, 6)
  } catch (_) {
    recentClients.value = []
  }
}

/* ---------- selections ---------- */
function selectService(s) {
  serviceId.value = serviceId.value === s.id ? '' : s.id
}

function addProduct(p) {
  const existing = cart.value.find((c) => c.id === p.id)
  if (existing) {
    existing.qty += 1
    return
  }
  cart.value.push({
    id: p.id,
    name: p.name,
    price_tiyin: p.price_tiyin,
    unit: p.unit,
    qty: 1,
  })
}
function inCart(id) {
  return cart.value.some((c) => c.id === id)
}
function incQty(item) {
  item.qty += 1
}
function decQty(item) {
  item.qty -= 1
  if (item.qty <= 0) removeProduct(item)
}
function removeProduct(item) {
  cart.value = cart.value.filter((c) => c.id !== item.id)
}

function pickClient(c) {
  clientId.value = c.id
  selectedClient.value = c
  clientSearch.value = ''
  clientResults.value = []
}
function clearClient() {
  clientId.value = ''
  selectedClient.value = null
}

/* ---------- submit ---------- */
async function submit() {
  error.value = ''
  if (!canSubmit.value) return
  submitting.value = true
  try {
    const payload = {
      staff_id: staffId.value,
      service_id: serviceId.value,
      starts_at: localToUtc(date.value, time.value),
      status: status.value,
      notes: notes.value.trim() || undefined,
    }
    if (clientMode.value === 'existing') {
      payload.client_id = clientId.value
    } else {
      payload.client = {
        name: newClient.value.name.trim(),
        phone: newClient.value.phone.trim(),
        email: newClient.value.email.trim() || undefined,
      }
    }
    if (cart.value.length) {
      payload.products = cart.value.map((c) => ({ id: c.id, qty: c.qty }))
    }
    await api.post('/v1/appointments', payload)
    emit('created')
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : "Yozuvni yaratib bo'lmadi"
  } finally {
    submitting.value = false
  }
}

onMounted(() => {
  loadRefs()
  loadRecentClients()
})
</script>

<template>
  <div class="af">
    <div v-if="error" class="alert alert-error af-error">{{ error }}</div>

    <div class="af-grid">
      <!-- LEFT: appointment basics -->
      <section class="af-col af-left">
        <div class="field">
          <label><Users :size="14" /> Xodim</label>
          <select v-model="staffId" :disabled="loadingRefs">
            <option value="" disabled>Tanlang…</option>
            <option v-for="s in staff" :key="s.id" :value="s.id">
              {{ s.name }}<template v-if="s.specialization"> · {{ s.specialization }}</template>
            </option>
          </select>
        </div>

        <div class="field">
          <label><Calendar :size="14" /> Sana</label>
          <input v-model="date" type="date" />
        </div>

        <div class="field-row">
          <div class="field">
            <label><Clock :size="14" /> Vaqt</label>
            <input v-model="time" type="time" />
          </div>
          <div class="field">
            <label>Davomiylik</label>
            <div class="af-readonly">
              <template v-if="duration">
                {{ duration }} daq
                <span v-if="endTime" class="muted"> · {{ endTime }} gacha</span>
              </template>
              <span v-else class="muted">Xizmat tanlang</span>
            </div>
          </div>
        </div>

        <div class="field mb-0">
          <label>Izoh</label>
          <textarea v-model="notes" rows="3" placeholder="Qo'shimcha ma'lumot…"></textarea>
        </div>
      </section>

      <!-- MIDDLE: status + services/products -->
      <section class="af-col af-middle">
        <div class="field">
          <label>Holat</label>
          <div class="segs af-status">
            <button
              v-for="s in STATUSES"
              :key="s.v"
              type="button"
              class="seg"
              :class="{ active: status === s.v }"
              @click="status = s.v"
            >
              {{ s.l }}
            </button>
          </div>
        </div>

        <div class="af-tabs">
          <button
            type="button"
            class="af-tab"
            :class="{ active: tab === 'services' }"
            @click="tab = 'services'"
          >
            <Scissors :size="15" /> Xizmatlar
          </button>
          <button
            type="button"
            class="af-tab"
            :class="{ active: tab === 'products' }"
            @click="tab = 'products'"
          >
            <Package :size="15" /> Tovarlar
          </button>
        </div>

        <!-- Services tab -->
        <div v-show="tab === 'services'">
          <div class="af-search">
            <Search :size="15" class="af-search-ic" />
            <input v-model="serviceSearch" placeholder="Xizmat qidirish…" />
          </div>
          <div v-if="loadingRefs" class="af-hint"><span class="spinner"></span> Yuklanmoqda…</div>
          <div v-else-if="!filteredServices.length" class="af-empty">Xizmat topilmadi.</div>
          <div v-else class="af-cards">
            <button
              v-for="s in filteredServices"
              :key="s.id"
              type="button"
              class="af-card"
              :class="{ selected: serviceId === s.id }"
              @click="selectService(s)"
            >
              <Check v-if="serviceId === s.id" :size="16" class="af-card-check" />
              <span class="af-card-name">{{ s.name }}</span>
              <span class="af-card-meta">
                <strong>{{ formatSom(s.price_tiyin) }}</strong>
                <span class="muted">{{ s.duration_min }} daq</span>
              </span>
            </button>
          </div>
        </div>

        <!-- Products tab -->
        <div v-show="tab === 'products'">
          <div class="af-search">
            <Search :size="15" class="af-search-ic" />
            <input v-model="productSearch" placeholder="Tovar qidirish…" @input="onProductSearch" />
          </div>
          <div v-if="!products.length" class="af-empty">Tovar topilmadi.</div>
          <div v-else class="af-cards">
            <button
              v-for="p in products"
              :key="p.id"
              type="button"
              class="af-card"
              :class="{ selected: inCart(p.id) }"
              @click="addProduct(p)"
            >
              <Plus v-if="!inCart(p.id)" :size="15" class="af-card-check" />
              <Check v-else :size="16" class="af-card-check" />
              <span class="af-card-name">{{ p.name }}</span>
              <span class="af-card-meta">
                <strong>{{ formatSom(p.price_tiyin) }}</strong>
                <span class="muted">Zaxira: {{ p.stock_qty }}{{ p.unit ? ' ' + p.unit : '' }}</span>
              </span>
            </button>
          </div>

          <!-- Cart -->
          <div v-if="cart.length" class="af-cart">
            <div v-for="item in cart" :key="item.id" class="af-cart-row">
              <span class="af-cart-name">{{ item.name }}</span>
              <div class="af-stepper">
                <button type="button" @click="decQty(item)" aria-label="Kamaytirish">
                  <Minus :size="13" />
                </button>
                <span>{{ item.qty }}</span>
                <button type="button" @click="incQty(item)" aria-label="Ko'paytirish">
                  <Plus :size="13" />
                </button>
              </div>
              <span class="af-cart-price">{{ formatSom(item.price_tiyin * item.qty) }}</span>
              <button
                type="button"
                class="af-cart-x"
                aria-label="O'chirish"
                @click="removeProduct(item)"
              >
                <X :size="14" />
              </button>
            </div>
          </div>
        </div>

        <div class="af-total">
          <span>Jami</span>
          <strong>{{ formatSom(grandTotal) }}</strong>
        </div>
      </section>

      <!-- RIGHT: client -->
      <section class="af-col af-right">
        <div class="af-tabs af-client-tabs">
          <button
            type="button"
            class="af-tab"
            :class="{ active: clientMode === 'existing' }"
            @click="clientMode = 'existing'"
          >
            <User :size="15" /> Mavjud
          </button>
          <button
            type="button"
            class="af-tab"
            :class="{ active: clientMode === 'new' }"
            @click="clientMode = 'new'"
          >
            <Plus :size="15" /> Yangi mijoz
          </button>
        </div>

        <!-- Existing client -->
        <template v-if="clientMode === 'existing'">
          <div v-if="selectedClient" class="af-picked">
            <div>
              <strong>{{ selectedClient.name }}</strong>
              <div class="muted">{{ selectedClient.phone }}</div>
            </div>
            <button type="button" class="af-cart-x" aria-label="Bekor" @click="clearClient">
              <X :size="15" />
            </button>
          </div>

          <template v-else>
            <div class="af-search">
              <Search :size="15" class="af-search-ic" />
              <input
                v-model="clientSearch"
                placeholder="Ism yoki telefon…"
                @input="onClientSearch"
              />
            </div>

            <div v-if="clientSearching" class="af-hint"><span class="spinner"></span></div>
            <ul v-else-if="clientResults.length" class="af-cli-list">
              <li v-for="c in clientResults" :key="c.id" @click="pickClient(c)">
                <strong>{{ c.name }}</strong>
                <span class="muted">{{ c.phone }}</span>
              </li>
            </ul>
            <div v-else-if="clientSearch.trim()" class="af-empty">Mijoz topilmadi.</div>

            <template v-if="!clientSearch.trim() && recentClients.length">
              <div class="af-recent-label">Oxirgi mijozlar</div>
              <div class="af-chips">
                <button
                  v-for="c in recentClients"
                  :key="c.id"
                  type="button"
                  class="af-chip"
                  @click="pickClient(c)"
                >
                  {{ c.name }}
                </button>
              </div>
            </template>
          </template>
        </template>

        <!-- New client -->
        <template v-else>
          <div class="field">
            <label>Ism</label>
            <input v-model="newClient.name" placeholder="Sardor Aliyev" />
          </div>
          <div class="field">
            <label>Telefon</label>
            <PhoneInput v-model="newClient.phone" />
          </div>
          <div class="field mb-0">
            <label>Email (ixtiyoriy)</label>
            <input v-model="newClient.email" type="email" placeholder="mijoz@mail.uz" />
          </div>
        </template>
      </section>
    </div>

    <!-- FOOTER -->
    <div class="af-foot">
      <button type="button" class="btn" @click="emit('cancel')">Bekor</button>
      <button type="button" class="btn btn-primary" :disabled="!canSubmit" @click="submit">
        {{ submitting ? 'Saqlanmoqda…' : 'Yozuv yaratish' }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.af-error {
  margin-bottom: 14px;
}

.af-grid {
  display: grid;
  grid-template-columns: 1fr 1.2fr 1fr;
  gap: 20px;
}
.af-col {
  min-width: 0;
}
.af-middle {
  border-left: 1px solid var(--border);
  border-right: 1px solid var(--border);
  padding: 0 20px;
}

/* labels with icons */
.field label {
  display: inline-flex;
  align-items: center;
  gap: 5px;
}

.af-readonly {
  height: 38px;
  display: flex;
  align-items: center;
  padding: 0 12px;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--surface-2);
  font-size: 13.5px;
  color: var(--text);
}

/* status segmented control */
.segs {
  display: flex;
  gap: 4px;
  background: var(--surface-2);
  border: 1px solid var(--border);
  border-radius: 9px;
  padding: 3px;
}
.af-status {
  flex-wrap: wrap;
}
.seg {
  flex: 1;
  font: inherit;
  font-weight: 600;
  font-size: 12.5px;
  cursor: pointer;
  border: none;
  background: transparent;
  color: var(--text-muted);
  padding: 6px 8px;
  border-radius: 7px;
  transition: background 0.15s, color 0.15s;
  white-space: nowrap;
}
.seg:hover {
  color: var(--text);
}
.seg.active {
  background: var(--surface);
  color: var(--primary);
  box-shadow: var(--shadow);
}

/* tabs */
.af-tabs {
  display: flex;
  gap: 6px;
  margin-bottom: 12px;
}
.af-client-tabs {
  margin-top: 2px;
}
.af-tab {
  flex: 1;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  font: inherit;
  font-weight: 600;
  font-size: 13px;
  cursor: pointer;
  padding: 8px 10px;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--surface);
  color: var(--text-muted);
  transition: all 0.15s;
}
.af-tab:hover {
  color: var(--text);
}
.af-tab.active {
  background: var(--primary-soft);
  color: var(--primary);
  border-color: var(--primary);
}

/* search box */
.af-search {
  position: relative;
  margin-bottom: 10px;
}
.af-search-ic {
  position: absolute;
  left: 10px;
  top: 50%;
  transform: translateY(-50%);
  color: var(--text-muted);
  pointer-events: none;
}
.af-search input {
  padding-left: 32px;
}

/* cards grid */
.af-cards {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 8px;
  max-height: 260px;
  overflow-y: auto;
  padding: 2px;
}
.af-card {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 6px;
  text-align: left;
  font: inherit;
  cursor: pointer;
  padding: 10px 12px;
  border: 1px solid var(--border);
  border-radius: 9px;
  background: var(--surface);
  color: var(--text);
  transition: border-color 0.15s, background 0.15s;
}
.af-card:hover {
  border-color: var(--primary);
}
.af-card.selected {
  border-color: var(--primary);
  background: var(--primary-soft);
}
.af-card-check {
  position: absolute;
  top: 8px;
  right: 8px;
  color: var(--primary);
}
.af-card-name {
  font-weight: 600;
  font-size: 13px;
  line-height: 1.25;
  padding-right: 18px;
}
.af-card-meta {
  display: flex;
  flex-direction: column;
  gap: 1px;
  font-size: 12px;
}
.af-card-meta strong {
  font-size: 12.5px;
}

/* cart */
.af-cart {
  margin-top: 12px;
  border: 1px solid var(--border);
  border-radius: 9px;
  overflow: hidden;
}
.af-cart-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  border-bottom: 1px solid var(--border);
}
.af-cart-row:last-child {
  border-bottom: none;
}
.af-cart-name {
  flex: 1;
  min-width: 0;
  font-size: 13px;
  font-weight: 550;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.af-stepper {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}
.af-stepper button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  border: 1px solid var(--border);
  border-radius: 6px;
  background: var(--surface-2);
  color: var(--text);
  cursor: pointer;
}
.af-stepper button:hover {
  border-color: var(--primary);
  color: var(--primary);
}
.af-stepper span {
  min-width: 18px;
  text-align: center;
  font-weight: 600;
  font-size: 13px;
  font-variant-numeric: tabular-nums;
}
.af-cart-price {
  font-size: 12.5px;
  font-weight: 600;
  white-space: nowrap;
}
.af-cart-x {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: none;
  background: transparent;
  color: var(--text-muted);
  cursor: pointer;
  padding: 2px;
  border-radius: 6px;
}
.af-cart-x:hover {
  color: var(--danger);
  background: var(--danger-soft);
}

/* total */
.af-total {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid var(--border);
  font-size: 14px;
}
.af-total strong {
  font-size: 16px;
  color: var(--primary);
}

/* client list */
.af-cli-list {
  list-style: none;
  margin: 0;
  padding: 0;
  border: 1px solid var(--border);
  border-radius: 9px;
  overflow: hidden;
  max-height: 240px;
  overflow-y: auto;
}
.af-cli-list li {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 9px 12px;
  cursor: pointer;
  border-bottom: 1px solid var(--border);
}
.af-cli-list li:last-child {
  border-bottom: none;
}
.af-cli-list li:hover {
  background: var(--surface-2);
}

.af-picked {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  padding: 12px 14px;
  border: 1px solid var(--primary);
  background: var(--primary-soft);
  border-radius: 9px;
}

.af-recent-label {
  margin: 14px 0 8px;
  font-size: 12px;
  font-weight: 600;
  color: var(--text-muted);
}
.af-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.af-chip {
  font: inherit;
  font-size: 12.5px;
  font-weight: 550;
  cursor: pointer;
  padding: 6px 12px;
  border: 1px solid var(--border);
  border-radius: 20px;
  background: var(--surface);
  color: var(--text);
  transition: all 0.15s;
}
.af-chip:hover {
  border-color: var(--primary);
  color: var(--primary);
}

.af-hint {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 4px;
  font-size: 13px;
  color: var(--text-muted);
}
.af-empty {
  padding: 14px 4px;
  font-size: 13px;
  color: var(--text-muted);
}

/* footer */
.af-foot {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 20px;
  padding-top: 16px;
  border-top: 1px solid var(--border);
}

/* responsive: stack columns */
@media (max-width: 880px) {
  .af-grid {
    grid-template-columns: 1fr;
    gap: 22px;
  }
  .af-middle {
    border: none;
    padding: 0;
    border-top: 1px solid var(--border);
    border-bottom: 1px solid var(--border);
    padding: 20px 0;
  }
}
</style>
