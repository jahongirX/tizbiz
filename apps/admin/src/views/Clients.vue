<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { api, ApiError } from '@navbat/api-client'
import { formatSom } from '../lib/money'
import { formatDateTime, parseUtc } from '../lib/datetime'
import { confirm } from '../composables/useConfirm'
import Modal from '../components/Modal.vue'
import PhoneInput from '../components/PhoneInput.vue'

// ---- List state ----
const loading = ref(true)
const error = ref('')
const rows = ref([])
const meta = ref({ page: 1, per_page: 20, total: 0, pages: 1 })

const search = ref('')
const segment = ref('')
const page = ref(1)
let searchTimer = null

const segments = [
  { key: '', label: 'Barchasi' },
  { key: 'new', label: 'Yangi' },
  { key: 'repeat', label: 'Takroriy' },
  { key: 'lost', label: "Yo'qolgan" },
]

// ---- Create / edit modal ----
const showModal = ref(false)
const saving = ref(false)
const formError = ref('')
const fieldErrors = ref({})
const editing = ref(null)
const form = ref(blank())
const tagInput = ref('')

// ---- Detail drawer ----
const drawer = ref(null)
const drawerLoading = ref(false)
const loyalty = ref(null)
const history = ref([])

// ---- Client categories (business-wide list + per-client assignment) ----
const allCategories = ref([])
const savingCats = ref(false)

async function loadCategories() {
  try {
    const res = await api.get('/v1/client-categories')
    const list = Array.isArray(res?.data) ? res.data : Array.isArray(res) ? res : res?.items || []
    allCategories.value = [...list].sort((a, b) => (a.sort ?? 0) - (b.sort ?? 0))
  } catch {
    allCategories.value = []
  }
}

function hasCategory(id) {
  return (drawer.value?.categories || []).some((c) => c.id === id)
}

// Toggle a category on the open client and persist the full set immediately.
async function toggleCategory(cat) {
  if (!drawer.value || savingCats.value) return
  const current = drawer.value.categories || []
  const on = current.some((c) => c.id === cat.id)
  const ids = on
    ? current.filter((c) => c.id !== cat.id).map((c) => c.id)
    : [...current.map((c) => c.id), cat.id]
  savingCats.value = true
  try {
    const res = await api.put('/v1/clients/' + drawer.value.id + '/categories', { category_ids: ids })
    const next = Array.isArray(res?.data) ? res.data : Array.isArray(res) ? res : res?.categories || []
    drawer.value = { ...drawer.value, categories: next }
    // Keep the corresponding table row in sync.
    const row = rows.value.find((r) => r.id === drawer.value.id)
    if (row) row.categories = next
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Kategoriyani saqlab bo\'lmadi'
  } finally {
    savingCats.value = false
  }
}

const statusLabels = {
  pending: 'Kutilmoqda',
  confirmed: 'Tasdiqlangan',
  arrived: 'Keldi',
  completed: 'Yakunlandi',
  no_show: 'Kelmadi',
  canceled: 'Bekor',
}

function blank() {
  return { name: '', phone: '', email: '', birthday: '', notes: '', tags: [] }
}

// Show a date (either 'YYYY-MM-DD' or a UTC datetime) as "dd.MM.yyyy".
function formatDate(str) {
  if (!str) return '—'
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(str)
  if (m) return `${m[3]}.${m[2]}.${m[1]}`
  const d = parseUtc(str)
  if (!d) return String(str)
  return new Intl.DateTimeFormat('uz-UZ', {
    timeZone: 'Asia/Tashkent',
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(d)
}

// ---- Loading ----
async function load() {
  loading.value = true
  error.value = ''
  try {
    const params = new URLSearchParams()
    const q = search.value.trim()
    if (q) params.set('search', q)
    if (segment.value) params.set('segment', segment.value)
    params.set('page', String(page.value))
    params.set('per_page', String(meta.value.per_page || 20))
    const res = await api.get('/v1/clients?' + params.toString())
    rows.value = Array.isArray(res?.data) ? res.data : Array.isArray(res) ? res : []
    meta.value = res?.meta || {
      page: page.value,
      per_page: meta.value.per_page || 20,
      total: rows.value.length,
      pages: 1,
    }
  } catch (e) {
    rows.value = []
    error.value = e instanceof ApiError ? e.message : 'Yuklab bo\'lmadi'
  } finally {
    loading.value = false
  }
}

function onSearch() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => {
    page.value = 1
    load()
  }, 300)
}

function setSegment(key) {
  if (segment.value === key) return
  segment.value = key
  page.value = 1
  load()
}

// ---- Pagination ----
const pageNumbers = computed(() => {
  const pages = Math.max(1, meta.value.pages || 1)
  const cur = meta.value.page || page.value
  const out = []
  const from = Math.max(1, cur - 2)
  const to = Math.min(pages, cur + 2)
  for (let p = from; p <= to; p++) out.push(p)
  return out
})

function goPage(p) {
  const pages = Math.max(1, meta.value.pages || 1)
  if (p < 1 || p > pages || p === (meta.value.page || page.value)) return
  page.value = p
  load()
}

// ---- Create / edit ----
function openCreate() {
  editing.value = null
  form.value = blank()
  tagInput.value = ''
  formError.value = ''
  fieldErrors.value = {}
  showModal.value = true
}

function openEdit(c) {
  editing.value = c
  form.value = {
    name: c.name || '',
    phone: c.phone || '',
    email: c.email || '',
    birthday: c.birthday || '',
    notes: c.notes || c.note || '',
    tags: Array.isArray(c.tags) ? [...c.tags] : [],
  }
  tagInput.value = ''
  formError.value = ''
  fieldErrors.value = {}
  showModal.value = true
}

function addTag() {
  const raw = tagInput.value
  const parts = raw
    .split(',')
    .map((t) => t.trim())
    .filter(Boolean)
  for (const t of parts) {
    if (!form.value.tags.includes(t)) form.value.tags.push(t)
  }
  tagInput.value = ''
}

function onTagKeydown(e) {
  if (e.key === 'Enter' || e.key === ',') {
    e.preventDefault()
    addTag()
  } else if (e.key === 'Backspace' && !tagInput.value && form.value.tags.length) {
    form.value.tags.pop()
  }
}

function removeTag(t) {
  form.value.tags = form.value.tags.filter((x) => x !== t)
}

function applyApiErrors(e) {
  fieldErrors.value = {}
  formError.value = ''
  if (e instanceof ApiError && Array.isArray(e.errors) && e.errors.length) {
    for (const err of e.errors) {
      const field =
        err.field ||
        err.source?.parameter ||
        (err.source?.pointer ? err.source.pointer.split('/').pop() : null)
      const msg = err.detail || err.title || 'Xato'
      if (field) fieldErrors.value[field] = msg
    }
    if (!Object.keys(fieldErrors.value).length) formError.value = e.message
  } else {
    formError.value = e instanceof ApiError ? e.message : 'Saqlab bo\'lmadi'
  }
}

async function save() {
  formError.value = ''
  fieldErrors.value = {}
  if (!form.value.name.trim()) {
    fieldErrors.value = { name: 'Mijoz ismini kiriting' }
    return
  }
  if (form.value.phone.replace(/\D/g, '').length < 12) {
    fieldErrors.value = { phone: 'Telefon raqamni to‘liq kiriting' }
    return
  }
  // Fold any half-typed tag into the list before saving.
  if (tagInput.value.trim()) addTag()
  saving.value = true
  try {
    const payload = {
      name: form.value.name.trim(),
      phone: form.value.phone.trim(),
      email: form.value.email.trim() || null,
      birthday: form.value.birthday || null,
      notes: form.value.notes.trim() || null,
      tags: form.value.tags,
    }
    if (editing.value) await api.patch('/v1/clients/' + editing.value.id, payload)
    else await api.post('/v1/clients', payload)
    showModal.value = false
    // Refresh the open drawer if we just edited that client.
    if (editing.value && drawer.value?.id === editing.value.id) {
      await load()
      const still = rows.value.find((r) => r.id === editing.value.id)
      if (still) await openDrawer(still)
    } else {
      await load()
    }
  } catch (e) {
    applyApiErrors(e)
  } finally {
    saving.value = false
  }
}

async function remove(c) {
  if (!(await confirm({ message: `"${c.name}" mijozini o'chirilsinmi?`, danger: true, confirmText: 'O‘chirish' }))) return
  try {
    await api.del('/v1/clients/' + c.id)
    if (drawer.value?.id === c.id) drawer.value = null
    if (showModal.value && editing.value?.id === c.id) showModal.value = false
    await load()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'O\'chirib bo\'lmadi'
  }
}

// ---- Detail drawer ----
async function openDrawer(c) {
  drawer.value = c
  drawerLoading.value = true
  loyalty.value = null
  history.value = []
  try {
    const detail = await api.get('/v1/clients/' + c.id)
    if (detail) {
      drawer.value = { ...c, ...(detail.client || {}) }
      history.value = detail.history || detail.appointments || []
      loyalty.value = detail.loyalty || null
    }
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Ma\'lumotni yuklab bo\'lmadi'
  } finally {
    drawerLoading.value = false
  }
}

onMounted(() => {
  load()
  loadCategories()
})
</script>

<template>
  <div>
    <div class="page-head">
      <h1>Mijozlar</h1>
      <button class="btn btn-primary" @click="openCreate">+ Yangi mijoz</button>
    </div>

    <div class="toolbar">
      <div class="field mb-0" style="max-width: 340px; flex: 1">
        <input
          v-model="search"
          placeholder="Qidiruv: ism / telefon / email…"
          @input="onSearch"
        />
      </div>
      <div class="segs">
        <button
          v-for="s in segments"
          :key="s.key"
          class="seg"
          :class="{ active: segment === s.key }"
          @click="setSegment(s.key)"
        >
          {{ s.label }}
        </button>
      </div>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div class="layout">
      <div class="list-col">
        <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>
        <div v-else-if="!rows.length" class="empty card">Mijozlar topilmadi.</div>
        <template v-else>
          <div class="table-wrap">
            <table class="data">
              <thead>
                <tr>
                  <th>Ism</th>
                  <th>Telefon</th>
                  <th>Email</th>
                  <th style="text-align: right">Sotildi</th>
                  <th style="text-align: right">Tashriflar</th>
                  <th>Oxirgi tashrif</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="c in rows"
                  :key="c.id"
                  style="cursor: pointer"
                  :class="{ active: drawer?.id === c.id }"
                  @click="openDrawer(c)"
                >
                  <td>
                    <strong>{{ c.name }}</strong>
                    <span v-if="c.categories && c.categories.length" class="tags-inline">
                      <span
                        v-for="cat in c.categories"
                        :key="cat.id"
                        class="cat-chip sm"
                        :style="{ background: (cat.color || '#64748b') + '22', color: cat.color || '#94a3b8' }"
                      >{{ cat.name }}</span>
                    </span>
                    <span v-if="c.tags && c.tags.length" class="tags-inline">
                      <span v-for="t in c.tags" :key="t" class="tag-chip sm">{{ t }}</span>
                    </span>
                  </td>
                  <td>{{ c.phone || '—' }}</td>
                  <td>{{ c.email || '—' }}</td>
                  <td style="text-align: right">{{ formatSom(c.spent_tiyin || 0) }}</td>
                  <td style="text-align: right">{{ c.visits ?? 0 }}</td>
                  <td>{{ formatDate(c.last_visit) }}</td>
                  <td style="text-align: right" @click.stop>
                    <button class="btn btn-sm btn-ghost" @click="openDrawer(c)">Ko'rish</button>
                    <button class="btn btn-sm btn-ghost" @click="openEdit(c)">Tahrir</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="pager">
            <span class="muted">Jami: {{ meta.total }}</span>
            <div class="pager-ctrls">
              <button
                class="btn btn-sm"
                :disabled="(meta.page || 1) <= 1"
                @click="goPage((meta.page || 1) - 1)"
              >
                ‹
              </button>
              <button
                v-for="p in pageNumbers"
                :key="p"
                class="btn btn-sm"
                :class="{ 'btn-primary': p === (meta.page || 1) }"
                @click="goPage(p)"
              >
                {{ p }}
              </button>
              <button
                class="btn btn-sm"
                :disabled="(meta.page || 1) >= (meta.pages || 1)"
                @click="goPage((meta.page || 1) + 1)"
              >
                ›
              </button>
            </div>
            <span class="muted">Sahifada: {{ meta.per_page }}</span>
          </div>
        </template>
      </div>

      <Modal v-if="drawer" :title="drawer.name" @close="drawer = null">
        <p class="muted mb-0">{{ drawer.phone || 'Telefon yo\'q' }}</p>
        <p v-if="drawer.email" class="muted" style="margin-top: 4px">{{ drawer.email }}</p>
        <p v-if="drawer.birthday" class="muted" style="margin-top: 4px">
          Tug'ilgan sana: {{ formatDate(drawer.birthday) }}
        </p>
        <div v-if="drawer.tags && drawer.tags.length" class="tags-inline" style="margin-top: 8px">
          <span v-for="t in drawer.tags" :key="t" class="tag-chip sm">{{ t }}</span>
        </div>

        <div class="cat-assign">
          <div class="row between" style="margin-bottom: 6px">
            <span class="muted" style="font-size: 12px">Kategoriyalar</span>
            <span v-if="savingCats" class="muted" style="font-size: 11px">Saqlanmoqda…</span>
          </div>
          <div v-if="!allCategories.length" class="muted" style="font-size: 12px">
            Kategoriya yo'q. <RouterLink to="/categories">Qo'shish</RouterLink>.
          </div>
          <div v-else class="cat-picker">
            <button
              v-for="cat in allCategories"
              :key="cat.id"
              type="button"
              class="cat-chip pick"
              :class="{ on: hasCategory(cat.id) }"
              :disabled="savingCats"
              :style="hasCategory(cat.id)
                ? { background: (cat.color || '#64748b') + '33', color: cat.color || '#94a3b8', borderColor: cat.color || '#64748b' }
                : {}"
              @click="toggleCategory(cat)"
            >
              <span class="dot" :style="{ background: cat.color || '#64748b' }"></span>
              {{ cat.name }}
            </button>
          </div>
        </div>

        <p v-if="drawer.notes || drawer.note" class="muted" style="margin-top: 8px">
          {{ drawer.notes || drawer.note }}
        </p>

        <div class="row" style="gap: 8px; margin-top: 12px">
          <button class="btn btn-sm btn-ghost" @click="openEdit(drawer)">Tahrirlash</button>
          <button class="btn btn-sm btn-danger" @click="remove(drawer)">O'chirish</button>
        </div>

        <div v-if="drawerLoading" class="loading-block"><span class="spinner"></span></div>

        <template v-else>
          <div v-if="loyalty" class="loy-box">
            <div>
              <div class="muted" style="font-size: 12px">Cashback</div>
              <div style="font-size: 20px; font-weight: 700; color: var(--primary)">
                {{ formatSom(loyalty.cashback_tiyin ?? 0) }}
              </div>
            </div>
            <div v-if="loyalty.points != null" class="muted" style="font-size: 12px">
              {{ loyalty.points }} ball
            </div>
          </div>

          <h3 style="font-size: 14px; margin-top: 18px">Tashriflar tarixi</h3>
          <div v-if="!history.length" class="muted" style="font-size: 13px">Tashriflar yo'q.</div>
          <ul v-else class="hist">
            <li v-for="(a, i) in history" :key="a.id || i">
              <div>
                <div>{{ a.service_name || a.service?.name || 'Xizmat' }}</div>
                <div class="muted" style="font-size: 12px">
                  {{ formatDateTime(a.starts_at || a.date) || formatDate(a.date) }}
                </div>
              </div>
              <span class="badge" :class="a.status">{{ statusLabels[a.status] || a.status }}</span>
            </li>
          </ul>
        </template>
      </Modal>
    </div>

    <Modal
      v-if="showModal"
      :title="editing ? 'Mijozni tahrirlash' : 'Yangi mijoz'"
      @close="showModal = false"
    >
      <form @submit.prevent="save">
        <div v-if="formError" class="alert alert-error">{{ formError }}</div>
        <div class="field">
          <label>Ismi</label>
          <input v-model="form.name" placeholder="Sardor Aliyev" />
          <div v-if="fieldErrors.name" class="field-err">{{ fieldErrors.name }}</div>
        </div>
        <div class="field">
          <label>Telefon</label>
          <PhoneInput v-model="form.phone" />
          <div v-if="fieldErrors.phone" class="field-err">{{ fieldErrors.phone }}</div>
        </div>
        <div class="field-row">
          <div class="field">
            <label>Email</label>
            <input v-model="form.email" type="email" placeholder="mijoz@example.com" />
            <div v-if="fieldErrors.email" class="field-err">{{ fieldErrors.email }}</div>
          </div>
          <div class="field">
            <label>Tug'ilgan sana</label>
            <input v-model="form.birthday" type="date" />
            <div v-if="fieldErrors.birthday" class="field-err">{{ fieldErrors.birthday }}</div>
          </div>
        </div>
        <div class="field">
          <label>Teglar</label>
          <div class="tag-box">
            <span v-for="t in form.tags" :key="t" class="tag-chip">
              {{ t }}
              <button type="button" class="tag-x" @click="removeTag(t)">✕</button>
            </span>
            <input
              v-model="tagInput"
              class="tag-input"
              placeholder="teg qo'shish…"
              @keydown="onTagKeydown"
              @blur="addTag"
            />
          </div>
          <div v-if="fieldErrors.tags" class="field-err">{{ fieldErrors.tags }}</div>
        </div>
        <div class="field">
          <label>Izoh</label>
          <textarea v-model="form.notes" rows="2" placeholder="Ixtiyoriy"></textarea>
          <div v-if="fieldErrors.notes" class="field-err">{{ fieldErrors.notes }}</div>
        </div>
      </form>
      <template #footer>
        <button class="btn" @click="showModal = false">Bekor</button>
        <button class="btn btn-primary" :disabled="saving" @click="save">
          {{ saving ? 'Saqlanmoqda…' : 'Saqlash' }}
        </button>
      </template>
    </Modal>
  </div>
</template>

<style scoped>
.toolbar {
  display: flex;
  gap: 12px;
  align-items: center;
  flex-wrap: wrap;
  margin-bottom: 16px;
}
.segs {
  display: inline-flex;
  gap: 4px;
  background: var(--surface-2);
  border: 1px solid var(--border);
  border-radius: 9px;
  padding: 3px;
}
.seg {
  font: inherit;
  font-weight: 600;
  font-size: 13px;
  cursor: pointer;
  border: none;
  background: transparent;
  color: var(--text-muted);
  padding: 6px 12px;
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

.layout {
  display: grid;
  grid-template-columns: 1fr;
  gap: 18px;
}
.layout:has(.drawer) {
  grid-template-columns: 1fr 360px;
}
@media (max-width: 900px) {
  .layout:has(.drawer) {
    grid-template-columns: 1fr;
  }
}
table.data tbody tr.active {
  background: var(--primary-soft);
}

.pager {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
  margin-top: 14px;
  font-size: 13px;
}
.pager-ctrls {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.drawer {
  align-self: start;
  position: sticky;
  top: 84px;
}
.loy-box {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: var(--surface-2);
  border-radius: 10px;
  padding: 14px 16px;
  margin-top: 16px;
}
.hist {
  list-style: none;
  margin: 8px 0 0;
  padding: 0;
}
.hist li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  padding: 10px 0;
  border-bottom: 1px solid var(--border);
}
.hist li:last-child {
  border-bottom: none;
}

.field-err {
  color: var(--danger);
  font-size: 12px;
  margin-top: 4px;
}

.tags-inline {
  display: inline-flex;
  gap: 4px;
  flex-wrap: wrap;
  margin-left: 8px;
  vertical-align: middle;
}
.tag-box {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  align-items: center;
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 6px 8px;
  background: var(--surface);
}
.tag-box:focus-within {
  border-color: var(--primary);
}
.tag-chip {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  background: var(--primary-soft);
  color: var(--primary);
  border-radius: 20px;
  padding: 3px 10px;
  font-size: 12.5px;
  font-weight: 600;
}
.tag-chip.sm {
  padding: 1px 8px;
  font-size: 11px;
}
.tag-x {
  border: none;
  background: transparent;
  color: inherit;
  cursor: pointer;
  font-size: 11px;
  padding: 0;
  line-height: 1;
}
.tag-input {
  border: none;
  background: transparent;
  padding: 3px 2px;
  width: auto;
  flex: 1;
  min-width: 120px;
}
.tag-input:focus {
  border: none;
}

.cat-chip {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  border-radius: 20px;
  padding: 3px 10px;
  font-size: 12.5px;
  font-weight: 600;
  background: var(--surface-2);
  color: var(--text-muted);
}
.cat-chip.sm {
  padding: 1px 8px;
  font-size: 11px;
}
.cat-assign {
  margin-top: 14px;
  padding-top: 14px;
  border-top: 1px solid var(--border);
}
.cat-picker {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.cat-chip.pick {
  cursor: pointer;
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text-muted);
  transition: border-color 0.12s, color 0.12s, background 0.12s;
}
.cat-chip.pick:hover {
  color: var(--text);
}
.cat-chip.pick:disabled {
  cursor: default;
  opacity: 0.7;
}
.cat-chip.pick .dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  flex-shrink: 0;
}
</style>
