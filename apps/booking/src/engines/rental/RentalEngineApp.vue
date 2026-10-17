<script setup>
// Rental engine (wedding halls / to'yxona). No packages: the hall offers a
// morning and an evening session (morning cheaper), a flat per-guest price, and
// the client only enters a guest count and picks a free date on a big month
// calendar. A day can hold both a morning and an evening event, so the calendar
// is session-aware. The hall is a single implicit resource (staff[0]).
import { ref, reactive, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import GuestCountStep from '../../components/GuestCountStep.vue'
import CalendarStep from '../../components/CalendarStep.vue'
import InfoStep from '../../components/InfoStep.vue'
import LocationCard from '../../components/LocationCard.vue'

const props = defineProps({
  slug: { type: String, default: '' },
  business: { type: Object, default: null },
  services: { type: Array, default: () => [] },
  staff: { type: Array, default: () => [] },
})

const business = computed(() => props.business)
// The hall is a single implicit resource; the appointment still needs a staff
// row and a service row for referential integrity.
const hall = computed(() => (props.staff || []).find((s) => s.is_active !== false) || props.staff?.[0] || null)
const hallService = computed(() => (props.services || []).find((s) => s.is_active !== false) || props.services?.[0] || null)

// Sessions — the only choice besides guest count and date. Morning is cheaper.
const SESSIONS = [
  { key: 'morning', label: 'Ertalab', sub: 'Kunduzgi bazm · 10:00–16:00', emo: '🌤️', perGuest: 15000 },
  { key: 'evening', label: 'Kechqurun', sub: 'Kechki to‘y · 18:00–23:00', emo: '🌙', perGuest: 25000 },
]

const step = ref('session')
const sel = reactive({ session: null, guests: 100, date: null })
const client = reactive({ name: '', phone: '' })

const submitting = ref(false)
const submitError = ref('')
const appointment = ref(null)

const STEP_ORDER = ['session', 'guests', 'datetime', 'info', 'confirm']
const STEP_TITLES = {
  session: 'Vaqt',
  guests: 'Mehmonlar',
  datetime: 'Sana',
  info: 'Ma’lumot',
  confirm: 'Tasdiqlash',
}
const progress = computed(() => {
  if (step.value === 'done') return STEP_ORDER.length
  return STEP_ORDER.indexOf(step.value) + 1
})

const brandInitials = computed(() =>
  String(business.value?.name || '?')
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p[0])
    .join('')
    .toUpperCase(),
)
const bizPhone = computed(() => business.value?.phone || business.value?.phone_number || '')

const coverStyle = computed(() =>
  business.value?.cover
    ? {
        backgroundImage: `linear-gradient(180deg, rgba(0,0,0,.18), rgba(0,0,0,.55)), url('${business.value.cover}')`,
        backgroundSize: 'cover',
        backgroundPosition: 'center',
      }
    : {},
)

const MON_FULL = [
  'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
  'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
]
function prettyDate(iso) {
  if (!iso) return ''
  const [y, m, d] = String(iso).split('-')
  return `${Number(d)} ${MON_FULL[Number(m) - 1] || ''} ${y}`
}
function money(som) {
  return Math.round(Number(som) || 0).toLocaleString('ru-RU').replace(/\s/g, ' ') + " so'm"
}

const perGuest = computed(() => sel.session?.perGuest || 0)
const tables = computed(() => Math.ceil((sel.guests || 0) / 10))
const total = computed(() => (sel.guests || 0) * perGuest.value)

// ---- Navigation ----
function pickSession(s) {
  sel.session = s
  step.value = 'guests'
}
function submitGuests(n) {
  sel.guests = n
  step.value = 'datetime'
}
function pickDate(iso) {
  sel.date = iso
  step.value = 'info'
}
function submitInfo(info) {
  client.name = info.name
  client.phone = info.phone
  submitError.value = ''
  step.value = 'confirm'
}

async function confirm() {
  if (!hall.value || !hallService.value) {
    submitError.value = 'Zal resursi topilmadi. Iltimos, biznesga qo‘ng‘iroq qiling.'
    return
  }
  submitting.value = true
  submitError.value = ''
  try {
    const appt = await api.post('/v1/appointments', {
      staff_id: hall.value.id,
      service_id: hallService.value.id,
      session: sel.session.key,
      date: sel.date,
      guests: sel.guests,
      client: { name: client.name, phone: client.phone },
    })
    appointment.value = appt
    step.value = 'done'
  } catch (e) {
    if (e instanceof ApiError && e.status === 409) {
      submitError.value = ''
      sel.date = null
      step.value = 'datetime'
      alert('Kechirasiz, bu sana band bo‘ldi. Iltimos, boshqa sanani tanlang.')
    } else {
      submitError.value = e instanceof ApiError ? e.message : 'Band qilishda xatolik.'
    }
  } finally {
    submitting.value = false
  }
}

function restart() {
  sel.session = null
  sel.guests = 100
  sel.date = null
  client.name = ''
  client.phone = ''
  appointment.value = null
  submitError.value = ''
  step.value = 'session'
}

onMounted(() => {})
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
          <div class="sub">{{ business.tagline || 'To‘yxona · onlayn bron' }}</div>
        </div>
      </div>
      <div v-if="bizPhone" class="brand-chips">
        <a class="brand-chip" :href="`tel:${bizPhone}`">
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
        <span v-for="(s, i) in STEP_ORDER" :key="s" class="dot" :class="{ done: i < progress }"></span>
      </div>
      <p class="step-count">{{ progress }}-qadam / {{ STEP_ORDER.length }} · {{ STEP_TITLES[step] }}</p>
    </template>

    <Transition name="step-fade" mode="out-in">
      <div :key="step">
        <!-- 1. Session (morning / evening) -->
        <div v-if="step === 'session'">
          <p class="section-label">To‘y vaqtini tanlang</p>
          <div class="pkg-list">
            <button
              v-for="s in SESSIONS"
              :key="s.key"
              class="pkg"
              :class="{ selected: s.key === sel.session?.key }"
              @click="pickSession(s)"
            >
              <div class="pkg-emo">{{ s.emo }}</div>
              <div class="pkg-main">
                <div class="pkg-name">{{ s.label }}</div>
                <div class="pkg-desc">{{ s.sub }}</div>
              </div>
              <div class="pkg-price">
                <b>{{ money(s.perGuest) }}</b>
                <span>/ kishi</span>
              </div>
            </button>
          </div>
        </div>

        <!-- 2. Guests -->
        <GuestCountStep
          v-else-if="step === 'guests'"
          :guests="sel.guests"
          :per-guest="perGuest"
          :can-back="true"
          @submit="submitGuests"
          @back="step = 'session'"
        />

        <!-- 3. Date -->
        <CalendarStep
          v-else-if="step === 'datetime'"
          :slug="slug"
          :session="sel.session?.key || ''"
          :selected-date="sel.date"
          @select="pickDate"
          @back="step = 'guests'"
        />

        <!-- 4. Client info -->
        <InfoStep
          v-else-if="step === 'info'"
          :name="client.name"
          :phone="client.phone"
          @submit="submitInfo"
          @back="step = 'datetime'"
        />

        <!-- 5. Confirm -->
        <div v-else-if="step === 'confirm'">
          <div class="step-head">
            <button class="back" aria-label="Orqaga" @click="step = 'info'">‹</button>
            <h2>Tasdiqlash</h2>
          </div>
          <div class="summary">
            <div class="sum-row"><span>Vaqt</span><b>{{ sel.session.label }} · {{ sel.session.sub.split('·')[1].trim() }}</b></div>
            <div class="sum-row"><span>Sana</span><b>{{ prettyDate(sel.date) }}</b></div>
            <div class="sum-row"><span>Mehmonlar</span><b>{{ sel.guests }} kishi · {{ tables }} stol</b></div>
            <div class="sum-row"><span>Bir kishiga</span><b>{{ money(perGuest) }}</b></div>
            <div class="sum-row total"><span>Jami taxminan</span><b>{{ money(total) }}</b></div>
            <div class="sum-row"><span>Mijoz</span><b>{{ client.name }}</b></div>
            <div class="sum-row"><span>Telefon</span><b>{{ client.phone }}</b></div>
          </div>
          <p class="fineprint">
            Bron so‘rovi yuboriladi, to‘yxona mudiri siz bilan bog‘lanadi.
            Yakuniy narx menyu va qo‘shimcha xizmatlarga qarab o‘zgarishi mumkin.
          </p>
          <div v-if="submitError" class="alert">{{ submitError }}</div>
          <button class="cta" :disabled="submitting" @click="confirm">
            {{ submitting ? 'Yuborilmoqda…' : 'Bron qilish' }}
          </button>
        </div>

        <!-- Done -->
        <div v-else-if="step === 'done'" class="done">
          <div class="done-emo">🎉</div>
          <h2>Bron qabul qilindi!</h2>
          <p class="done-sub">
            {{ prettyDate(sel.date) }} · {{ sel.session.label }} · {{ sel.guests }} mehmon · {{ tables }} stol
          </p>
          <p class="note">To‘yxona mudiri tez orada siz bilan bog‘lanadi.</p>
          <LocationCard :business="business" />
          <button class="cta ghost" @click="restart">Yana bron qilish</button>
        </div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.pkg-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.pkg {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  text-align: left;
  border: 1px solid var(--line, #2a2d3a);
  border-radius: 16px;
  background: var(--card, #171a24);
  color: inherit;
  padding: 16px;
  cursor: pointer;
}
.pkg.selected {
  border-color: var(--brand, #8b5cf6);
  box-shadow: 0 0 0 1px var(--brand, #8b5cf6);
}
.pkg-emo {
  font-size: 26px;
  line-height: 1;
}
.pkg-main {
  flex: 1;
  min-width: 0;
}
.pkg-name {
  font-weight: 600;
  font-size: 16px;
}
.pkg-desc {
  font-size: 13px;
  color: var(--muted, #8b90a3);
  margin-top: 2px;
}
.pkg-price {
  text-align: right;
  white-space: nowrap;
}
.pkg-price b {
  color: var(--brand, #8b5cf6);
  font-size: 15px;
}
.pkg-price span {
  display: block;
  font-size: 11px;
  color: var(--muted, #8b90a3);
}
.summary {
  border: 1px solid var(--line, #2a2d3a);
  border-radius: 16px;
  padding: 6px 14px;
  margin-bottom: 14px;
}
.sum-row {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  padding: 11px 0;
  border-bottom: 1px solid var(--line, #2a2d3a);
}
.sum-row:last-child {
  border-bottom: none;
}
.sum-row.total {
  font-size: 17px;
}
.sum-row.total b {
  color: var(--brand, #8b5cf6);
}
.sum-row b {
  text-align: right;
}
.fineprint {
  font-size: 12.5px;
  color: var(--muted, #8b90a3);
  margin: 0 0 16px;
  line-height: 1.5;
}
.cta {
  width: 100%;
  height: 54px;
  border: none;
  border-radius: 16px;
  background: var(--brand, #8b5cf6);
  color: var(--brand-ink, #fff);
  font-size: 17px;
  font-weight: 700;
  cursor: pointer;
}
.cta:disabled {
  opacity: 0.6;
  cursor: default;
}
.cta.ghost {
  background: transparent;
  border: 1px solid var(--line, #2a2d3a);
  color: inherit;
  margin-top: 18px;
}
.done {
  text-align: center;
  padding: 24px 0 8px;
}
.done-emo {
  font-size: 56px;
}
.done-sub {
  font-weight: 600;
  margin: 6px 0 4px;
}
</style>
