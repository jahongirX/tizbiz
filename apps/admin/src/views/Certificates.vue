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

const statusLabels = { active: 'Faol', used: 'Ishlatilgan', void: 'Bekor' }
const statusBadge = { active: 'completed', used: 'canceled', void: 'no_show' }

const showModal = ref(false)
const saving = ref(false)
const formError = ref('')
const editing = ref(null)
const form = ref(blank())

function blank() {
  return { code: '', name: '', value_som: '', expires_at: '', status: 'active' }
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const res = await api.get('/v1/certificates')
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

function openEdit(c) {
  editing.value = c
  form.value = {
    code: c.code || '',
    name: c.name || '',
    value_som: c.value_tiyin != null ? tiyinToSom(c.value_tiyin) : '',
    expires_at: c.expires_at ? String(c.expires_at).slice(0, 10) : '',
    status: c.status || 'active',
  }
  formError.value = ''
  showModal.value = true
}

async function save() {
  formError.value = ''
  if (!form.value.code.trim()) {
    formError.value = 'Kodni kiriting'
    return
  }
  saving.value = true
  try {
    const payload = {
      code: form.value.code.trim(),
      name: form.value.name.trim(),
      value_tiyin: form.value.value_som === '' ? 0 : somToTiyin(form.value.value_som),
      expires_at: form.value.expires_at || null,
      status: form.value.status,
    }
    if (editing.value) {
      await api.patch('/v1/certificates/' + editing.value.id, payload)
    } else {
      await api.post('/v1/certificates', payload)
    }
    showModal.value = false
    await load()
  } catch (e) {
    formError.value = e instanceof ApiError ? e.message : 'Saqlab bo\'lmadi'
  } finally {
    saving.value = false
  }
}

async function remove(c) {
  if (!(await confirm({ message: `"${c.code}" sertifikatini o'chirilsinmi?`, danger: true, confirmText: 'O‘chirish' }))) return
  try {
    await api.del('/v1/certificates/' + c.id)
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
      <h1>Sertifikatlar</h1>
      <button class="btn btn-primary" @click="openCreate">+ Yangi sertifikat</button>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>
    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

    <template v-else>
      <div v-if="!rows.length" class="empty card">
        Hali sertifikat yo'q. <a href="#" @click.prevent="openCreate">Birinchisini qo'shing</a>.
      </div>

      <div v-else class="table-wrap">
        <table class="data">
          <thead>
            <tr>
              <th>Kod</th>
              <th>Nomi</th>
              <th style="text-align: right">Nominal</th>
              <th style="text-align: right">Qoldiq</th>
              <th>Holat</th>
              <th>Amal muddati</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="c in rows" :key="c.id">
              <td><strong>{{ c.code }}</strong></td>
              <td>{{ c.name || '—' }}</td>
              <td style="text-align: right">{{ formatSom(c.value_tiyin) }}</td>
              <td style="text-align: right">{{ formatSom(c.balance_tiyin) }}</td>
              <td>
                <span class="badge" :class="statusBadge[c.status] || 'canceled'">
                  {{ statusLabels[c.status] || c.status }}
                </span>
              </td>
              <td>{{ c.expires_at ? String(c.expires_at).slice(0, 10) : '—' }}</td>
              <td style="text-align: right; white-space: nowrap">
                <button class="btn btn-sm btn-ghost" @click="openEdit(c)">Tahrir</button>
                <button class="btn btn-sm btn-danger" @click="remove(c)">O'chirish</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>

    <Modal
      v-if="showModal"
      :title="editing ? 'Sertifikatni tahrirlash' : 'Yangi sertifikat'"
      @close="showModal = false"
    >
      <form @submit.prevent="save">
        <div v-if="formError" class="alert alert-error">{{ formError }}</div>
        <div class="field">
          <label>Kod</label>
          <input v-model="form.code" placeholder="SERT-2026-001" />
        </div>
        <div class="field">
          <label>Nomi</label>
          <input v-model="form.name" placeholder="Sovg'a sertifikati" />
        </div>
        <div class="field-row">
          <div class="field">
            <label>Nominal (so'm)</label>
            <input v-model="form.value_som" type="number" min="0" step="1000" placeholder="500000" />
          </div>
          <div class="field">
            <label>Amal muddati</label>
            <input v-model="form.expires_at" type="date" />
          </div>
        </div>
        <div class="field">
          <label>Holat</label>
          <select v-model="form.status">
            <option value="active">Faol</option>
            <option value="used">Ishlatilgan</option>
            <option value="void">Bekor</option>
          </select>
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
