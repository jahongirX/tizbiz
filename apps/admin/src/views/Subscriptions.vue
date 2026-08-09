<script setup>
import { ref, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { api, ApiError } from '@navbat/api-client'
import { somToTiyin, tiyinToSom, formatSom } from '../lib/money'
import { confirm } from '../composables/useConfirm'
import Modal from '../components/Modal.vue'

const loading = ref(true)
const error = ref('')
const rows = ref([])

const showModal = ref(false)
const saving = ref(false)
const formError = ref('')
const editing = ref(null)
const form = ref(blank())

function blank() {
  return { name: '', visits: 1, price_som: '', valid_days: 30, is_active: true }
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const res = await api.get('/v1/subscription-types')
    rows.value = Array.isArray(res) ? res : res?.items || []
  } catch (e) {
    rows.value = []
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
    name: s.name || '',
    visits: s.visits ?? 1,
    price_som: s.price_tiyin != null ? tiyinToSom(s.price_tiyin) : '',
    valid_days: s.valid_days ?? 30,
    is_active: s.is_active !== false,
  }
  formError.value = ''
  showModal.value = true
}

async function save() {
  formError.value = ''
  if (!form.value.name.trim()) {
    formError.value = 'Nomni kiriting'
    return
  }
  saving.value = true
  try {
    const payload = {
      name: form.value.name.trim(),
      visits: Number(form.value.visits) || 0,
      price_tiyin: form.value.price_som === '' ? 0 : somToTiyin(form.value.price_som),
      valid_days: Number(form.value.valid_days) || 0,
      is_active: form.value.is_active,
    }
    if (editing.value) {
      await api.patch('/v1/subscription-types/' + editing.value.id, payload)
    } else {
      await api.post('/v1/subscription-types', payload)
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
  if (!(await confirm({ message: `"${s.name}" abonementini o'chirilsinmi?`, danger: true, confirmText: 'O‘chirish' }))) return
  try {
    await api.del('/v1/subscription-types/' + s.id)
    await load()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'O\'chirib bo\'lmadi'
  }
}

onMounted(load)
</script>

<template>
  <div>
    <RouterLink to="/loyalty" class="back-link">← Loyallik</RouterLink>

    <div class="page-head">
      <h1>Abonementlar</h1>
      <button class="btn btn-primary" @click="openCreate">+ Yangi abonement</button>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>
    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

    <template v-else>
      <div v-if="!rows.length" class="empty card">
        Hali abonement yo'q. <a href="#" @click.prevent="openCreate">Birinchisini qo'shing</a>.
      </div>

      <div v-else class="table-wrap">
        <table class="data">
          <thead>
            <tr>
              <th>Nomi</th>
              <th style="text-align: right">Tashriflar</th>
              <th style="text-align: right">Narxi</th>
              <th>Amal muddati</th>
              <th>Faol</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="s in rows" :key="s.id">
              <td><strong>{{ s.name }}</strong></td>
              <td style="text-align: right">{{ s.visits }}</td>
              <td style="text-align: right">{{ formatSom(s.price_tiyin) }}</td>
              <td>{{ s.valid_days }} kun</td>
              <td>
                <span class="badge" :class="s.is_active !== false ? 'completed' : 'canceled'">
                  {{ s.is_active !== false ? 'Faol' : 'Nofaol' }}
                </span>
              </td>
              <td style="text-align: right; white-space: nowrap">
                <button class="btn btn-sm btn-ghost" @click="openEdit(s)">Tahrir</button>
                <button class="btn btn-sm btn-danger" @click="remove(s)">O'chirish</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>

    <Modal
      v-if="showModal"
      :title="editing ? 'Abonementni tahrirlash' : 'Yangi abonement'"
      @close="showModal = false"
    >
      <form @submit.prevent="save">
        <div v-if="formError" class="alert alert-error">{{ formError }}</div>
        <div class="field">
          <label>Nomi</label>
          <input v-model="form.name" placeholder="10 tashrif paketi" />
        </div>
        <div class="field-row">
          <div class="field">
            <label>Tashriflar soni</label>
            <input v-model.number="form.visits" type="number" min="1" step="1" />
          </div>
          <div class="field">
            <label>Narxi (so'm)</label>
            <input v-model="form.price_som" type="number" min="0" step="1000" placeholder="500000" />
          </div>
        </div>
        <div class="field">
          <label>Amal muddati (kun)</label>
          <input v-model.number="form.valid_days" type="number" min="1" step="1" />
        </div>
        <label class="row" style="gap: 8px; cursor: pointer">
          <input v-model="form.is_active" type="checkbox" style="width: auto" />
          <span>Faol (sotuvda ko'rinadi)</span>
        </label>
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
.back-link {
  display: inline-block;
  margin-bottom: 12px;
  font-size: 13px;
  font-weight: 600;
  color: var(--text-muted);
  text-decoration: none;
}
.back-link:hover {
  color: var(--primary);
}
</style>
