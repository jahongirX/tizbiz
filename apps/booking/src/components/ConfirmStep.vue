<script setup>
import { soms, duration, prettyLocal } from '../format.js'

defineProps({
  business: { type: Object, required: true },
  service: { type: Object, required: true },
  staff: { type: Object, required: true },
  slot: { type: Object, required: true },
  client: { type: Object, required: true },
  submitting: { type: Boolean, default: false },
  error: { type: String, default: '' },
})
const emit = defineEmits(['confirm', 'back'])
</script>

<template>
  <div>
    <div class="step-head">
      <button class="back" aria-label="Orqaga" @click="emit('back')">‹</button>
      <h2>Tasdiqlash</h2>
    </div>

    <div class="summary">
      <div class="row">
        <span class="k">Xizmat</span>
        <span class="v">{{ service.name }} · {{ duration(service.duration_min) }}</span>
      </div>
      <div class="row">
        <span class="k">Mutaxassis</span>
        <span class="v">{{ staff.name }}</span>
      </div>
      <div class="row">
        <span class="k">Vaqt</span>
        <span class="v accent">{{ prettyLocal(slot.start_local) }}</span>
      </div>
      <div class="row">
        <span class="k">Mijoz</span>
        <span class="v">{{ client.name }}<br />{{ client.phone }}</span>
      </div>
      <div class="row total">
        <span class="k">Narx</span>
        <span class="v">{{ soms(service.price_tiyin) }}</span>
      </div>
    </div>

    <div v-if="service.deposit_tiyin > 0" class="deposit-callout">
      <span class="ico">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
          stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <rect x="2" y="5" width="20" height="14" rx="2" />
          <line x1="2" y1="10" x2="22" y2="10" />
        </svg>
      </span>
      <div class="txt">
        <div class="amt">{{ soms(service.deposit_tiyin) }} depozit</div>
        <div class="hint">Joyingizni kafolatlaydi. Tasdiqlaganingizdan so‘ng to‘lanadi.</div>
      </div>
    </div>

    <div v-if="error" class="alert">{{ error }}</div>

    <button class="btn" :disabled="submitting" @click="emit('confirm')">
      <template v-if="!submitting">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"
          stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M20 6L9 17l-5-5" />
        </svg>
        Navbatni tasdiqlash
      </template>
      <template v-else>Yuborilmoqda…</template>
    </button>
  </div>
</template>
