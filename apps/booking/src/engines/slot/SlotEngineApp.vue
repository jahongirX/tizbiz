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
// steps: 'service' | 'staff' | 'datetime' | 'confirm' | 'done'
// The staff step only exists when there is a choice to make, and the client's
// details live on the confirm screen — a returning client books in two taps.
const step = ref('service')
// `services` holds every service of the visit, primary first: the API keeps the
// first in service_id and the rest as line items.
const sel = reactive({ services: [], staff: null, slot: null })
const primaryService = computed(() => sel.services[0] || null)
// Booking several services at once is a barbershop/salon habit. Other business
// types that fall back to this engine keep the old one-service flow untouched.
const MULTI_SERVICE_CATEGORIES = ['barber', 'salon']
const multiService = computed(() =>
  MULTI_SERVICE_CATEGORIES.includes(String(business.value?.category || '')),
)
const selectedServiceIds = computed(() => sel.services.map((s) => s.id))
const totalDuration = computed(() =>
  sel.services.reduce((n, s) => n + (Number(s.duration_min) || 0), 0),
)
const totalPrice = computed(() =>
  sel.services.reduce((n, s) => n + (Number(s.price_tiyin) || 0), 0),
)
const totalDeposit = computed(() =>
  sel.services.reduce((n, s) => n + (Number(s.deposit_tiyin) || 0), 0),
)

const CLIENT_KEY = 'tizbiz_client'
function rememberedClient() {
  try {
    const raw = localStorage.getItem(CLIENT_KEY)
    const v = raw ? JSON.parse(raw) : null
    return v && v.phone ? { name: String(v.name || ''), phone: String(v.phone) } : null
  } catch {
    return null
  }
}
const client = reactive(rememberedClient() || { name: '', phone: '' })

const submitting = ref(false)
const submitError = ref('')
const appointment = ref(null)

const payLoading = ref(false)
const payError = ref('')

// One master -> no reason to ask which one.
const needsStaffStep = computed(() => staff.value.length > 1)
const STEP_ORDER = computed(() =>
  needsStaffStep.value
    ? ['service', 'staff', 'datetime', 'confirm']
    : ['service', 'datetime', 'confirm'],
)
const STEP_TITLES = {
  service: 'Xizmat',
  staff: 'Mutaxassis',
  datetime: 'Vaqt',
  confirm: 'Tasdiqlash',
}
const progress = computed(() => {
  if (step.value === 'done') return STEP_ORDER.value.length
  return STEP_ORDER.value.indexOf(step.value) + 1
})

// 'any' -> availability is merged across every master; the picked slot decides.
const ANY_STAFF = 'any'
const anyStaff = ref(false)
const availabilityStaffIds = computed(() =>
  anyStaff.value || !sel.staff ? staff.value.map((m) => m.id) : [sel.staff.id],
)

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

// Optional cover image behind the branded header (dark overlay keeps text legible).
const coverStyle = computed(() =>
  business.value?.cover
    ? {
        backgroundImage: `linear-gradient(180deg, rgba(0,0,0,.18), rgba(0,0,0,.55)), url('${business.value.cover}')`,
        backgroundSize: 'cover',
        backgroundPosition: 'center',
      }
    : {},
)

// ---- Navigation ----
function toggleService(s) {
  sel.slot = null // the visit's length changed, so the offered slots did too
  if (!multiService.value) {
    sel.services = [s]
    servicesDone()
    return
  }
  const at = sel.services.findIndex((x) => x.id === s.id)
  if (at >= 0) sel.services.splice(at, 1)
  else sel.services.push(s)
}
function servicesDone() {
  if (!sel.services.length) return
  if (needsStaffStep.value) {
    step.value = 'staff'
  } else {
    sel.staff = staff.value[0] || null
    anyStaff.value = false
    step.value = 'datetime'
  }
}
function pickStaff(m) {
  if (m === ANY_STAFF) {
    anyStaff.value = true
    sel.staff = null
  } else {
    anyStaff.value = false
    sel.staff = m
  }
  sel.slot = null
  step.value = 'datetime'
}
function pickSlot(slot) {
  sel.slot = slot
  // With "farqi yo'q" the chosen time also chooses the master.
  if (anyStaff.value && slot.staff_id) {
    sel.staff = staff.value.find((m) => m.id === slot.staff_id) || null
  }
  submitError.value = ''
  step.value = 'confirm'
}
function backFromDatetime() {
  step.value = needsStaffStep.value ? 'staff' : 'service'
}
function updateClient(info) {
  client.name = info.name
  client.phone = info.phone
}

async function confirm() {
  submitting.value = true
  submitError.value = ''
  try {
    const appt = await api.post('/v1/appointments', {
      staff_id: sel.staff.id,
      service_id: primaryService.value.id,
      extra_service_ids: sel.services.slice(1).map((s) => s.id),
      starts_at: sel.slot.start_utc,
      client: { name: client.name, phone: client.phone },
    })
    appointment.value = appt
    // Next time this device books, the details are already filled in.
    try {
      localStorage.setItem(CLIENT_KEY, JSON.stringify({ name: client.name, phone: client.phone }))
    } catch {
      /* private mode — booking still works, we just won't remember */
    }
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
  sel.services = []
  sel.staff = null
  sel.slot = null
  anyStaff.value = false
  appointment.value = null
  submitError.value = ''
  payError.value = ''
  step.value = 'service'
}
</script>

<template>
  <div class="shell">
    <header class="brand" :style="coverStyle">
      <div class="brand-top">
        <div class="brand-logo">
          <img v-if="business.logo" :src="business.logo" alt="" />
          <template v-else>{{ brandInitials }}</template>
        </div>
        <div class="brand-info">
          <h1>{{ business.name }}</h1>
          <div class="sub">{{ business.tagline || 'Onlayn navbat olish' }}</div>
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
          :selected-ids="selectedServiceIds"
          :multi="multiService"
          @toggle="toggleService"
          @next="servicesDone"
        />

        <StaffStep
          v-else-if="step === 'staff'"
          :staff="staff"
          :selected-id="anyStaff ? 'any' : (sel.staff?.id ?? null)"
          @select="pickStaff"
          @back="step = 'service'"
        />

        <DateTimeStep
          v-else-if="step === 'datetime'"
          :staff-ids="availabilityStaffIds"
          :service-id="primaryService.id"
          :extra-service-ids="selectedServiceIds.slice(1)"
          :selected-start="sel.slot?.start_utc ?? null"
          @select="pickSlot"
          @back="backFromDatetime"
        />

        <ConfirmStep
          v-else-if="step === 'confirm'"
          :business="business"
          :services="sel.services"
          :total-min="totalDuration"
          :total-price="totalPrice"
          :total-deposit="totalDeposit"
          :staff="sel.staff"
          :slot="sel.slot"
          :client="client"
          :submitting="submitting"
          :error="submitError"
          @update:client="updateClient"
          @confirm="confirm"
          @back="step = 'datetime'"
        />

        <DoneStep
          v-else-if="step === 'done'"
          :services="sel.services"
          :total-deposit="totalDeposit"
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
