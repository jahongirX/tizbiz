<script setup>
import { ref, reactive, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { Plus, Pencil, Trash2 } from 'lucide-vue-next'

const loading = ref(true)
const items = ref([])

const modal = ref(false)
const editing = ref(null)
const form = reactive({ name: '', text: '' })
const saving = ref(false)
const error = ref('')

async function load() {
  loading.value = true
  try {
    items.value = await api.get('/v1/sms/templates')
  } finally {
    loading.value = false
  }
}
onMounted(load)

function openNew() {
  editing.value = null
  Object.assign(form, { name: '', text: '' })
  error.value = ''
  modal.value = true
}
function openEdit(t) {
  editing.value = t
  Object.assign(form, { name: t.name, text: t.text })
  error.value = ''
  modal.value = true
}

async function save() {
  error.value = ''
  if (!form.name.trim()) { error.value = 'Nom kiriting'; return }
  if (!form.text.trim()) { error.value = 'Matn kiriting'; return }
  saving.value = true
  try {
    const payload = { name: form.name.trim(), text: form.text.trim() }
    if (editing.value) await api.patch('/v1/sms/templates/' + editing.value.id, payload)
    else await api.post('/v1/sms/templates', payload)
    modal.value = false
    await load()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Saqlab bo‘lmadi'
  } finally {
    saving.value = false
  }
}

async function remove(t) {
  if (!confirm(`"${t.name}" shablonini o‘chirasizmi?`)) return
  await api.del('/v1/sms/templates/' + t.id)
  await load()
}
</script>

<template>
  <div class="page-head">
    <h2>Shablonlar</h2>
    <button class="btn" @click="openNew"><Plus :size="16" /> Shablon qo‘shish</button>
  </div>

  <div v-if="loading" class="spinner"></div>

  <div v-else-if="!items.length" class="card empty">
    Hali shablon yo‘q. Tez-tez yuboradigan matnlarni shablon qilib saqlang — xabar yozishda bir bosishda qo‘yiladi.
  </div>

  <div v-else class="grid" style="gap: 12px">
    <div v-for="t in items" :key="t.id" class="card" style="display: flex; gap: 12px; align-items: flex-start">
      <div style="flex: 1; min-width: 0">
        <div style="font-weight: 600; margin-bottom: 4px">{{ t.name }}</div>
        <div class="muted" style="font-size: 13px; white-space: pre-wrap">{{ t.text }}</div>
      </div>
      <div class="row" style="gap: 6px">
        <button class="btn ghost sm" @click="openEdit(t)"><Pencil :size="14" /></button>
        <button class="btn ghost sm" style="color: var(--danger)" @click="remove(t)"><Trash2 :size="14" /></button>
      </div>
    </div>
  </div>

  <!-- Add/edit modal -->
  <div v-if="modal" class="modal-back" @click.self="modal = false">
    <div class="modal">
      <h3>{{ editing ? 'Shablonni tahrirlash' : 'Yangi shablon' }}</h3>
      <div v-if="error" class="alert err">{{ error }}</div>
      <div class="field">
        <label>Nom</label>
        <input v-model="form.name" placeholder="Eslatma" />
      </div>
      <div class="field">
        <label>Matn</label>
        <textarea v-model="form.text" maxlength="1000" placeholder="Xabar matni…"></textarea>
        <p class="muted" style="font-size: 12px; margin: 6px 0 0">{{ form.text.length }} belgi</p>
      </div>
      <div class="row" style="justify-content: flex-end; gap: 10px">
        <button class="btn ghost" @click="modal = false">Bekor</button>
        <button class="btn" :disabled="saving" @click="save">{{ saving ? 'Saqlanmoqda…' : 'Saqlash' }}</button>
      </div>
    </div>
  </div>
</template>
