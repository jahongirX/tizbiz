<script setup>
import { ref, onMounted } from 'vue'
import { api, ApiError } from '@navbat/api-client'

const loading = ref(true)
const error = ref('')
const saving = ref(false)
const saved = ref(false)
const formError = ref('')

const form = ref({
  online_booking_enabled: false,
  booking_lead_min: 60,
  booking_horizon_days: 30,
})

async function load() {
  loading.value = true
  error.value = ''
  try {
    const res = await api.get('/v1/settings/booking')
    form.value = {
      online_booking_enabled: !!res.online_booking_enabled,
      booking_lead_min: Number(res.booking_lead_min ?? 60),
      booking_horizon_days: Number(res.booking_horizon_days ?? 30),
    }
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Yuklab bo\'lmadi'
  } finally {
    loading.value = false
  }
}

async function save() {
  formError.value = ''
  saved.value = false
  saving.value = true
  try {
    const payload = {
      online_booking_enabled: form.value.online_booking_enabled,
      booking_lead_min: Number(form.value.booking_lead_min),
      booking_horizon_days: Number(form.value.booking_horizon_days),
    }
    const res = await api.put('/v1/settings/booking', payload)
    form.value = {
      online_booking_enabled: !!res.online_booking_enabled,
      booking_lead_min: Number(res.booking_lead_min ?? payload.booking_lead_min),
      booking_horizon_days: Number(res.booking_horizon_days ?? payload.booking_horizon_days),
    }
    saved.value = true
    setTimeout(() => (saved.value = false), 2500)
  } catch (e) {
    formError.value = e instanceof ApiError ? e.message : 'Saqlab bo\'lmadi'
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<template>
  <div>
    <div class="page-head">
      <h1>Onlayn-yozuv sozlamalari</h1>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>
    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

    <section v-else class="card" style="max-width: 520px">
      <div v-if="formError" class="alert alert-error">{{ formError }}</div>

      <form @submit.prevent="save">
        <label class="row" style="gap: 10px; cursor: pointer; margin-bottom: 6px">
          <input v-model="form.online_booking_enabled" type="checkbox" style="width: auto" />
          <span style="font-weight: 600">Onlayn yozuvni yoqish</span>
        </label>
        <p class="muted" style="margin: 0 0 20px; font-size: 13px">
          Yoqilganda mijozlar sayt orqali o'zlari navbatga yozila oladi.
        </p>

        <div class="field-row">
          <div class="field">
            <label>Minimal oldindan (daqiqa)</label>
            <input
              v-model.number="form.booking_lead_min"
              type="number"
              min="0"
              step="5"
              placeholder="60"
            />
            <span class="muted" style="font-size: 12px">Shu daqiqadan yaqinroq vaqtga yozib bo'lmaydi.</span>
          </div>
          <div class="field">
            <label>Maksimal oldindan (kun)</label>
            <input
              v-model.number="form.booking_horizon_days"
              type="number"
              min="1"
              step="1"
              placeholder="30"
            />
            <span class="muted" style="font-size: 12px">Shu kundan uzoqroq sanaga yozib bo'lmaydi.</span>
          </div>
        </div>

        <div class="row" style="margin-top: 20px; gap: 12px">
          <button class="btn btn-primary" type="submit" :disabled="saving">
            {{ saving ? 'Saqlanmoqda…' : 'Saqlash' }}
          </button>
          <span v-if="saved" style="color: var(--success); font-weight: 600">✓ Saqlandi</span>
        </div>
      </form>
    </section>
  </div>
</template>
