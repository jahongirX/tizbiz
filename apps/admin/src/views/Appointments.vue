<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { api, ApiError } from '@tizbiz/api-client'
import {
  todayInput,
  addDays,
  localDayStartUtc,
  localDayEndUtc,
  formatDateTime,
  formatLocalTime,
} from '../lib/datetime'
import Modal from '../components/Modal.vue'
import PhoneInput from '../components/PhoneInput.vue'

const STATUSES = [
  { v: 'pending', l: 'Kutilmoqda' },
  { v: 'confirmed', l: 'Tasdiqlangan' },
  { v: 'arrived', l: 'Keldi' },
  { v: 'completed', l: 'Yakunlandi' },
  { v: 'no_show', l: 'Kelmadi' },
  { v: 'canceled', l: 'Bekor qilindi' },
]
const statusLabel = Object.fromEntries(STATUSES.map((s) => [s.v, s.l]))

const loading = ref(true)
const error = ref('')
const appointments = ref([])
const staff = ref([])
const services = ref([])

// Filters live in the URL: a refresh (or a shared link) keeps the view the user
// set up, instead of snapping back to "today + 7 days, everyone".
const route = useRoute()
const router = useRouter()

const filters = ref({
  from: String(route.query.from || todayInput()),
  to: String(route.query.to || addDays(todayInput(), 7)),
  staff: String(route.query.staff || ''),
  status: String(route.query.status || ''),
})

function syncUrl() {
  const q = {}
  for (const [key, value] of Object.entries(filters.value)) {
    if (value) q[key] = String(value)
  }
  // replace, not push: the back button should leave the page, not walk through
  // every filter the user tried.
  router.replace({ query: q })
}

const sorted = computed(() =>
  [...appointments.value].sort((a, b) =>
    (a.starts_at || '').localeCompare(b.starts_at || ''),
  ),
)

async function loadRefs() {
  try {
    const [st, sv] = await Promise.all([api.get('/v1/staff'), api.get('/v1/services')])
    staff.value = Array.isArray(st) ? st : st?.items || []
    services.value = Array.isArray(sv) ? sv : sv?.items || []
  } catch (_) {
    /* refs are non-fatal */
  }
}

async function load() {
  syncUrl()
  loading.value = true
  error.value = ''
  try {
    const params = new URLSearchParams()
    params.set('from', localDayStartUtc(filters.value.from))
    params.set('to', localDayEndUtc(filters.value.to))
    if (filters.value.staff) params.set('staff', filters.value.staff)
    if (filters.value.status) params.set('status', filters.value.status)
    const res = await api.get('/v1/appointments?' + params.toString())
    appointments.value = Array.isArray(res) ? res : res?.items || []
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Yuklab bo\'lmadi'
  } finally {
    loading.value = false
  }
}

async function changeStatus(a, status) {
  if (a.status === status) return
  const prev = a.status
  a.status = status
  try {
    await api.patch('/v1/appointments/' + a.id, { status })
  } catch (e) {
    a.status = prev
    error.value = e instanceof ApiError ? e.message : 'Holatni o\'zgartirib bo\'lmadi'
  }
}

/* ---------- New appointment modal ---------- */
const showNew = ref(false)
const nb = ref(newBooking())
const slots = ref([])
const slotsLoading = ref(false)
const slotsError = ref('')
const clientResults = ref([])
const bookingError = ref('')
const booking = ref(false)

function newBooking() {
  return {
    staff_id: '',
    service_id: '',
    date: todayInput(),
    slot: null,
    clientMode: 'new', // 'new' | 'existing'
    clientSearch: '',
    client_id: '',
    clientName: '',
    clientPhone: '',
  }
}

function openNew() {
  nb.value = newBooking()
  if (staff.value[0]) nb.value.staff_id = staff.value[0].id
  slots.value = []
  clientResults.value = []
  bookingError.value = ''
  slotsError.value = ''
  showNew.value = true
}

async function fetchSlots() {
  nb.value.slot = null
  slots.value = []
  slotsError.value = ''
  if (!nb.value.staff_id || !nb.value.service_id || !nb.value.date) return
  slotsLoading.value = true
  try {
    const res = await api.get(
      `/v1/staff/${nb.value.staff_id}/availability?date=${nb.value.date}&service_id=${nb.value.service_id}`,
    )
    slots.value = res?.slots || (Array.isArray(res) ? res : [])
    if (!slots.value.length) slotsError.value = 'Bu kun uchun bo\'sh vaqt yo\'q.'
  } catch (e) {
    slotsError.value = e instanceof ApiError ? e.message : 'Vaqtlarni yuklab bo\'lmadi'
  } finally {
    slotsLoading.value = false
  }
}

let clientTimer = null
function searchClients() {
  clearTimeout(clientTimer)
  clientTimer = setTimeout(async () => {
    const q = nb.value.clientSearch.trim()
    if (!q) {
      clientResults.value = []
      return
    }
    try {
      const res = await api.get('/v1/clients?search=' + encodeURIComponent(q))
      clientResults.value = Array.isArray(res) ? res : res?.items || []
    } catch (_) {
      clientResults.value = []
    }
  }, 300)
}

function pickClient(c) {
  nb.value.client_id = c.id
  nb.value.clientSearch = `${c.name} · ${c.phone || ''}`
  clientResults.value = []
}

async function submitBooking() {
  bookingError.value = ''
  if (!nb.value.slot) {
    bookingError.value = 'Vaqtni tanlang.'
    return
  }
  const payload = {
    staff_id: nb.value.staff_id,
    service_id: nb.value.service_id,
    starts_at: nb.value.slot.start_utc,
  }
  if (nb.value.clientMode === 'existing') {
    if (!nb.value.client_id) {
      bookingError.value = 'Mijozni tanlang.'
      return
    }
    payload.client_id = nb.value.client_id
  } else {
    if (!nb.value.clientName.trim() || !nb.value.clientPhone.trim()) {
      bookingError.value = 'Mijoz ismi va telefonini kiriting.'
      return
    }
    payload.client = { name: nb.value.clientName.trim(), phone: nb.value.clientPhone.trim() }
  }
  booking.value = true
  try {
    await api.post('/v1/appointments', payload)
    showNew.value = false
    await load()
  } catch (e) {
    bookingError.value = e instanceof ApiError ? e.message : 'Yozuvni yaratib bo\'lmadi'
  } finally {
    booking.value = false
  }
}

onMounted(async () => {
  await loadRefs()
  await load()
})
</script>

<template>
  <div>
    <div class="page-head">
      <h1>Yozuvlar</h1>
      <button class="btn btn-primary" @click="openNew">+ Yangi yozuv</button>
    </div>

    <div class="card filters">
      <div class="field">
        <label>Dan</label>
        <input v-model="filters.from" type="date" />
      </div>
      <div class="field">
        <label>Gacha</label>
        <input v-model="filters.to" type="date" />
      </div>
      <div class="field">
        <label>Xodim</label>
        <select v-model="filters.staff">
          <option value="">Barchasi</option>
          <option v-for="s in staff" :key="s.id" :value="s.id">{{ s.name }}</option>
        </select>
      </div>
      <div class="field">
        <label>Holat</label>
        <select v-model="filters.status">
          <option value="">Barchasi</option>
          <option v-for="s in STATUSES" :key="s.v" :value="s.v">{{ s.l }}</option>
        </select>
      </div>
      <div class="field" style="flex: 0">
        <label>&nbsp;</label>
        <button class="btn btn-primary" @click="load">Ko'rsatish</button>
      </div>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>
    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

    <template v-else>
      <div v-if="!sorted.length" class="empty card">Tanlangan davr uchun yozuvlar yo'q.</div>
      <div v-else class="table-wrap">
        <table class="data cards">
          <thead>
            <tr>
              <th>Vaqt</th>
              <th>Mijoz</th>
              <th>Xizmat</th>
              <th>Xodim</th>
              <th>Holat</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="a in sorted" :key="a.id">
              <td>{{ formatDateTime(a.starts_at) }}</td>
              <td>
                <strong>{{ a.client?.name || a.client_name || '—' }}</strong>
                <div class="muted" style="font-size: 12px">{{ a.client?.phone || a.client_phone || '' }}</div>
              </td>
              <td data-label="Xizmat">{{ (a.service_names || []).join(' + ') || a.service?.name || a.service_name || '—' }}</td>
              <td data-label="Xodim">{{ a.staff?.name || a.staff_name || '—' }}</td>
              <td data-label="Holat">
                <select
                  class="status-select"
                  :class="a.status"
                  :value="a.status"
                  @change="changeStatus(a, $event.target.value)"
                >
                  <option v-for="s in STATUSES" :key="s.v" :value="s.v">{{ s.l }}</option>
                </select>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>

    <!-- New appointment -->
    <Modal v-if="showNew" title="Yangi yozuv" wide @close="showNew = false">
      <div v-if="bookingError" class="alert alert-error">{{ bookingError }}</div>

      <div class="field-row">
        <div class="field">
          <label>Xodim</label>
          <select v-model="nb.staff_id" @change="fetchSlots">
            <option value="" disabled>Tanlang…</option>
            <option v-for="s in staff" :key="s.id" :value="s.id">{{ s.name }}</option>
          </select>
        </div>
        <div class="field">
          <label>Xizmat</label>
          <select v-model="nb.service_id" @change="fetchSlots">
            <option value="" disabled>Tanlang…</option>
            <option v-for="s in services" :key="s.id" :value="s.id">{{ s.name }}</option>
          </select>
        </div>
        <div class="field">
          <label>Sana</label>
          <input v-model="nb.date" type="date" @change="fetchSlots" />
        </div>
      </div>

      <div class="field">
        <label>Bo'sh vaqtlar</label>
        <div v-if="slotsLoading" class="loading-block" style="padding: 14px">
          <span class="spinner"></span>
        </div>
        <div v-else-if="slotsError" class="muted" style="font-size: 13px">{{ slotsError }}</div>
        <div v-else-if="!nb.service_id || !nb.staff_id" class="muted" style="font-size: 13px">
          Xodim va xizmatni tanlang.
        </div>
        <div v-else class="slots">
          <button
            v-for="s in slots"
            :key="s.start_utc"
            type="button"
            class="slot"
            :class="{ sel: nb.slot?.start_utc === s.start_utc }"
            @click="nb.slot = s"
          >
            {{ formatLocalTime(s.start_local) }}
          </button>
        </div>
      </div>

      <hr style="border: none; border-top: 1px solid var(--border); margin: 18px 0" />

      <div class="row" style="gap: 16px; margin-bottom: 12px">
        <label class="row" style="gap: 6px; margin: 0; cursor: pointer">
          <input v-model="nb.clientMode" type="radio" value="new" style="width: auto" />
          <span>Yangi mijoz</span>
        </label>
        <label class="row" style="gap: 6px; margin: 0; cursor: pointer">
          <input v-model="nb.clientMode" type="radio" value="existing" style="width: auto" />
          <span>Mavjud mijoz</span>
        </label>
      </div>

      <template v-if="nb.clientMode === 'new'">
        <div class="field-row">
          <div class="field">
            <label>Ismi</label>
            <input v-model="nb.clientName" placeholder="Sardor Aliyev" />
          </div>
          <div class="field">
            <label>Telefon</label>
            <PhoneInput v-model="nb.clientPhone" />
          </div>
        </div>
      </template>

      <template v-else>
        <div class="field" style="position: relative">
          <label>Mijozni qidirish</label>
          <input
            v-model="nb.clientSearch"
            placeholder="Ism yoki telefon…"
            @input="nb.client_id = ''; searchClients()"
          />
          <ul v-if="clientResults.length" class="cli-drop">
            <li v-for="c in clientResults" :key="c.id" @click="pickClient(c)">
              <strong>{{ c.name }}</strong> <span class="muted">{{ c.phone }}</span>
            </li>
          </ul>
          <small v-if="nb.client_id" class="muted" style="color: var(--success)">✓ Tanlandi</small>
        </div>
      </template>

      <template #footer>
        <button class="btn" @click="showNew = false">Bekor</button>
        <button class="btn btn-primary" :disabled="booking || !nb.slot" @click="submitBooking">
          {{ booking ? 'Saqlanmoqda…' : 'Yozuvni yaratish' }}
        </button>
      </template>
    </Modal>
  </div>
</template>

<style scoped>
.filters {
  display: flex;
  gap: 12px;
  align-items: flex-end;
  flex-wrap: wrap;
  margin-bottom: 18px;
  padding: 16px;
}
.filters .field {
  flex: 1;
  min-width: 130px;
  margin-bottom: 0;
}
.status-select {
  padding: 4px 8px;
  font-size: 12.5px;
  font-weight: 600;
  border-radius: 20px;
  width: auto;
}
.slots {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(72px, 1fr));
  gap: 8px;
}
.slot {
  padding: 8px 4px;
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text);
  border-radius: 8px;
  font: inherit;
  font-weight: 600;
  cursor: pointer;
}
.slot:hover {
  border-color: var(--primary);
}
.slot.sel {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}
.cli-drop {
  list-style: none;
  margin: 4px 0 0;
  padding: 4px;
  position: absolute;
  z-index: 5;
  left: 0;
  right: 0;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  box-shadow: var(--shadow);
  max-height: 200px;
  overflow-y: auto;
}
.cli-drop li {
  padding: 8px 10px;
  border-radius: 6px;
  cursor: pointer;
}
.cli-drop li:hover {
  background: var(--surface-2);
}
</style>
