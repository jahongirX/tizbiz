<script setup>
import { soms, duration } from '../format.js'

defineProps({
  services: { type: Array, default: () => [] },
  selectedId: { type: [Number, String, null], default: null },
})
const emit = defineEmits(['select'])
</script>

<template>
  <div>
    <div class="step-head">
      <h2>Xizmatni tanlang</h2>
    </div>

    <div v-if="!services.length" class="empty">
      <div class="emo">📋</div>
      <p>Hozircha xizmatlar mavjud emas.</p>
    </div>

    <button
      v-for="s in services"
      :key="s.id"
      class="card"
      :class="{ selected: s.id === selectedId }"
      @click="emit('select', s)"
    >
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
      <span class="chev">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"
          stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M9 18l6-6-6-6" />
        </svg>
      </span>
    </button>
  </div>
</template>
