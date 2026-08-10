<script setup>
import { ref, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { somToTiyin, tiyinToSom, formatSom } from '../lib/money'
import { confirm } from '../composables/useConfirm'
import Modal from '../components/Modal.vue'
import ImageUpload from '../components/ImageUpload.vue'
import { Pencil, Trash2 } from 'lucide-vue-next'

const loading = ref(true)
const error = ref('')
const services = ref([])
const categories = ref([])

const showModal = ref(false)
const saving = ref(false)
const formError = ref('')
const editing = ref(null)
const form = ref(blank())

function blank() {
  return { name: '', duration_min: 30, price_som: '', deposit_som: '', category_id: '', is_active: true, online_bookable: true, image: '' }
}

const categoryName = computed(() => {
  const map = {}
  for (const c of categories.value) map[c.id] = c.name
  return map
})

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [svc, cats] = await Promise.all([
      api.get('/v1/services'),
      api.get('/v1/service-categories').catch(() => []),
    ])
    services.value = Array.isArray(svc) ? svc : svc?.items || []
    categories.value = Array.isArray(cats) ? cats : cats?.items || []
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Yuklab bo\'lmadi'
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editing.value = null
  form.value = blank()
  formError.value = ''
  showModal.value = true
}

function openEdit(s) {
  editing.value = s
  form.value = {
    name: s.name,
    duration_min: s.duration_min,
    price_som: tiyinToSom(s.price_tiyin),
    deposit_som: s.deposit_tiyin ? tiyinToSom(s.deposit_tiyin) : '',
    category_id: s.category_id || '',
    is_active: s.is_active !== false,
    online_bookable: s.online_bookable !== false,
    image: s.image || '',
  }
  formError.value = ''
  showModal.value = true
}

async function save() {
  formError.value = ''
  saving.value = true
  try {
    const payload = {
      name: form.value.name.trim(),
      duration_min: Number(form.value.duration_min),
      price_tiyin: somToTiyin(form.value.price_som),
      deposit_tiyin: form.value.deposit_som === '' ? 0 : somToTiyin(form.value.deposit_som),
      category_id: form.value.category_id || null,
      is_active: form.value.is_active,
      online_bookable: form.value.online_bookable,
      image: form.value.image || '',
    }
    if (editing.value) {
      await api.patch('/v1/services/' + editing.value.id, payload)
    } else {
      await api.post('/v1/services', payload)
    }
    showModal.value = false
    await load()
  } catch (e) {
    formError.value = e instanceof ApiError ? e.message : 'Saqlab bo\'lmadi'
  } finally {
    saving.value = false
  }
}

async function remove(s) {
  if (!(await confirm({ message: `"${s.name}" xizmatini o'chirilsinmi?`, danger: true, confirmText: 'O‘chirish' }))) return
  try {
    await api.del('/v1/services/' + s.id)
    await load()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'O\'chirib bo\'lmadi'
  }
}

// ---- Categories (with image) ----
const catModal = ref(false)
const catSaving = ref(false)
const catError = ref('')
const editingCat = ref(null)
const catForm = ref({ name: '', image: '' })

function openCatCreate() {
  editingCat.value = null
  catForm.value = { name: '', image: '' }
  catError.value = ''
  catModal.value = true
}
function openCatEdit(c) {
  editingCat.value = c
  catForm.value = { name: c.name, image: c.image || '' }
  catError.value = ''
  catModal.value = true
}
async function saveCat() {
  catError.value = ''
  catSaving.value = true
  try {
    const payload = { name: catForm.value.name.trim(), image: catForm.value.image || '' }
    if (editingCat.value) await api.patch('/v1/service-categories/' + editingCat.value.id, payload)
    else await api.post('/v1/service-categories', payload)
    catModal.value = false
    await load()
  } catch (e) {
    catError.value = e instanceof ApiError ? e.message : 'Saqlab bo\'lmadi'
  } finally {
    catSaving.value = false
  }
}
async function removeCat(c) {
  if (!(await confirm({ message: `"${c.name}" kategoriyasini o'chirilsinmi?`, danger: true, confirmText: 'O‘chirish' }))) return
  try {
    await api.del('/v1/service-categories/' + c.id)
    await load()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'O\'chirib bo\'lmadi'
  }
}

onMounted(load)
</script>

<template>
  <div>
    <div class="page-head">
      <h1>Xizmatlar</h1>
      <button class="btn btn-primary" @click="openCreate">+ Yangi xizmat</button>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>
    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

    <template v-else>
      <!-- Categories with images -->
      <section class="cat-panel card">
        <div class="cat-panel-head">
          <h3>Kategoriyalar</h3>
          <button class="btn btn-sm btn-primary" @click="openCatCreate">+ Kategoriya</button>
        </div>
        <p v-if="!categories.length" class="muted" style="margin: 0; font-size: 13px">
          Kategoriya yo‘q. Menyu/xizmatlarni bo‘limlarga ajrating.
        </p>
        <div v-else class="cat-list">
          <div v-for="c in categories" :key="c.id" class="cat-item">
            <img v-if="c.image" :src="c.image" class="cat-thumb" alt="" />
            <span v-else class="cat-thumb ph">{{ c.name.charAt(0) }}</span>
            <span class="cat-name">{{ c.name }}</span>
            <button class="icon-btn" title="Tahrir" @click="openCatEdit(c)"><Pencil :size="14" /></button>
            <button class="icon-btn del" title="O‘chirish" @click="removeCat(c)"><Trash2 :size="14" /></button>
          </div>
        </div>
      </section>

      <div v-if="!services.length" class="empty card">
        Hali xizmat qo'shilmagan. <a href="#" @click.prevent="openCreate">Birinchisini qo'shing</a>.
      </div>

      <div v-else class="table-wrap">
        <table class="data">
          <thead>
            <tr>
              <th style="width: 44px"></th>
              <th>Nomi</th>
              <th>Kategoriya</th>
              <th>Davomiyligi</th>
              <th>Narxi</th>
              <th>Depozit</th>
              <th>Onlayn bron</th>
              <th>Holat</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="s in services" :key="s.id">
              <td>
                <img v-if="s.image" :src="s.image" class="row-thumb" alt="" />
                <span v-else class="row-thumb ph">{{ s.name.charAt(0) }}</span>
              </td>
              <td><strong>{{ s.name }}</strong></td>
              <td>{{ categoryName[s.category_id] || '—' }}</td>
              <td>{{ s.duration_min }} daqiqa</td>
              <td>{{ formatSom(s.price_tiyin) }}</td>
              <td>{{ s.deposit_tiyin ? formatSom(s.deposit_tiyin) : '—' }}</td>
              <td>
                <span class="badge" :class="s.online_bookable !== false ? 'completed' : 'canceled'">
                  {{ s.online_bookable !== false ? 'Ochiq' : 'Yopiq' }}
                </span>
              </td>
              <td>
                <span class="badge" :class="s.is_active !== false ? 'completed' : 'canceled'">
                  {{ s.is_active !== false ? 'Faol' : 'Nofaol' }}
                </span>
              </td>
              <td style="text-align: right">
                <button class="btn btn-sm btn-ghost" @click="openEdit(s)">Tahrir</button>
                <button class="btn btn-sm btn-danger" @click="remove(s)">O'chirish</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>

    <Modal v-if="showModal" :title="editing ? 'Xizmatni tahrirlash' : 'Yangi xizmat'" @close="showModal = false">
      <form @submit.prevent="save">
        <div v-if="formError" class="alert alert-error">{{ formError }}</div>
        <div class="field">
          <label>Rasm</label>
          <ImageUpload v-model="form.image" :size="88" />
        </div>
        <div class="field">
          <label>Nomi</label>
          <input v-model="form.name" placeholder="Soch olish" required />
        </div>
        <div class="field-row">
          <div class="field">
            <label>Davomiyligi (daqiqa)</label>
            <input v-model.number="form.duration_min" type="number" min="5" step="5" required />
          </div>
          <div class="field">
            <label>Kategoriya</label>
            <select v-model="form.category_id">
              <option value="">—</option>
              <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
            </select>
          </div>
        </div>
        <div class="field-row">
          <div class="field">
            <label>Narxi (so'm)</label>
            <input v-model="form.price_som" type="number" min="0" step="1000" placeholder="50000" required />
          </div>
          <div class="field">
            <label>Depozit (so'm)</label>
            <input v-model="form.deposit_som" type="number" min="0" step="1000" placeholder="0" />
          </div>
        </div>
        <label class="row" style="gap: 8px; cursor: pointer">
          <input v-model="form.is_active" type="checkbox" style="width: auto" />
          <span>Faol (bookingda ko'rinadi)</span>
        </label>
        <label class="row" style="gap: 8px; cursor: pointer; margin-top: 10px">
          <input v-model="form.online_bookable" type="checkbox" style="width: auto" />
          <span>Onlayn bron (mijoz saytdan yozila oladi)</span>
        </label>
      </form>
      <template #footer>
        <button class="btn" @click="showModal = false">Bekor</button>
        <button class="btn btn-primary" :disabled="saving" @click="save">
          {{ saving ? 'Saqlanmoqda…' : 'Saqlash' }}
        </button>
      </template>
    </Modal>

    <Modal v-if="catModal" :title="editingCat ? 'Kategoriyani tahrirlash' : 'Yangi kategoriya'" @close="catModal = false">
      <form @submit.prevent="saveCat">
        <div v-if="catError" class="alert alert-error">{{ catError }}</div>
        <div class="field">
          <label>Rasm</label>
          <ImageUpload v-model="catForm.image" :size="88" />
        </div>
        <div class="field">
          <label>Nomi</label>
          <input v-model="catForm.name" placeholder="Tortlar" required />
        </div>
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
.cat-panel {
  margin-bottom: 16px;
  padding: 16px;
}
.cat-panel-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}
.cat-panel-head h3 {
  margin: 0;
  font-size: 16px;
}
.cat-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.cat-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 8px 6px 6px;
  border: 1px solid var(--border);
  border-radius: 10px;
}
.cat-thumb {
  width: 34px;
  height: 34px;
  border-radius: 8px;
  object-fit: cover;
  flex-shrink: 0;
}
.cat-thumb.ph {
  display: grid;
  place-items: center;
  background: var(--primary-soft);
  color: var(--primary);
  font-weight: 700;
}
.cat-name {
  font-weight: 600;
  font-size: 14px;
}
.icon-btn {
  border: none;
  background: transparent;
  color: var(--text-muted);
  cursor: pointer;
  padding: 4px;
  border-radius: 6px;
  display: inline-flex;
}
.icon-btn:hover {
  background: var(--surface-2);
  color: var(--text);
}
.icon-btn.del:hover {
  color: var(--danger, #ef4444);
}
.row-thumb {
  width: 34px;
  height: 34px;
  border-radius: 8px;
  object-fit: cover;
}
.row-thumb.ph {
  display: grid;
  place-items: center;
  background: var(--primary-soft);
  color: var(--primary);
  font-weight: 700;
  font-size: 14px;
}
</style>
