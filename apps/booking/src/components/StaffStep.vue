<script setup>
defineProps({
  staff: { type: Array, default: () => [] },
  selectedId: { type: [Number, String, null], default: null },
})
const emit = defineEmits(['select', 'back'])

function initials(name) {
  return String(name || '?')
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p[0])
    .join('')
    .toUpperCase()
}
</script>

<template>
  <div>
    <div class="step-head">
      <button class="back" aria-label="Orqaga" @click="emit('back')">‹</button>
      <h2>Mutaxassisni tanlang</h2>
    </div>

    <div v-if="!staff.length" class="empty">
      <div class="emo">👤</div>
      <p>Mutaxassislar topilmadi.</p>
    </div>

    <button
      v-for="m in staff"
      :key="m.id"
      class="card"
      :class="{ selected: m.id === selectedId }"
      @click="emit('select', m)"
    >
      <span class="avatar">{{ initials(m.name) }}</span>
      <div class="grow">
        <div class="title">{{ m.name }}</div>
        <div v-if="m.specialization" class="meta">{{ m.specialization }}</div>
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
