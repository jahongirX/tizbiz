<script setup>
import { ref, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { Send as SendIcon } from 'lucide-vue-next'

const devices = ref([])
const templates = ref([])
const contacts = ref([])
const deviceId = ref('')
const templateId = ref('')
const contactPick = ref('')
const phonesRaw = ref('')
const text = ref('')
const sending = ref(false)
const result = ref(null)
const error = ref('')

const phones = computed(() =>
  phonesRaw.value
    .split(/[\n,;]+/)
    .map((p) => p.trim())
    .filter(Boolean),
)

onMounted(async () => {
  const [d, t, c] = await Promise.all([
    api.get('/v1/sms/devices'),
    api.get('/v1/sms/templates').catch(() => []),
    api.get('/v1/sms/contacts').catch(() => []),
  ])
  devices.value = d
  templates.value = t
  contacts.value = c
  const active = devices.value.find((d) => d.is_active)
  if (active) deviceId.value = String(active.id)
})

function applyTemplate() {
  const t = templates.value.find((x) => String(x.id) === templateId.value)
  if (t) text.value = t.text
}

function addContact() {
  const c = contacts.value.find((x) => String(x.id) === contactPick.value)
  if (!c) return
  if (!phones.value.includes(c.phone)) {
    phonesRaw.value = (phonesRaw.value.trim() ? phonesRaw.value.trim() + '\n' : '') + c.phone
  }
  contactPick.value = ''
}

async function send() {
  error.value = ''
  result.value = null
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
      <label>Raqamlar (har biri yangi qatorda yoki vergul bilan)</label>
      <textarea v-model="phonesRaw" placeholder="+998901234567&#10;+998907654321"></textarea>
      <div class="row" style="justify-content: space-between; gap: 12px; margin-top: 6px">
        <span class="muted" style="font-size: 12px">{{ phones.length }} ta raqam</span>
        <select v-if="contacts.length" v-model="contactPick" style="width: auto; max-width: 60%" @change="addContact">
          <option value="">+ Kontaktdan qo‘shish</option>
          <option v-for="c in contacts" :key="c.id" :value="String(c.id)">{{ c.name }} — {{ c.phone }}</option>
        </select>
      </div>
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
</template>
