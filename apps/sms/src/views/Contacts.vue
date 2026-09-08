<script setup>
import { ref, reactive, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { Plus, Pencil, Trash2, Upload, Download, FileText } from 'lucide-vue-next'

const loading = ref(true)
const items = ref([])
const search = ref('')
const categories = ref([])
const categoryFilter = ref('')

const modal = ref(false)
const editing = ref(null)
const form = reactive({ name: '', phone: '', note: '', category: '' })
const saving = ref(false)
const error = ref('')

async function load() {
  loading.value = true
  try {
    const params = new URLSearchParams()
    if (search.value.trim()) params.set('q', search.value.trim())
    if (categoryFilter.value) params.set('category', categoryFilter.value)
    const qs = params.toString()
    items.value = await api.get('/v1/sms/contacts' + (qs ? '?' + qs : ''))
  } finally {
    loading.value = false
  }
}
async function loadCategories() {
  categories.value = await api.get('/v1/sms/contacts/categories').catch(() => [])
}
onMounted(async () => {
  await Promise.all([load(), loadCategories()])
})

function openNew() {
  editing.value = null
  Object.assign(form, { name: '', phone: '', note: '', category: categoryFilter.value || '' })
  error.value = ''
  modal.value = true
}
function openEdit(c) {
  editing.value = c
  Object.assign(form, { name: c.name, phone: c.phone, note: c.note || '', category: c.category || '' })
  error.value = ''
  modal.value = true
}

async function save() {
  error.value = ''
  if (!form.name.trim()) { error.value = 'Ism kiriting'; return }
  if (!form.phone.trim()) { error.value = 'Raqam kiriting'; return }
  saving.value = true
  try {
    const payload = {
      name: form.name.trim(),
      phone: form.phone.trim(),
      note: form.note.trim(),
      category: form.category.trim(),
    }
    if (editing.value) await api.patch('/v1/sms/contacts/' + editing.value.id, payload)
    else await api.post('/v1/sms/contacts', payload)
    modal.value = false
    await Promise.all([load(), loadCategories()])
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Saqlab bo‘lmadi'
  } finally {
    saving.value = false
  }
}

async function remove(c) {
  if (!confirm(`"${c.name}" kontaktini o‘chirasizmi?`)) return
  await api.del('/v1/sms/contacts/' + c.id)
  await Promise.all([load(), loadCategories()])
}

// ---- Import / Export (CSV) ----
const fileInput = ref(null)
const notice = ref('')

function csvCell(v) {
  const s = String(v ?? '')
  return /[",\n;]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s
}
function downloadCsv(name, rows) {
  const csv = rows.map((r) => r.map(csvCell).join(',')).join('\n')
  const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = name
  a.click()
  URL.revokeObjectURL(url)
}
function exportCsv() {
  downloadCsv('kontaktlar.csv', [
    ['name', 'phone', 'note', 'category'],
    ...items.value.map((c) => [c.name, c.phone, c.note || '', c.category || '']),
  ])
}
function downloadTemplate() {
  downloadCsv('kontaktlar-namuna.csv', [
    ['name', 'phone', 'note', 'category'],
    ['Ali Valiyev', '+998901234567', 'VIP mijoz', 'Mijozlar'],
    ['Vali Aliyev', '998907654321', '', 'Hamkorlar'],
    ['', '+998935556677', '', ''],
  ])
}

/** Parse CSV/TXT: columns name,phone,note,category — or a single phone per line. */
function parseContacts(textData) {
  const out = []
  const lines = textData.split(/\r?\n/).map((l) => l.trim()).filter(Boolean)
  for (const line of lines) {
    const cols = line.split(/[,;\t]/).map((c) => c.trim().replace(/^"|"$/g, ''))
    if (!out.length && /^(name|ism|phone|raqam|number|tel|nomer)$/i.test(cols[0])) continue
    let name = '', phone = '', note = '', category = ''
    if (cols.length === 1) {
      phone = cols[0]
    } else {
      const phoneCol = cols.findIndex((c) => /^\+?\d[\d\s\-()]{5,}$/.test(c))
      if (phoneCol === 0) { phone = cols[0]; name = cols[1] || ''; note = cols[2] || ''; category = cols[3] || '' }
      else { name = cols[0]; phone = cols[1]; note = cols[2] || ''; category = cols[3] || '' }
    }
    phone = phone.replace(/[^\d+]/g, '')
    if (phone.replace(/\D/g, '').length >= 7) out.push({ name: name || phone, phone, note, category })
  }
  return out
}

function triggerImport() {
  notice.value = ''
  fileInput.value?.click()
}
async function onImportFile(e) {
  const f = e.target.files?.[0]
  if (!f) return
  try {
    const rows = parseContacts(await f.text())
    e.target.value = ''
    if (!rows.length) { notice.value = 'Faylda raqam topilmadi.'; return }
    const res = await api.post('/v1/sms/contacts/import', { contacts: rows })
    notice.value = `Import: ${res.imported} qo‘shildi, ${res.skipped} o‘tkazib yuborildi.`
    await Promise.all([load(), loadCategories()])
  } catch (err) {
    notice.value = err instanceof ApiError ? err.message : 'Import xatosi'
  }
}
</script>

<template>
  <div class="page-head">
    <h2>Kontaktlar <span class="muted" style="font-size: 15px; font-weight: 500">({{ items.length }})</span></h2>
    <div class="row" style="gap: 8px; flex-wrap: wrap">
      <button class="btn ghost" @click="downloadTemplate"><FileText :size="16" /> Namuna</button>
      <button class="btn ghost" @click="triggerImport"><Upload :size="16" /> Import</button>
      <button class="btn ghost" :disabled="!items.length" @click="exportCsv"><Download :size="16" /> Export</button>
      <button class="btn" @click="openNew"><Plus :size="16" /> Kontakt qo‘shish</button>
      <input ref="fileInput" type="file" accept=".csv,.txt,text/csv,text/plain" hidden @change="onImportFile" />
    </div>
  </div>

  <div v-if="notice" class="alert ok" style="margin-bottom: 12px">{{ notice }}</div>

  <div class="card" style="margin-bottom: 16px">
    <div class="row" style="gap: 12px; flex-wrap: wrap">
      <select v-if="categories.length" v-model="categoryFilter" style="width: auto; min-width: 160px" @change="load">
        <option value="">Barcha kategoriya</option>
        <option v-for="c in categories" :key="c" :value="c">{{ c }}</option>
      </select>
      <input v-model="search" style="flex: 1; min-width: 200px" placeholder="Ism yoki raqam bo‘yicha qidirish" @keyup.enter="load" />
      <button class="btn" @click="load">Qidirish</button>
    </div>
  </div>

  <div v-if="loading" class="spinner"></div>

  <div v-else-if="!items.length" class="card empty">Kontakt topilmadi.</div>

  <div v-else class="table-wrap">
    <table class="table">
      <thead>
        <tr><th>Ism</th><th>Raqam</th><th>Kategoriya</th><th>Izoh</th><th></th></tr>
      </thead>
      <tbody>
        <tr v-for="c in items" :key="c.id">
          <td style="font-weight: 600">{{ c.name }}</td>
          <td class="muted" style="white-space: nowrap">{{ c.phone }}</td>
          <td><span v-if="c.category" class="cat-badge">{{ c.category }}</span><span v-else class="muted">—</span></td>
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
        <label>Kategoriya (ixtiyoriy)</label>
        <input v-model="form.category" list="cat-options" placeholder="Mijozlar, Hamkorlar…" />
        <datalist id="cat-options">
          <option v-for="c in categories" :key="c" :value="c" />
        </datalist>
      </div>
      <div class="field">
        <label>Izoh (ixtiyoriy)</label>
        <input v-model="form.note" placeholder="VIP, eslatma…" />
      </div>
      <div class="row" style="justify-content: flex-end; gap: 10px">
        <button class="btn ghost" @click="modal = false">Bekor</button>
        <button class="btn" :disabled="saving" @click="save">{{ saving ? 'Saqlanmoqda…' : 'Saqlash' }}</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.cat-badge {
  display: inline-block;
  padding: 2px 10px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 600;
  background: rgba(45, 126, 236, 0.16);
  color: var(--brand-2, #6fa8f5);
  white-space: nowrap;
}
</style>
