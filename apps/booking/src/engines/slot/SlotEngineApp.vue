<script setup>
// Slot engine (online booking) public SPA — barber, salon, dentistry, clinic…
// Presentation only: the site payload is loaded once by the parent (App.vue)
// and handed in as props, so this component just renders the booking wizard.
// A new vertical adds a sibling under ../<engine>/ ; nothing here changes.
import { ref, reactive, computed } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import ServiceStep from '../../components/ServiceStep.vue'
import StaffStep from '../../components/StaffStep.vue'
import DateTimeStep from '../../components/DateTimeStep.vue'
import InfoStep from '../../components/InfoStep.vue'
import ConfirmStep from '../../components/ConfirmStep.vue'
import DoneStep from '../../components/DoneStep.vue'

const props = defineProps({
  slug: { type: String, default: '' },
  business: { type: Object, default: null },
  services: { type: Array, default: () => [] },
  staff: { type: Array, default: () => [] },
})

// Only active offerings reach the wizard (mirrors the previous inline filter).
const services = computed(() => (props.services || []).filter((s) => s.is_active !== false))
const staff = computed(() => (props.staff || []).filter((s) => s.is_active !== false))
const business = computed(() => props.business)

// ---- Wizard state ----
// steps: 'service' | 'staff' | 'datetime' | 'info' | 'confirm' | 'done'
const step = ref('service')
const sel = reactive({ service: null, staff: null, slot: null })
const client = reactive({ name: '', phone: '' })

const submitting = ref(false)
const submitError = ref('')
const appointment = ref(null)

const payLoading = ref(false)
const payError = ref('')

const STEP_ORDER = ['service', 'staff', 'datetime', 'info', 'confirm']
const STEP_TITLES = {
  service: 'Xizmat',
  staff: 'Mutaxassis',
  datetime: 'Vaqt',
  info: 'Ma’lumot',
  confirm: 'Tasdiqlash',
}
const progress = computed(() => {
  if (step.value === 'done') return STEP_ORDER.length
  return STEP_ORDER.indexOf(step.value) + 1
})

const brandInitials = computed(() => {
  return String(business.value?.name || '?')
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p[0])
    .join('')
    .toUpperCase()
})
const bizPhone = computed(() => business.value?.phone || business.value?.phone_number || '')
const bizCategory = computed(
  () => business.value?.category || business.value?.category_name || '',
)

// ---- Navigation ----
function pickService(s) {
  sel.service = s
  sel.slot = null // duration/availability depends on service
  step.value = 'staff'
}
function pickStaff(m) {
  sel.staff = m
  sel.slot = null
  step.value = 'datetime'
}
function pickSlot(slot) {
  sel.slot = slot
  step.value = 'info'
}
function submitInfo(info) {
  client.name = info.name
  client.phone = info.phone
  submitError.value = ''
  step.value = 'confirm'
}

async function confirm() {
  submitting.value = true
  submitError.value = ''
  try {
    const appt = await api.post('/v1/appointments', {
      staff_id: sel.staff.id,
      service_id: sel.service.id,
      starts_at: sel.slot.start_utc,
      client: { name: client.name, phone: client.phone },
    })
    appointment.value = appt
    step.value = 'done'
  } catch (e) {
    if (e instanceof ApiError && e.status === 409) {
      // Slot taken meanwhile — send the user back to pick another.
      submitError.value = ''
      sel.slot = null
      step.value = 'datetime'
      alert('Kechirasiz, bu vaqt band bo‘ldi. Iltimos, boshqa vaqtni tanlang.')
    } else {
      submitError.value = e instanceof ApiError ? e.message : 'Band qilishda xatolik.'
    }
  } finally {
    submitting.value = false
  }
}

async function payDeposit() {
  if (!appointment.value?.id) return
  payLoading.value = true
  payError.value = ''
  try {
    const res = await api.post('/v1/payments/deposit', {
      appointment_id: appointment.value.id,
      provider: 'payme',
    })
    const url =
      res?.url || res?.checkout_url || res?.payment_url || res?.redirect_url || res?.pay_url
    if (url) {
      window.location.href = url
    } else {
      payError.value = 'To‘lov havolasi topilmadi.'
    }
  } catch (e) {
    payError.value = e instanceof ApiError ? e.message : 'To‘lovni boshlab bo‘lmadi.'
  } finally {
    payLoading.value = false
  }
}

function restart() {
  sel.service = null
  sel.staff = null
  sel.slot = null
  client.name = ''
  client.phone = ''
  appointment.value = null
  submitError.value = ''
  payError.value = ''
  step.value = 'service'
}
</script>

<template>
  <div class="shell">
    <header class="brand">
      <div class="brand-top">
        <div class="brand-logo">{{ brandInitials }}</div>
        <div class="brand-info">
          <h1>{{ business.name }}</h1>
          <div class="sub">Onlayn navbat olish</div>
        </div>
      </div>
      <div v-if="bizCategory || bizPhone" class="brand-chips">
        <span v-if="bizCategory" class="brand-chip">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M20.59 13.41l-7.17 7.17a2 2 0 01-2.83 0L2 12V2h10l8.59 8.59a2 2 0 010 2.82z" />
            <line x1="7" y1="7" x2="7.01" y2="7" />
          </svg>
          {{ bizCategory }}
        </span>
        <a v-if="bizPhone" class="brand-chip" :href="`tel:${bizPhone}`">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07 19.5 19.5 0 01-6-6 19.79 19.79 0 01-3.07-8.67A2 2 0 014.11 2h3a2 2 0 012 1.72c.13.96.36 1.9.7 2.81a2 2 0 01-.45 2.11L8.09 9.91a16 16 0 006 6l1.27-1.27a2 2 0 012.11-.45c.9.34 1.85.57 2.81.7A2 2 0 0122 16.92z" />
          </svg>
          {{ bizPhone }}
        </a>
      </div>
    </header>

    <template v-if="step !== 'done'">
      <div class="steps">
        <span
          v-for="(s, i) in STEP_ORDER"
          :key="s"
          class="dot"
          :class="{ done: i < progress }"
        ></span>
      </div>
      <p class="step-count">
        {{ progress }}-qadam / {{ STEP_ORDER.length }} · {{ STEP_TITLES[step] }}
      </p>
    </template>

    <Transition name="step-fade" mode="out-in">
      <div :key="step">
        <ServiceStep
          v-if="step === 'service'"
          :services="services"
          :selected-id="sel.service?.id ?? null"
          @select="pickService"
        />

        <StaffStep
          v-else-if="step === 'staff'"
          :staff="staff"
          :selected-id="sel.staff?.id ?? null"
          @select="pickStaff"
          @back="step = 'service'"
        />

        <DateTimeStep
          v-else-if="step === 'datetime'"
          :staff-id="sel.staff.id"
          :service-id="sel.service.id"
          :selected-start="sel.slot?.start_utc ?? null"
          @select="pickSlot"
          @back="step = 'staff'"
        />

        <InfoStep
          v-else-if="step === 'info'"
          :name="client.name"
          :phone="client.phone"
          @submit="submitInfo"
          @back="step = 'datetime'"
        />

        <ConfirmStep
          v-else-if="step === 'confirm'"
          :business="business"
          :service="sel.service"
          :staff="sel.staff"
          :slot="sel.slot"
          :client="client"
          :submitting="submitting"
          :error="submitError"
          @confirm="confirm"
          @back="step = 'info'"
        />

        <DoneStep
          v-else-if="step === 'done'"
          :service="sel.service"
          :staff="sel.staff"
          :slot="sel.slot"
          :pay-loading="payLoading"
          :pay-error="payError"
          @pay="payDeposit"
          @restart="restart"
        />
      </div>
    </Transition>
  </div>
</template>
