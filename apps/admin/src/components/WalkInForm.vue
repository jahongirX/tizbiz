<script setup>
// Walk-in ("Hozir keldi") — the barbershop's most common case: the client is
// already in the chair. One screen, no date/time pickers: master + service, an
// optional phone, and the appointment starts now with status "arrived".
import { ref, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { formatSom } from '../lib/money'
import { localToUtc, minutesToHhmm, nowLocalMinutes, todayInput } from '../lib/datetime'
import PhoneInput from './PhoneInput.vue'

const props = defineProps({
  // Preselected master (the column the user is looking at).
  staffId: { type: [Number, String], default: '' },
})
const emit = defineEmits(['created', 'cancel'])

const staff = ref([])
const services = ref([])
const loading = ref(true)
const submitting = ref(false)
const error = ref('')

const masterId = ref(props.staffId || '')
const serviceId = ref('')
const phone = ref('')
const name = ref('')
// Shown by default: a shop usually does take the number, and an extra click to
// reveal the field is one the master will skip.
const withClient = ref(true)

const service = computed(() => services.value.find((s) => s.id === serviceId.value) || null)
const canSubmit = computed(() => !!masterId.value && !!serviceId.value && !submitting.value)

/** Now, rounded down to 5 minutes — the grid barbers actually think in. */
function nowHhmm() {
  return minutesToHhmm(Math.floor(nowLocalMinutes() / 5) * 5)
}

async function load() {
  loading.value = true
  try {
    const [st, sv] = await Promise.all([
      api.get('/v1/staff').catch(() => []),
      api.get('/v1/services').catch(() => []),
    ])
    staff.value = (Array.isArray(st) ? st : st?.items || []).filter((s) => s.is_active !== false)
    services.value = (Array.isArray(sv) ? sv : sv?.items || []).filter((s) => s.is_active !== false)
    if (!masterId.value && staff.value.length) masterId.value = staff.value[0].id
    if (services.value.length) serviceId.value = services.value[0].id
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : "Ma'lumotlarni yuklab bo'lmadi"
  } finally {
    loading.value = false
  }
}

async function submit() {
  if (!canSubmit.value) return
  error.value = ''
  submitting.value = true
  try {
    const payload = {
      staff_id: masterId.value,
      service_id: serviceId.value,
      starts_at: localToUtc(todayInput(), nowHhmm()),
      status: 'arrived',
    }
    // A phone is optional — it only matters for loyalty and reminders later.
    if (withClient.value && phone.value.replace(/\D/g, '').length >= 12) {
      payload.client = { name: name.value.trim() || 'Mijoz', phone: phone.value.trim() }
    }
    await api.post('/v1/appointments', payload)
    emit('created')
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : "Navbatga qo'shib bo'lmadi"
  } finally {
    submitting.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="wi">
    <div v-if="error" class="alert alert-error" style="margin-bottom: 12px">{{ error }}</div>
    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

    <template v-else>
      <div class="field">
        <label>Usta</label>
        <select v-model="masterId">
          <option v-for="s in staff" :key="s.id" :value="s.id">{{ s.name }}</option>
        </select>
      </div>

      <div class="field">
        <label>Xizmat</label>
        <div class="chips">
          <button
            v-for="s in services"
            :key="s.id"
            type="button"
            class="chip"
            :class="{ active: serviceId === s.id }"
            @click="serviceId = s.id"
          >
            <span class="chip-name">{{ s.name }}</span>
            <span class="chip-meta">{{ s.duration_min }} daq · {{ formatSom(s.price_tiyin) }}</span>
          </button>
        </div>
      </div>

      <label class="row toggle">
        <input v-model="withClient" type="checkbox" style="width: auto" />
        <span>Mijoz raqamini kiritish (loyallik uchun)</span>
      </label>

      <div v-if="withClient" class="field-row">
        <div class="field">
          <label>Telefon</label>
          <PhoneInput v-model="phone" />
        </div>
        <div class="field">
          <label>Ismi</label>
          <input v-model="name" placeholder="Ixtiyoriy" />
        </div>
      </div>

      <div class="wi-foot">
        <span class="muted">
          Boshlanish: <strong>{{ nowHhmm() }}</strong>
          <template v-if="service"> · {{ service.duration_min }} daqiqa</template>
        </span>
        <div class="row" style="gap: 10px">
          <button class="btn" @click="emit('cancel')">Bekor</button>
          <button class="btn btn-primary" :disabled="!canSubmit" @click="submit">
            {{ submitting ? 'Qo‘shilmoqda…' : 'Navbatga qo‘shish' }}
          </button>
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.chip {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 2px;
  padding: 8px 12px;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: var(--surface);
  color: var(--text);
  cursor: pointer;
  text-align: left;
  font: inherit;
}
.chip:hover {
  border-color: var(--primary);
}
.chip.active {
  border-color: var(--primary);
  background: var(--primary-soft);
}
.chip-name {
  font-weight: 600;
  font-size: 13px;
}
.chip-meta {
  font-size: 11.5px;
  color: var(--text-muted);
}
.toggle {
  gap: 8px;
  margin: 14px 0 6px;
  cursor: pointer;
  font-size: 13px;
}
.wi-foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 12px;
  margin-top: 18px;
  padding-top: 14px;
  border-top: 1px solid var(--border);
}
</style>
