<script setup>
import { ref, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { confirm } from '../composables/useConfirm'
import Modal from '../components/Modal.vue'

const loading = ref(true)
const error = ref('')
const staff = ref([])

const showModal = ref(false)
const saving = ref(false)
const formError = ref('')
const editing = ref(null)
const form = ref(blank())

function blank() {
  return { name: '', specialization: '', is_active: true }
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const res = await api.get('/v1/staff')
    staff.value = Array.isArray(res) ? res : res?.items || []
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
  form.value = { name: s.name, specialization: s.specialization || '', is_active: s.is_active !== false }
  formError.value = ''
  showModal.value = true
}

async function save() {
  formError.value = ''
  saving.value = true
  try {
    const payload = {
      name: form.value.name.trim(),
      specialization: form.value.specialization.trim() || null,
      is_active: form.value.is_active,
    }
    if (editing.value) await api.patch('/v1/staff/' + editing.value.id, payload)
    else await api.post('/v1/staff', payload)
    showModal.value = false
    await load()
  } catch (e) {
    formError.value = e instanceof ApiError ? e.message : 'Saqlab bo\'lmadi'
  } finally {
    saving.value = false
  }
}

async function remove(s) {
  if (!(await confirm({ message: `"${s.name}" xodimini o'chirilsinmi?`, danger: true, confirmText: 'O‘chirish' }))) return
  try {
    await api.del('/v1/staff/' + s.id)
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
      <h1>Xodimlar</h1>
      <button class="btn btn-primary" @click="openCreate">+ Yangi xodim</button>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>
    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

    <template v-else>
      <div v-if="!staff.length" class="empty card">
        Hali xodim qo'shilmagan. <a href="#" @click.prevent="openCreate">Birinchisini qo'shing</a>.
      </div>

      <div v-else class="table-wrap">
        <table class="data">
          <thead>
            <tr>
              <th>Ismi</th>
              <th>Mutaxassisligi</th>
              <th>Holat</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="s in staff" :key="s.id">
              <td><strong>{{ s.name }}</strong></td>
              <td>{{ s.specialization || '—' }}</td>
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

    <Modal v-if="showModal" :title="editing ? 'Xodimni tahrirlash' : 'Yangi xodim'" @close="showModal = false">
      <form @submit.prevent="save">
        <div v-if="formError" class="alert alert-error">{{ formError }}</div>
        <div class="field">
          <label>Ismi</label>
          <input v-model="form.name" placeholder="Dilnoza Rahimova" required />
        </div>
        <div class="field">
          <label>Mutaxassisligi</label>
          <input v-model="form.specialization" placeholder="Usta / Shifokor / Registratura" />
        </div>
        <label class="row" style="gap: 8px; cursor: pointer">
          <input v-model="form.is_active" type="checkbox" style="width: auto" />
          <span>Faol</span>
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
