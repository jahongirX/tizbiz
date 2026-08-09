<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { api, ApiError } from '@tizbiz/api-client'
import { somToTiyin, tiyinToSom, formatSom } from '../lib/money'
import { confirm } from '../composables/useConfirm'
import Modal from '../components/Modal.vue'

// ---- Tabs ----
const tabs = [
  { key: 'discount', label: 'Chegirma qoidalari' },
  { key: 'category', label: 'Kategoriya qoidalari' },
  { key: 'settings', label: 'Sozlamalar' },
]
const tab = ref('discount')

// ---- Metric metadata ----
const metricLabels = {
  sold: 'Sotilgan',
  paid: "To'langan",
  visits: 'Tashriflar',
  inactive_days: 'Faol emas (kun)',
}
// Money-valued metrics store their threshold in TIYIN; the rest store a count.
function isMoneyMetric(m) {
  return m === 'sold' || m === 'paid'
}
function thresholdLabel(m) {
  if (isMoneyMetric(m)) return "Chegara (so'm)"
  if (m === 'inactive_days') return 'Chegara (kun)'
  return 'Chegara (tashrif)'
}
function formatThreshold(m, threshold) {
  if (isMoneyMetric(m)) return formatSom(threshold)
  return String(threshold ?? 0)
}

function applyApiErrors(e, formError, fieldErrors) {
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

// ============================================================
// Discount rules
// ============================================================
const discLoading = ref(true)
const discError = ref('')
const discRules = ref([])

const discModal = ref(false)
const discSaving = ref(false)
const discFormError = ref('')
const discFieldErrors = ref({})
const discEditing = ref(null)
const discForm = ref(blankDisc())

function blankDisc() {
  return { metric: 'sold', threshold: '', percent: '', active: true }
}

async function loadDisc() {
  discLoading.value = true
  discError.value = ''
  try {
    const res = await api.get('/v1/loyalty/discount-rules')
    discRules.value = Array.isArray(res) ? res : res?.items || []
  } catch (e) {
    discRules.value = []
    discError.value = e instanceof ApiError ? e.message : 'Yuklab bo\'lmadi'
  } finally {
    discLoading.value = false
  }
}

function openDiscCreate() {
  discEditing.value = null
  discForm.value = blankDisc()
  discFormError.value = ''
  discFieldErrors.value = {}
  discModal.value = true
}

function openDiscEdit(r) {
  discEditing.value = r
  discForm.value = {
    metric: r.metric,
    threshold: isMoneyMetric(r.metric) ? tiyinToSom(r.threshold) : r.threshold,
    percent: r.percent,
    active: r.active !== false,
  }
  discFormError.value = ''
  discFieldErrors.value = {}
  discModal.value = true
}

async function saveDisc() {
  discFormError.value = ''
  discFieldErrors.value = {}
  discSaving.value = true
  try {
    const metric = discForm.value.metric
    const threshold = isMoneyMetric(metric)
      ? somToTiyin(discForm.value.threshold)
      : Math.round(Number(discForm.value.threshold) || 0)
    const payload = {
      metric,
      threshold,
      percent: Math.round(Number(discForm.value.percent) || 0),
      active: discForm.value.active,
    }
    if (discEditing.value)
      await api.patch('/v1/loyalty/discount-rules/' + discEditing.value.id, payload)
    else await api.post('/v1/loyalty/discount-rules', payload)
    discModal.value = false
    await loadDisc()
  } catch (e) {
    applyApiErrors(e, discFormError, discFieldErrors)
  } finally {
    discSaving.value = false
  }
}

async function removeDisc(r) {
  if (!(await confirm({ message: 'Chegirma qoidasini o\'chirilsinmi?', danger: true, confirmText: 'O‘chirish' }))) return
  try {
    await api.del('/v1/loyalty/discount-rules/' + r.id)
    await loadDisc()
  } catch (e) {
    discError.value = e instanceof ApiError ? e.message : 'O\'chirib bo\'lmadi'
  }
}

// ============================================================
// Auto-category rules
// ============================================================
const catLoading = ref(true)
const catError = ref('')
const catRules = ref([])
const categories = ref([])

const catModal = ref(false)
const catSaving = ref(false)
const catFormError = ref('')
const catFieldErrors = ref({})
const catEditing = ref(null)
const catForm = ref(blankCat())

const applying = ref(false)
const applyResult = ref(null)

const catMetricOptions = ['sold', 'paid', 'visits', 'inactive_days']

const categoryMap = computed(() => {
  const map = {}
  for (const c of categories.value) map[c.id] = c
  return map
})

function blankCat() {
  return { metric: 'visits', threshold: '', action: 'add', category_id: '', active: true }
}

async function loadCat() {
  catLoading.value = true
  catError.value = ''
  try {
    const [rules, cats] = await Promise.all([
      api.get('/v1/loyalty/auto-category-rules'),
      api.get('/v1/client-categories').catch(() => []),
    ])
    catRules.value = Array.isArray(rules) ? rules : rules?.items || []
    categories.value = Array.isArray(cats) ? cats : cats?.items || []
  } catch (e) {
    catRules.value = []
    catError.value = e instanceof ApiError ? e.message : 'Yuklab bo\'lmadi'
  } finally {
    catLoading.value = false
  }
}

function openCatCreate() {
  catEditing.value = null
  catForm.value = blankCat()
  if (categories.value.length) catForm.value.category_id = categories.value[0].id
  catFormError.value = ''
  catFieldErrors.value = {}
  catModal.value = true
}

function openCatEdit(r) {
  catEditing.value = r
  catForm.value = {
    metric: r.metric,
    threshold: isMoneyMetric(r.metric) ? tiyinToSom(r.threshold) : r.threshold,
    action: r.action,
    category_id: r.category_id,
    active: r.active !== false,
  }
  catFormError.value = ''
  catFieldErrors.value = {}
  catModal.value = true
}

async function saveCat() {
  catFormError.value = ''
  catFieldErrors.value = {}
  if (!catForm.value.category_id) {
    catFieldErrors.value = { category_id: 'Kategoriyani tanlang' }
    return
  }
  catSaving.value = true
  try {
    const metric = catForm.value.metric
    const threshold = isMoneyMetric(metric)
      ? somToTiyin(catForm.value.threshold)
      : Math.round(Number(catForm.value.threshold) || 0)
    const payload = {
      metric,
      threshold,
      action: catForm.value.action,
      category_id: catForm.value.category_id,
      active: catForm.value.active,
    }
    if (catEditing.value)
      await api.patch('/v1/loyalty/auto-category-rules/' + catEditing.value.id, payload)
    else await api.post('/v1/loyalty/auto-category-rules', payload)
    catModal.value = false
    await loadCat()
  } catch (e) {
    applyApiErrors(e, catFormError, catFieldErrors)
  } finally {
    catSaving.value = false
  }
}

async function removeCat(r) {
  if (!(await confirm({ message: 'Kategoriya qoidasini o\'chirilsinmi?', danger: true, confirmText: 'O‘chirish' }))) return
  try {
    await api.del('/v1/loyalty/auto-category-rules/' + r.id)
    await loadCat()
  } catch (e) {
    catError.value = e instanceof ApiError ? e.message : 'O\'chirib bo\'lmadi'
  }
}

async function applyRules() {
  applying.value = true
  applyResult.value = null
  catError.value = ''
  try {
    const res = await api.post('/v1/loyalty/auto-category-rules/apply', {})
    applyResult.value = {
      added: res?.added ?? 0,
      removed: res?.removed ?? 0,
    }
  } catch (e) {
    catError.value = e instanceof ApiError ? e.message : 'Qo\'llab bo\'lmadi'
  } finally {
    applying.value = false
  }
}

// ============================================================
// Settings
// ============================================================
const setLoading = ref(true)
const setError = ref('')
const setSaving = ref(false)
const setSaved = ref(false)
const setFieldErrors = ref({})
const setForm = ref({
  earn_percent: 0,
  referral_bonus_som: 0,
  referral_bonus_points: 0,
  discount_cancel_days: 0,
  sms_notify_days: 0,
})

async function loadSettings() {
  setLoading.value = true
  setError.value = ''
  try {
    const s = (await api.get('/v1/loyalty/settings')) || {}
    setForm.value = {
      earn_percent: (Number(s.earn_rate) || 0) / 100,
      referral_bonus_som: tiyinToSom(s.referral_bonus_tiyin || 0),
      referral_bonus_points: Number(s.referral_bonus_points) || 0,
      discount_cancel_days: Number(s.discount_cancel_days) || 0,
      sms_notify_days: Number(s.sms_notify_days) || 0,
    }
  } catch (e) {
    setError.value = e instanceof ApiError ? e.message : 'Yuklab bo\'lmadi'
  } finally {
    setLoading.value = false
  }
}

async function saveSettings() {
  setSaving.value = true
  setSaved.value = false
  setError.value = ''
  setFieldErrors.value = {}
  try {
    const payload = {
      earn_rate: Math.round((Number(setForm.value.earn_percent) || 0) * 100),
      referral_bonus_tiyin: somToTiyin(setForm.value.referral_bonus_som),
      referral_bonus_points: Math.round(Number(setForm.value.referral_bonus_points) || 0),
      discount_cancel_days: Math.round(Number(setForm.value.discount_cancel_days) || 0),
      sms_notify_days: Math.round(Number(setForm.value.sms_notify_days) || 0),
    }
    await api.put('/v1/loyalty/settings', payload)
    setSaved.value = true
    setTimeout(() => (setSaved.value = false), 2500)
  } catch (e) {
    const fe = ref({})
    applyApiErrors(e, setError, fe)
    setFieldErrors.value = fe.value
  } finally {
    setSaving.value = false
  }
}

onMounted(() => {
  loadDisc()
  loadCat()
  loadSettings()
})
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <RouterLink to="/loyalty" class="back-link">← Loyallik</RouterLink>
        <h1>Loyallik kartalari, chegirma va cashback</h1>
      </div>
    </div>

    <div class="segs" style="margin-bottom: 18px">
      <button
        v-for="t in tabs"
        :key="t.key"
        class="seg"
        :class="{ active: tab === t.key }"
        @click="tab = t.key"
      >
        {{ t.label }}
      </button>
    </div>

    <!-- ============ DISCOUNT RULES ============ -->
    <section v-show="tab === 'discount'">
      <div class="row between" style="margin-bottom: 14px; align-items: center">
        <p class="muted mb-0">
          Mijozning umumiy sotilgan/to'langan summasi yoki tashriflar soniga qarab avtomatik chegirma.
        </p>
        <button class="btn btn-primary" @click="openDiscCreate">+ Qoida</button>
      </div>

      <div v-if="discError" class="alert alert-error">{{ discError }}</div>
      <div v-if="discLoading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

      <template v-else>
        <div v-if="!discRules.length" class="empty card">
          Hali chegirma qoidasi yo'q. <a href="#" @click.prevent="openDiscCreate">Birinchisini qo'shing</a>.
        </div>
        <div v-else class="table-wrap">
          <table class="data">
            <thead>
              <tr>
                <th>Mezon</th>
                <th>Chegara</th>
                <th>Chegirma</th>
                <th>Holat</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in discRules" :key="r.id">
                <td><strong>{{ metricLabels[r.metric] || r.metric }}</strong></td>
                <td>{{ formatThreshold(r.metric, r.threshold) }}</td>
                <td>{{ r.percent }}%</td>
                <td>
                  <span class="badge" :class="r.active !== false ? 'completed' : 'canceled'">
                    {{ r.active !== false ? 'Faol' : 'Nofaol' }}
                  </span>
                </td>
                <td style="text-align: right">
                  <button class="btn btn-sm btn-ghost" @click="openDiscEdit(r)">Tahrir</button>
                  <button class="btn btn-sm btn-danger" @click="removeDisc(r)">O'chirish</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </section>

    <!-- ============ AUTO-CATEGORY RULES ============ -->
    <section v-show="tab === 'category'">
      <div class="row between" style="margin-bottom: 14px; align-items: center">
        <p class="muted mb-0">
          Mijozlarni mezon bo'yicha avtomatik kategoriyaga qo'shish yoki olib tashlash.
        </p>
        <div class="row" style="gap: 8px">
          <button class="btn" :disabled="applying" @click="applyRules">
            {{ applying ? 'Qo\'llanmoqda…' : 'Qoidalarni qo\'llash' }}
          </button>
          <button class="btn btn-primary" @click="openCatCreate">+ Qoida</button>
        </div>
      </div>

      <div v-if="applyResult" class="alert" style="background: var(--primary-soft); color: var(--primary)">
        Qo'shildi: {{ applyResult.added }} · Olib tashlandi: {{ applyResult.removed }}
      </div>
      <div v-if="catError" class="alert alert-error">{{ catError }}</div>
      <div v-if="catLoading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

      <template v-else>
        <div v-if="!catRules.length" class="empty card">
          Hali kategoriya qoidasi yo'q. <a href="#" @click.prevent="openCatCreate">Birinchisini qo'shing</a>.
        </div>
        <div v-else class="table-wrap">
          <table class="data">
            <thead>
              <tr>
                <th>Mezon</th>
                <th>Chegara</th>
                <th>Amal</th>
                <th>Kategoriya</th>
                <th>Holat</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in catRules" :key="r.id">
                <td><strong>{{ metricLabels[r.metric] || r.metric }}</strong></td>
                <td>{{ formatThreshold(r.metric, r.threshold) }}</td>
                <td>{{ r.action === 'remove' ? 'Olib tashlash' : "Qo'shish" }}</td>
                <td>
                  <span
                    v-if="categoryMap[r.category_id]"
                    class="cat-chip"
                    :style="{ background: categoryMap[r.category_id].color || 'var(--surface-2)' }"
                  >
                    {{ categoryMap[r.category_id].name }}
                  </span>
                  <span v-else class="muted">—</span>
                </td>
                <td>
                  <span class="badge" :class="r.active !== false ? 'completed' : 'canceled'">
                    {{ r.active !== false ? 'Faol' : 'Nofaol' }}
                  </span>
                </td>
                <td style="text-align: right">
                  <button class="btn btn-sm btn-ghost" @click="openCatEdit(r)">Tahrir</button>
                  <button class="btn btn-sm btn-danger" @click="removeCat(r)">O'chirish</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </section>

    <!-- ============ SETTINGS ============ -->
    <section v-show="tab === 'settings'">
      <div v-if="setError" class="alert alert-error">{{ setError }}</div>
      <div v-if="setLoading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

      <div v-else class="card" style="max-width: 520px">
        <form @submit.prevent="saveSettings">
          <div class="field">
            <label>Cashback foizi (%)</label>
            <div class="row" style="gap: 8px">
              <input
                v-model.number="setForm.earn_percent"
                type="number"
                min="0"
                max="100"
                step="0.5"
                style="max-width: 140px"
              />
              <span class="muted">% har xariddan</span>
            </div>
            <small class="muted">Masalan 5% — 100 000 so'mlik xizmatdan 5 000 so'mlik ball.</small>
            <div v-if="setFieldErrors.earn_rate" class="field-err">{{ setFieldErrors.earn_rate }}</div>
          </div>

          <div class="field-row">
            <div class="field">
              <label>Referral bonus (so'm)</label>
              <input v-model.number="setForm.referral_bonus_som" type="number" min="0" step="1000" />
              <div v-if="setFieldErrors.referral_bonus_tiyin" class="field-err">
                {{ setFieldErrors.referral_bonus_tiyin }}
              </div>
            </div>
            <div class="field">
              <label>Referral bonus (ball)</label>
              <input v-model.number="setForm.referral_bonus_points" type="number" min="0" step="1" />
              <div v-if="setFieldErrors.referral_bonus_points" class="field-err">
                {{ setFieldErrors.referral_bonus_points }}
              </div>
            </div>
          </div>

          <div class="field-row">
            <div class="field">
              <label>Chegirmani bekor qilish (kun)</label>
              <input v-model.number="setForm.discount_cancel_days" type="number" min="0" step="1" />
              <small class="muted">Faolsizlikdan keyin chegirma bekor bo'ladi.</small>
              <div v-if="setFieldErrors.discount_cancel_days" class="field-err">
                {{ setFieldErrors.discount_cancel_days }}
              </div>
            </div>
            <div class="field">
              <label>SMS eslatma (necha kun oldin)</label>
              <input v-model.number="setForm.sms_notify_days" type="number" min="0" step="1" />
              <div v-if="setFieldErrors.sms_notify_days" class="field-err">
                {{ setFieldErrors.sms_notify_days }}
              </div>
            </div>
          </div>

          <div class="row" style="margin-top: 20px; gap: 12px; align-items: center">
            <button class="btn btn-primary" :disabled="setSaving" type="submit">
              {{ setSaving ? 'Saqlanmoqda…' : 'Saqlash' }}
            </button>
            <span v-if="setSaved" style="color: var(--success); font-weight: 600">✓ Saqlandi</span>
          </div>
        </form>
      </div>
    </section>

    <!-- ============ Discount rule modal ============ -->
    <Modal
      v-if="discModal"
      :title="discEditing ? 'Chegirma qoidasini tahrirlash' : 'Yangi chegirma qoidasi'"
      @close="discModal = false"
    >
      <form @submit.prevent="saveDisc">
        <div v-if="discFormError" class="alert alert-error">{{ discFormError }}</div>
        <div class="field">
          <label>Mezon</label>
          <select v-model="discForm.metric">
            <option value="sold">Sotilgan</option>
            <option value="paid">To'langan</option>
            <option value="visits">Tashriflar</option>
          </select>
          <div v-if="discFieldErrors.metric" class="field-err">{{ discFieldErrors.metric }}</div>
        </div>
        <div class="field-row">
          <div class="field">
            <label>{{ thresholdLabel(discForm.metric) }}</label>
            <input
              v-model.number="discForm.threshold"
              type="number"
              min="0"
              :step="isMoneyMetric(discForm.metric) ? 1000 : 1"
            />
            <div v-if="discFieldErrors.threshold" class="field-err">{{ discFieldErrors.threshold }}</div>
          </div>
          <div class="field">
            <label>Chegirma (%)</label>
            <input v-model.number="discForm.percent" type="number" min="0" max="100" step="1" />
            <div v-if="discFieldErrors.percent" class="field-err">{{ discFieldErrors.percent }}</div>
          </div>
        </div>
        <label class="row" style="gap: 8px; cursor: pointer">
          <input v-model="discForm.active" type="checkbox" style="width: auto" />
          <span>Faol</span>
        </label>
      </form>
      <template #footer>
        <button class="btn" @click="discModal = false">Bekor</button>
        <button class="btn btn-primary" :disabled="discSaving" @click="saveDisc">
          {{ discSaving ? 'Saqlanmoqda…' : 'Saqlash' }}
        </button>
      </template>
    </Modal>

    <!-- ============ Auto-category rule modal ============ -->
    <Modal
      v-if="catModal"
      :title="catEditing ? 'Kategoriya qoidasini tahrirlash' : 'Yangi kategoriya qoidasi'"
      @close="catModal = false"
    >
      <form @submit.prevent="saveCat">
        <div v-if="catFormError" class="alert alert-error">{{ catFormError }}</div>
        <div class="field">
          <label>Mezon</label>
          <select v-model="catForm.metric">
            <option v-for="m in catMetricOptions" :key="m" :value="m">{{ metricLabels[m] }}</option>
          </select>
          <div v-if="catFieldErrors.metric" class="field-err">{{ catFieldErrors.metric }}</div>
        </div>
        <div class="field-row">
          <div class="field">
            <label>{{ thresholdLabel(catForm.metric) }}</label>
            <input
              v-model.number="catForm.threshold"
              type="number"
              min="0"
              :step="isMoneyMetric(catForm.metric) ? 1000 : 1"
            />
            <div v-if="catFieldErrors.threshold" class="field-err">{{ catFieldErrors.threshold }}</div>
          </div>
          <div class="field">
            <label>Amal</label>
            <select v-model="catForm.action">
              <option value="add">Qo'shish</option>
              <option value="remove">Olib tashlash</option>
            </select>
            <div v-if="catFieldErrors.action" class="field-err">{{ catFieldErrors.action }}</div>
          </div>
        </div>
        <div class="field">
          <label>Kategoriya</label>
          <select v-model="catForm.category_id">
            <option value="">— tanlang —</option>
            <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
          <div v-if="catFieldErrors.category_id" class="field-err">{{ catFieldErrors.category_id }}</div>
          <small v-if="!categories.length" class="muted">
            Avval "Mijozlar" bo'limida kategoriya yarating.
          </small>
        </div>
        <label class="row" style="gap: 8px; cursor: pointer">
          <input v-model="catForm.active" type="checkbox" style="width: auto" />
          <span>Faol</span>
        </label>
      </form>
      <template #footer>
        <button class="btn" @click="catModal = false">Bekor</button>
        <button class="btn btn-primary" :disabled="catSaving" @click="saveCat">
          {{ catSaving ? 'Saqlanmoqda…' : 'Saqlash' }}
        </button>
      </template>
    </Modal>
  </div>
</template>

<style scoped>
.back-link {
  display: inline-block;
  font-size: 13px;
  font-weight: 600;
  color: var(--text-muted);
  text-decoration: none;
  margin-bottom: 6px;
}
.back-link:hover {
  color: var(--primary);
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
  padding: 6px 14px;
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

.row.between {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}

.field-err {
  color: var(--danger);
  font-size: 12px;
  margin-top: 4px;
}

.cat-chip {
  display: inline-block;
  padding: 2px 10px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 600;
  color: #fff;
}
</style>
