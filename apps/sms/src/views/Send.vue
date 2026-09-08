<script setup>
import { ref, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { Send as SendIcon, X, Users, Upload, Search } from 'lucide-vue-next'

const devices = ref([])
const templates = ref([])
const contacts = ref([])
const deviceId = ref('')
const templateId = ref('')

const phones = ref([]) // list of number strings (chips)
const phoneInput = ref('')
const text = ref('')
const sending = ref(false)
const result = ref(null)
const error = ref('')

// contact picker modal
const pickerOpen = ref(false)
const pickerSearch = ref('')
const pickerCategory = ref('')
const picked = ref(new Set())
const fileInput = ref(null)

const pickerCategories = computed(() => {
  const set = new Set()
  contacts.value.forEach((c) => c.category && set.add(c.category))
  return [...set].sort()
})

const contactFiltered = computed(() => {
  const q = pickerSearch.value.trim().toLowerCase()
  const cat = pickerCategory.value
  return contacts.value.filter((c) => {
    if (cat && c.category !== cat) return false
    if (!q) return true
    return c.name.toLowerCase().includes(q) || String(c.phone).includes(q)
  })
})

function normalize(raw) {
  return String(raw || '').replace(/[^\d+]/g, '')
}

/** Add one or many numbers (splits on spaces, commas, semicolons, newlines). */
function addPhones(raw) {
  const parts = String(raw || '').split(/[\s,;]+/)
  for (const part of parts) {
    const p = normalize(part)
    if (p && p.replace(/\D/g, '').length >= 7 && !phones.value.includes(p)) {
      phones.value.push(p)
    }
  }
}

function commitInput() {
  if (phoneInput.value.trim()) {
    addPhones(phoneInput.value)
    phoneInput.value = ''
  }
}
function onKeydown(e) {
  if (e.key === 'Enter' || e.key === ',' || e.key === ' ' || e.key === ';') {
    e.preventDefault()
    commitInput()
  } else if (e.key === 'Backspace' && !phoneInput.value && phones.value.length) {
    phones.value.pop()
  }
}
function onPaste(e) {
  const t = e.clipboardData?.getData('text') || ''
  if (t && /[\s,;]/.test(t)) {
    e.preventDefault()
    addPhones(t)
  }
}
function removePhone(i) {
  phones.value.splice(i, 1)
}
function clearAll() {
  phones.value = []
}

// contact picker
function openPicker() {
  picked.value = new Set()
  pickerSearch.value = ''
  pickerCategory.value = ''
  pickerOpen.value = true
}
function toggle(id) {
  const s = new Set(picked.value)
  s.has(id) ? s.delete(id) : s.add(id)
  picked.value = s
}
function pickAllFiltered() {
  const s = new Set(picked.value)
  contactFiltered.value.forEach((c) => s.add(c.id))
  picked.value = s
}
function addPicked() {
  contacts.value.forEach((c) => {
    if (picked.value.has(c.id)) addPhones(c.phone)
  })
  pickerOpen.value = false
}

// import numbers from a .txt/.csv file into the chips
function triggerFile() {
  fileInput.value?.click()
}
async function onFile(e) {
  const f = e.target.files?.[0]
  if (!f) return
  const txt = await f.text()
  addPhones(txt)
  e.target.value = ''
}

onMounted(async () => {
  const [d, t, c] = await Promise.all([
    api.get('/v1/sms/devices'),
    api.get('/v1/sms/templates').catch(() => []),
    api.get('/v1/sms/contacts').catch(() => []),
  ])
  devices.value = d
  templates.value = t
  contacts.value = c
  const active = devices.value.find((x) => x.is_active)
  if (active) deviceId.value = String(active.id)
})

function applyTemplate() {
  const t = templates.value.find((x) => String(x.id) === templateId.value)
  if (t) text.value = t.text
}

async function send() {
  error.value = ''
  result.value = null
  commitInput()
  if (!phones.value.length) { error.value = 'Kamida bitta raqam kiriting'; return }
  if (!text.value.trim()) { error.value = 'Xabar matnini kiriting'; return }
  sending.value = true
  try {
    result.value = await api.post('/v1/sms/send', {
      device_id: deviceId.value ? Number(deviceId.value) : undefined,
      phones: phones.value,
      text: text.value.trim(),
    })
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Yuborishda xatolik'
  } finally {
    sending.value = false
  }
}
</script>

<template>
  <div class="page-head"><h2>Xabar Yuborish</h2></div>

  <div class="card" style="max-width: 620px">
    <div v-if="error" class="alert err">{{ error }}</div>
    <div v-if="result" class="alert ok">
      Yuborildi: {{ result.sent }} · Xato: {{ result.failed }}<template v-if="result.blocked"> · Qora ro‘yxat: {{ result.blocked }}</template>
    </div>

    <div class="field">
      <label>Server (telefon)</label>
      <select v-model="deviceId">
        <option value="">Birinchi faol server</option>
        <option v-for="d in devices" :key="d.id" :value="String(d.id)">{{ d.name }}</option>
      </select>
      <p v-if="!devices.length" class="muted" style="font-size: 12px; margin: 6px 0 0">
        Avval <RouterLink to="/devices" style="color: var(--brand-2)">Serverlar</RouterLink> bo‘limidan telefon qo‘shing.
      </p>
    </div>

    <div class="field">
      <div class="row" style="justify-content: space-between; align-items: center">
        <label style="margin: 0">Raqamlar</label>
        <div class="row" style="gap: 8px">
          <button type="button" class="btn ghost sm" @click="openPicker"><Users :size="14" /> Kontaktlar</button>
          <button type="button" class="btn ghost sm" @click="triggerFile"><Upload :size="14" /> Import</button>
          <input ref="fileInput" type="file" accept=".txt,.csv,text/plain,text/csv" hidden @change="onFile" />
        </div>
      </div>

      <div class="chips" @click="$refs.chipInput?.focus()">
        <span v-for="(p, i) in phones" :key="p" class="chip">
          {{ p }}
          <button type="button" class="chip-x" @click.stop="removePhone(i)" aria-label="o‘chirish"><X :size="12" /></button>
        </span>
        <input
          ref="chipInput"
          v-model="phoneInput"
          class="chip-input"
          :placeholder="phones.length ? '' : '+998901234567, +998907654321…'"
          inputmode="tel"
          @keydown="onKeydown"
          @paste="onPaste"
          @blur="commitInput"
        />
      </div>

      <div class="row" style="justify-content: space-between; margin-top: 6px">
        <span class="muted" style="font-size: 12px">{{ phones.length }} ta raqam</span>
        <button v-if="phones.length" type="button" class="linkbtn" @click="clearAll">Tozalash</button>
      </div>
      <p class="muted" style="font-size: 11px; margin: 6px 0 0">
        Raqam yozib Enter/vergul bosing yoki ro‘yxatni joylashtiring (paste).
      </p>
    </div>

    <div class="field">
      <label>Xabar</label>
      <select v-if="templates.length" v-model="templateId" style="margin-bottom: 8px" @change="applyTemplate">
        <option value="">Shablondan tanlash…</option>
        <option v-for="t in templates" :key="t.id" :value="String(t.id)">{{ t.name }}</option>
      </select>
      <textarea v-model="text" maxlength="1000" placeholder="Xabar matni…"></textarea>
      <p class="muted" style="font-size: 12px; margin: 6px 0 0">{{ text.length }} belgi</p>
    </div>

    <button class="btn" :disabled="sending || !devices.length" @click="send">
      <SendIcon :size="16" /> {{ sending ? 'Yuborilmoqda…' : 'Yuborish' }}
    </button>
  </div>

  <!-- Contact picker modal -->
  <div v-if="pickerOpen" class="modal-back" @click.self="pickerOpen = false">
    <div class="modal">
      <h3>Kontaktlardan tanlash</h3>
      <div class="field" style="margin-bottom: 10px">
        <div class="row" style="gap: 8px; align-items: center; flex-wrap: wrap">
          <select v-if="pickerCategories.length" v-model="pickerCategory" style="width: auto; min-width: 130px">
            <option value="">Barcha kategoriya</option>
            <option v-for="c in pickerCategories" :key="c" :value="c">{{ c }}</option>
          </select>
          <div style="position: relative; flex: 1; min-width: 140px">
            <Search :size="14" style="position: absolute; left: 10px; top: 50%; transform: translateY(-50%); opacity: 0.5" />
            <input v-model="pickerSearch" placeholder="Qidirish…" style="padding-left: 30px" />
          </div>
          <button type="button" class="btn ghost sm" @click="pickAllFiltered">Hammasi</button>
        </div>
      </div>

      <div v-if="!contacts.length" class="empty" style="padding: 20px 0">
        Kontakt yo‘q. <RouterLink to="/contacts" style="color: var(--brand-2)">Kontaktlar</RouterLink> bo‘limida qo‘shing.
      </div>
      <div v-else class="pick-list">
        <label v-for="c in contactFiltered" :key="c.id" class="pick-row">
          <input type="checkbox" :checked="picked.has(c.id)" @change="toggle(c.id)" />
          <span class="pick-name">{{ c.name }}</span>
          <span v-if="c.category" class="muted" style="font-size: 11px">· {{ c.category }}</span>
          <span class="muted" style="font-size: 12px">{{ c.phone }}</span>
        </label>
      </div>

      <div class="row" style="justify-content: space-between; align-items: center; margin-top: 14px">
        <span class="muted" style="font-size: 12px">{{ picked.size }} ta tanlandi</span>
        <div class="row" style="gap: 10px">
          <button type="button" class="btn ghost" @click="pickerOpen = false">Bekor</button>
          <button type="button" class="btn" :disabled="!picked.size" @click="addPicked">Qo‘shish</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  align-items: center;
  min-height: 46px;
  padding: 8px 10px;
  border: 1px solid var(--line, #2a3550);
  border-radius: 10px;
  background: var(--input-bg, #0e1626);
  cursor: text;
}
.chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 6px 4px 10px;
  background: var(--brand, #2d7eec);
  color: #fff;
  border-radius: 999px;
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
}
.chip-x {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 16px;
  height: 16px;
  border: 0;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.25);
  color: #fff;
  cursor: pointer;
  padding: 0;
}
.chip-x:hover { background: rgba(255, 255, 255, 0.45); }
.chip-input {
  flex: 1;
  min-width: 140px;
  border: 0 !important;
  outline: none;
  background: transparent;
  padding: 4px 2px;
  color: inherit;
  font-size: 14px;
}
.linkbtn {
  border: 0;
  background: none;
  color: var(--danger, #ef5350);
  font-size: 12px;
  cursor: pointer;
  padding: 0;
}
.pick-list {
  max-height: 320px;
  overflow-y: auto;
  border: 1px solid var(--line, #2a3550);
  border-radius: 10px;
}
.pick-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 12px;
  cursor: pointer;
  border-bottom: 1px solid var(--line, #1f2942);
}
.pick-row:last-child { border-bottom: 0; }
.pick-row:hover { background: rgba(255, 255, 255, 0.03); }
.pick-name { flex: 1; font-weight: 600; }
</style>
