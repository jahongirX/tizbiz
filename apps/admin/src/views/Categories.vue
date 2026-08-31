<script setup>
import { ref, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { confirm } from '../composables/useConfirm'
import Modal from '../components/Modal.vue'

const loading = ref(true)
const error = ref('')
const rows = ref([])

const showModal = ref(false)
const saving = ref(false)
const formError = ref('')
const editing = ref(null)

// Preset palette for quick picking (dark-friendly hues). Declared before `form`
// so blank() can read presets[0] without hitting its temporal dead zone.
const presets = [
  '#6366f1', '#8b5cf6', '#ec4899', '#ef4444', '#f97316',
  '#f59e0b', '#eab308', '#22c55e', '#10b981', '#14b8a6',
  '#06b6d4', '#3b82f6', '#64748b', '#94a3b8',
]

function blank() {
  return { name: '', color: presets[0], sort: 0 }
}

const form = ref(blank())

async function load() {
  loading.value = true
  error.value = ''
  try {
    const res = await api.get('/v1/client-categories')
    const list = Array.isArray(res?.data) ? res.data : Array.isArray(res) ? res : res?.items || []
    rows.value = [...list].sort((a, b) => (a.sort ?? 0) - (b.sort ?? 0))
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
    name: c.name || '',
    color: c.color || presets[0],
    sort: c.sort ?? 0,
  }
  formError.value = ''
  showModal.value = true
}

async function save() {
  formError.value = ''
  if (!form.value.name.trim()) {
    formError.value = 'Kategoriya nomini kiriting'
    return
  }
  saving.value = true
  try {
    const payload = {
      name: form.value.name.trim(),
      color: form.value.color,
      sort: Number(form.value.sort) || 0,
    }
    if (editing.value) {
      await api.patch('/v1/client-categories/' + editing.value.id, payload)
    } else {
      await api.post('/v1/client-categories', payload)
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
  if (!(await confirm({ message: `"${c.name}" kategoriyasini o'chirilsinmi?`, danger: true, confirmText: 'O‘chirish' }))) return
  try {
    await api.del('/v1/client-categories/' + c.id)
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
      <h1>Kategoriyalar</h1>
      <button class="btn btn-primary" @click="openCreate">+ Yangi kategoriya</button>
    </div>

    <p class="muted" style="margin-top: -6px; margin-bottom: 16px">
      Mijozlarni guruhlash uchun kategoriyalar. Har biriga rang bering.
    </p>

    <div v-if="error" class="alert alert-error">{{ error }}</div>
    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

    <template v-else>
      <div v-if="!rows.length" class="empty card">
        Hali kategoriya qo'shilmagan. <a href="#" @click.prevent="openCreate">Birinchisini qo'shing</a>.
      </div>

      <div v-else class="table-wrap">
        <table class="data">
          <thead>
            <tr>
              <th style="width: 44px"></th>
              <th>Nomi</th>
              <th>Rang</th>
              <th style="text-align: right">Tartib</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="c in rows" :key="c.id">
              <td>
                <span class="swatch" :style="{ background: c.color || '#64748b' }"></span>
              </td>
              <td>
                <span class="cat-chip" :style="{ background: (c.color || '#64748b') + '22', color: c.color || '#94a3b8' }">
                  {{ c.name }}
                </span>
              </td>
              <td><span class="muted">{{ c.color || '—' }}</span></td>
              <td style="text-align: right">{{ c.sort ?? 0 }}</td>
              <td style="text-align: right">
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
      :title="editing ? 'Kategoriyani tahrirlash' : 'Yangi kategoriya'"
      @close="showModal = false"
    >
      <form @submit.prevent="save">
        <div v-if="formError" class="alert alert-error">{{ formError }}</div>
        <div class="field">
          <label>Nomi</label>
          <input v-model="form.name" placeholder="Masalan: VIP" />
        </div>
        <div class="field">
          <label>Rang</label>
          <div class="color-row">
            <input v-model="form.color" type="color" class="color-input" />
            <div class="palette">
              <button
                v-for="p in presets"
                :key="p"
                type="button"
                class="pal-dot"
                :class="{ on: form.color?.toLowerCase() === p }"
                :style="{ background: p }"
                :aria-label="p"
                @click="form.color = p"
              ></button>
            </div>
          </div>
        </div>
        <div class="field">
          <label>Tartib</label>
          <input v-model.number="form.sort" type="number" step="1" placeholder="0" />
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
.swatch {
  display: inline-block;
  width: 20px;
  height: 20px;
  border-radius: 6px;
  border: 1px solid var(--border);
  vertical-align: middle;
}
.cat-chip {
  display: inline-flex;
  align-items: center;
  border-radius: 20px;
  padding: 3px 12px;
  font-size: 12.5px;
  font-weight: 600;
}
.color-row {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}
.color-input {
  width: 46px;
  height: 38px;
  padding: 2px;
  border-radius: 8px;
  cursor: pointer;
  flex-shrink: 0;
}
.palette {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.pal-dot {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  border: 2px solid transparent;
  cursor: pointer;
  padding: 0;
}
.pal-dot.on {
  border-color: var(--text);
  box-shadow: 0 0 0 2px var(--surface);
}
</style>
