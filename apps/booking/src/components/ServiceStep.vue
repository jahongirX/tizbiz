<script setup>
// Multi-select: a barbershop visit is often "soch + soqol", so the step adds up
// the chosen services and the slot search then looks for one long enough.
import { computed } from 'vue'
import { soms, duration } from '../format.js'

const props = defineProps({
  services: { type: Array, default: () => [] },
  selectedIds: { type: Array, default: () => [] },
})
const emit = defineEmits(['toggle', 'next'])

const chosen = computed(() => props.services.filter((s) => props.selectedIds.includes(s.id)))
const totalMin = computed(() => chosen.value.reduce((n, s) => n + (Number(s.duration_min) || 0), 0))
const totalPrice = computed(() => chosen.value.reduce((n, s) => n + (Number(s.price_tiyin) || 0), 0))
const totalDeposit = computed(() =>
  chosen.value.reduce((n, s) => n + (Number(s.deposit_tiyin) || 0), 0),
)

function isOn(id) {
  return props.selectedIds.includes(id)
}
</script>

<template>
  <div>
    <div class="step-head">
      <h2>Xizmatni tanlang</h2>
    </div>
    <p class="section-label">Bir nechtasini birga tanlashingiz mumkin</p>

    <div v-if="!services.length" class="empty">
      <div class="emo">📋</div>
      <p>Hozircha xizmatlar mavjud emas.</p>
    </div>

    <button
      v-for="s in services"
      :key="s.id"
      class="card"
      :class="{ selected: isOn(s.id) }"
      :aria-pressed="isOn(s.id)"
      @click="emit('toggle', s)"
    >
      <span class="tick" :class="{ on: isOn(s.id) }" aria-hidden="true">
        <svg v-if="isOn(s.id)" viewBox="0 0 24 24" fill="none" stroke="currentColor"
          stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
          <path d="M20 6L9 17l-5-5" />
        </svg>
      </span>
      <div class="grow">
        <div class="title">{{ s.name }}</div>
        <div class="meta">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <circle cx="12" cy="12" r="9" />
            <path d="M12 7v5l3 2" />
          </svg>
          {{ duration(s.duration_min) }}
        </div>
      </div>
      <div class="end">
        <div class="price">{{ soms(s.price_tiyin) }}</div>
        <span v-if="s.deposit_tiyin > 0" class="badge deposit">
          depozit {{ soms(s.deposit_tiyin) }}
        </span>
      </div>
    </button>

    <div v-if="chosen.length" class="basket">
      <div class="basket-sum">
        <strong>{{ soms(totalPrice) }}</strong>
        <span>{{ chosen.length }} ta xizmat · {{ duration(totalMin) }}</span>
        <span v-if="totalDeposit > 0" class="basket-dep">depozit {{ soms(totalDeposit) }}</span>
      </div>
      <button class="btn" @click="emit('next')">Davom etish</button>
    </div>
  </div>
</template>

<style scoped>
.tick {
  width: 22px;
  height: 22px;
  flex: 0 0 auto;
  border-radius: 6px;
  border: 1.5px solid var(--border);
  display: grid;
  place-items: center;
  color: #fff;
  margin-right: 12px;
}
.tick.on {
  background: var(--brand);
  border-color: var(--brand);
}
.tick svg {
  width: 13px;
  height: 13px;
}

/* Sticky summary: the total has to stay visible while the list scrolls. */
.basket {
  position: sticky;
  bottom: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  flex-wrap: wrap;
  margin-top: 14px;
  padding: 12px 14px;
  border: 1px solid var(--border);
  border-radius: 14px;
  background: var(--surface);
  box-shadow: 0 -6px 20px rgba(0, 0, 0, 0.18);
}
.basket-sum {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.basket-sum strong {
  font-size: 17px;
}
.basket-sum span {
  font-size: 12.5px;
  color: var(--muted);
}
.basket-dep {
  color: var(--warning, #d9a441) !important;
}
.basket .btn {
  margin: 0;
  width: auto;
  padding-inline: 22px;
  flex: 0 0 auto;
}
</style>
