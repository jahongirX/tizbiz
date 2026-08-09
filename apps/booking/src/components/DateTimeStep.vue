<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { isoDate, slotTime, dayStrip, slotBucket } from '../format.js'

const props = defineProps({
  staffId: { type: [Number, String], required: true },
  serviceId: { type: [Number, String], required: true },
  selectedStart: { type: [String, null], default: null },
})
const emit = defineEmits(['select', 'back'])

const days = dayStrip(14)
const date = ref(isoDate())
const slots = ref([])
const loading = ref(false)
const error = ref('')

// Group slots into morning / afternoon / evening for readability.
const GROUPS = [
  { key: 'morning', label: 'Ertalab' },
  { key: 'afternoon', label: 'Kunduzi' },
  { key: 'evening', label: 'Kechqurun' },
]
const grouped = computed(() =>
  GROUPS.map((g) => ({
    ...g,
    items: slots.value.filter((s) => slotBucket(s.start_local) === g.key),
  })).filter((g) => g.items.length),
)

async function load() {
  loading.value = true
  error.value = ''
  slots.value = []
  try {
    const q = new URLSearchParams({ date: date.value, service_id: String(props.serviceId) })
    const res = await api.get(`/v1/staff/${props.staffId}/availability?${q}`)
    slots.value = Array.isArray(res?.slots) ? res.slots : []
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Bo‘sh vaqtlarni yuklab bo‘lmadi.'
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch(date, load)
</script>

<template>
  <div>
    <div class="step-head">
      <button class="back" aria-label="Orqaga" @click="emit('back')">‹</button>
      <h2>Sana va vaqt</h2>
    </div>

    <p class="section-label">Sanani tanlang</p>
    <div class="day-strip" role="tablist" aria-label="Sana">
      <button
        v-for="d in days"
        :key="d.iso"
        class="day"
        :class="{ selected: d.iso === date }"
        role="tab"
        :aria-selected="d.iso === date"
        @click="date = d.iso"
      >
        <div class="dow">{{ d.dow }}</div>
        <div class="num">{{ d.num }}</div>
        <div class="mon">{{ d.mon }}</div>
      </button>
    </div>

    <p class="section-label" style="margin-top: 6px">Bo‘sh vaqtlar</p>

    <div v-if="loading" class="slots" aria-hidden="true">
      <div v-for="n in 8" :key="n" class="skeleton" style="height: 44px"></div>
    </div>
    <div v-else-if="error" class="alert">{{ error }}</div>
    <div v-else-if="!slots.length" class="empty">
      <div class="emo">🗓️</div>
      <p>Bu kunga bo‘sh vaqt yo‘q.<br />Boshqa sanani tanlang.</p>
    </div>

    <template v-else>
      <div v-for="g in grouped" :key="g.key" class="slot-group">
        <div class="slot-group-head">{{ g.label }}</div>
        <div class="slots">
          <button
            v-for="s in g.items"
            :key="s.start_utc"
            class="slot"
            :class="{ selected: s.start_utc === selectedStart }"
            @click="emit('select', s)"
          >
            {{ slotTime(s.start_local) }}
          </button>
        </div>
      </div>
    </template>
  </div>
</template>
