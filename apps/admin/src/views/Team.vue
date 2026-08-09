<script setup>
import { ref, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { useAuthStore } from '../stores/auth'
import { confirm } from '../composables/useConfirm'
import Modal from '../components/Modal.vue'
import PhoneInput from '../components/PhoneInput.vue'

const auth = useAuthStore()

const ROLE_LABELS = {
  business_owner: 'Egasi',
  business_admin: 'Administrator',
  staff: 'Xodim',
}
const ROLE_OPTIONS = [
  { value: 'business_owner', label: 'Egasi' },
  { value: 'business_admin', label: 'Administrator' },
  { value: 'staff', label: 'Xodim' },
]

const loading = ref(true)
const error = ref('')
const members = ref([])

const isOwner = computed(() => auth.role === 'business_owner')
const currentUserId = computed(() => auth.user?.id ?? null)
const ownerCount = computed(
  () => members.value.filter((m) => m.role === 'business_owner').length,
)

// The last remaining owner may not be removed or demoted.
function isLastOwner(m) {
  return m.role === 'business_owner' && ownerCount.value <= 1
}

function roleLabel(role) {
  return ROLE_LABELS[role] || role
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const res = await api.get('/v1/team')
    members.value = Array.isArray(res) ? res : res?.items || []
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Yuklab bo\'lmadi'
  } finally {
    loading.value = false
  }
}

// ---- Add member modal ----
const showModal = ref(false)
const saving = ref(false)
const formError = ref('')
const form = ref(blank())

function blank() {
  return { phone: '', name: '', role: 'staff', password: '' }
}

function openCreate() {
  form.value = blank()
  formError.value = ''
  showModal.value = true
}

async function save() {
  formError.value = ''
  if (!form.value.phone.trim()) {
    formError.value = 'Telefon raqamini kiriting'
    return
  }
  saving.value = true
  try {
    const payload = {
      phone: form.value.phone.trim(),
      role: form.value.role,
    }
    const name = form.value.name.trim()
    if (name) payload.name = name
    const password = form.value.password.trim()
    if (password) payload.password = password

    await api.post('/v1/team', payload)
    showModal.value = false
    await load()
  } catch (e) {
    formError.value = e instanceof ApiError ? e.message : 'Saqlab bo\'lmadi'
  } finally {
    saving.value = false
  }
}

// ---- Inline role change ----
const savingRole = ref(null)

async function changeRole(m, newRole) {
  if (newRole === m.role) return
  error.value = ''
  savingRole.value = m.user_id
  const prev = m.role
  try {
    await api.patch('/v1/team/' + m.user_id, { role: newRole })
    m.role = newRole
  } catch (e) {
    m.role = prev // revert on failure
    error.value = e instanceof ApiError ? e.message : 'Rolni o\'zgartirib bo\'lmadi'
  } finally {
    savingRole.value = null
  }
}

// ---- Remove member ----
const removing = ref(null)

async function remove(m) {
  if (!(await confirm({ message: `"${m.name || m.phone}" jamoadan chiqarilsinmi?`, danger: true, confirmText: 'Chiqarish' }))) return
  error.value = ''
  removing.value = m.user_id
  try {
    await api.del('/v1/team/' + m.user_id)
    await load()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Chiqarib bo\'lmadi'
  } finally {
    removing.value = null
  }
}

onMounted(load)
</script>

<template>
  <div>
    <div class="page-head">
      <h1>Jamoa</h1>
      <button v-if="isOwner" class="btn btn-primary" @click="openCreate">+ A'zo qo'shish</button>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>
    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

    <template v-else>
      <div v-if="!members.length" class="empty card">
        Jamoada hali a'zo yo'q.
        <a v-if="isOwner" href="#" @click.prevent="openCreate">Birinchisini qo'shing</a>.
      </div>

      <div v-else class="table-wrap">
        <table class="data">
          <thead>
            <tr>
              <th>Ism</th>
              <th>Telefon</th>
              <th>Rol</th>
              <th v-if="isOwner"></th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="m in members"
              :key="m.user_id"
              :class="{ 'is-me': m.user_id === currentUserId }"
            >
              <td>
                <strong>{{ m.name || '—' }}</strong>
                <span v-if="m.user_id === currentUserId" class="badge confirmed me-badge">Siz</span>
              </td>
              <td>{{ m.phone }}</td>
              <td>
                <!-- Owner may re-assign roles inline, except demoting the last owner. -->
                <select
                  v-if="isOwner"
                  :value="m.role"
                  :disabled="savingRole === m.user_id || isLastOwner(m)"
                  :title="isLastOwner(m) ? 'Oxirgi egani o\'zgartirib bo\'lmaydi' : ''"
                  class="role-select"
                  @change="changeRole(m, $event.target.value)"
                >
                  <option v-for="o in ROLE_OPTIONS" :key="o.value" :value="o.value">
                    {{ o.label }}
                  </option>
                </select>
                <span v-else class="badge" :class="m.role === 'business_owner' ? 'completed' : 'confirmed'">
                  {{ roleLabel(m.role) }}
                </span>
              </td>
              <td v-if="isOwner" style="text-align: right">
                <button
                  class="btn btn-sm btn-danger"
                  :disabled="removing === m.user_id || isLastOwner(m)"
                  :title="isLastOwner(m) ? 'Oxirgi egani chiqarib bo\'lmaydi' : ''"
                  @click="remove(m)"
                >
                  {{ removing === m.user_id ? '…' : 'Chiqarish' }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>

    <Modal v-if="showModal" title="Jamoaga a'zo qo'shish" @close="showModal = false">
      <form @submit.prevent="save">
        <div v-if="formError" class="alert alert-error">{{ formError }}</div>
        <div class="field">
          <label>Telefon</label>
          <PhoneInput v-model="form.phone" />
        </div>
        <div class="field">
          <label>Ism</label>
          <input v-model="form.name" placeholder="Dilnoza Rahimova" />
        </div>
        <div class="field">
          <label>Rol</label>
          <select v-model="form.role">
            <option v-for="o in ROLE_OPTIONS" :key="o.value" :value="o.value">
              {{ o.label }}
            </option>
          </select>
        </div>
        <div class="field">
          <label>Parol</label>
          <input v-model="form.password" type="password" autocomplete="new-password" placeholder="Yangi foydalanuvchi uchun" />
          <small class="muted">Agar bu raqam bilan foydalanuvchi hali mavjud bo'lmasa, parol majburiy.</small>
        </div>
      </form>
      <template #footer>
        <button class="btn" @click="showModal = false">Bekor</button>
        <button class="btn btn-primary" :disabled="saving" @click="save">
          {{ saving ? 'Saqlanmoqda…' : 'Qo\'shish' }}
        </button>
      </template>
    </Modal>
  </div>
</template>

<style scoped>
.me-badge {
  margin-left: 8px;
}
.is-me {
  background: var(--surface-2, rgba(255, 255, 255, 0.03));
}
.role-select {
  min-width: 150px;
}
.field small.muted {
  display: block;
  margin-top: 4px;
  font-size: 12px;
}
</style>
