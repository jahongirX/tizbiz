<script setup>
import { ref, reactive, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { Plus, Pencil, Trash2 } from 'lucide-vue-next'

const loading = ref(true)
const items = ref([])
const search = ref('')

const modal = ref(false)
const editing = ref(null)
const form = reactive({ name: '', phone: '', note: '' })
const saving = ref(false)
const error = ref('')

async function load() {
  loading.value = true
  try {
    const q = search.value.trim() ? '?q=' + encodeURIComponent(search.value.trim()) : ''
    items.value = await api.get('/v1/sms/contacts' + q)
  } finally {
    loading.value = false
  }
}
onMounted(load)

function openNew() {
  editing.value = null
  Object.assign(form, { name: '', phone: '', note: '' })
  error.value = ''
  modal.value = true
}
function openEdit(c) {
  editing.value = c
  Object.assign(form, { name: c.name, phone: c.phone, note: c.note || '' })
  error.value = ''
  modal.value = true
}

async function save() {
  error.value = ''
  if (!form.name.trim()) { error.value = 'Ism kiriting'; return }
  if (!form.phone.trim()) { error.value = 'Raqam kiriting'; return }
  saving.value = true
  try {
    const payload = { name: form.name.trim(), phone: form.phone.trim(), note: form.note.trim() }
    if (editing.value) await api.patch('/v1/sms/contacts/' + editing.value.id, payload)
    else await api.post('/v1/sms/contacts', payload)
    modal.value = false
    await load()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Saqlab bo‘lmadi'
  } finally {
    saving.value = false
  }
}

async function remove(c) {
  if (!confirm(`"${c.name}" kontaktini o‘chirasizmi?`)) return
  await api.del('/v1/sms/contacts/' + c.id)
  await load()
}
</script>

<template>
  <div class="page-head">
    <h2>Kontaktlar <span class="muted" style="font-size: 15px; font-weight: 500">({{ items.length }})</span></h2>
    <button class="btn" @click="openNew"><Plus :size="16" /> Kontakt qo‘shish</button>
  </div>

  <div class="card" style="margin-bottom: 16px">
    <div class="row" style="gap: 12px">
      <input v-model="search" style="flex: 1" placeholder="Ism yoki raqam bo‘yicha qidirish" @keyup.enter="load" />
      <button class="btn" @click="load">Qidirish</button>
    </div>
  </div>

  <div v-if="loading" class="spinner"></div>

  <div v-else-if="!items.length" class="card empty">Kontakt topilmadi.</div>

  <div v-else class="table-wrap">
    <table class="table">
      <thead>
        <tr><th>Ism</th><th>Raqam</th><th>Izoh</th><th></th></tr>
      </thead>
      <tbody>
        <tr v-for="c in items" :key="c.id">
          <td style="font-weight: 600">{{ c.name }}</td>
          <td class="muted" style="white-space: nowrap">{{ c.phone }}</td>
          <td class="muted">{{ c.note || '—' }}</td>
          <td>
            <div class="row" style="gap: 6px; justify-content: flex-end">
              <button class="btn ghost sm" @click="openEdit(c)"><Pencil :size="14" /></button>
              <button class="btn ghost sm" style="color: var(--danger)" @click="remove(c)"><Trash2 :size="14" /></button>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
  </div>

  <!-- Add/edit modal -->
  <div v-if="modal" class="modal-back" @click.self="modal = false">
    <div class="modal">
      <h3>{{ editing ? 'Kontaktni tahrirlash' : 'Yangi kontakt' }}</h3>
      <div v-if="error" class="alert err">{{ error }}</div>
      <div class="field">
        <label>Ism</label>
        <input v-model="form.name" placeholder="Ali Valiyev" />
      </div>
      <div class="field">
        <label>Raqam</label>
        <input v-model="form.phone" placeholder="+998901234567" />
      </div>
      <div class="field">
        <label>Izoh (ixtiyoriy)</label>
        <input v-model="form.note" placeholder="Mijoz, VIP…" />
      </div>
      <div class="row" style="justify-content: flex-end; gap: 10px">
        <button class="btn ghost" @click="modal = false">Bekor</button>
        <button class="btn" :disabled="saving" @click="save">{{ saving ? 'Saqlanmoqda…' : 'Saqlash' }}</button>
      </div>
    </div>
  </div>
</template>
