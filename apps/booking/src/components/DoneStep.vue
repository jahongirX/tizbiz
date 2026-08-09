<script setup>
import { soms, prettyLocal } from '../format.js'

defineProps({
  service: { type: Object, required: true },
  staff: { type: Object, required: true },
  slot: { type: Object, required: true },
  payLoading: { type: Boolean, default: false },
  payError: { type: String, default: '' },
})
const emit = defineEmits(['pay', 'restart'])
</script>

<template>
  <div>
    <div class="done-hero">
      <div class="check">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6"
          stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M20 6L9 17l-5-5" />
        </svg>
      </div>
      <h2>Navbat band qilindi!</h2>
      <p>{{ prettyLocal(slot.start_local) }}</p>
    </div>

    <div class="summary">
      <div class="row">
        <span class="k">Xizmat</span>
        <span class="v">{{ service.name }}</span>
      </div>
      <div class="row">
        <span class="k">Mutaxassis</span>
        <span class="v">{{ staff.name }}</span>
      </div>
    </div>

    <template v-if="service.deposit_tiyin > 0">
      <div class="deposit-callout">
        <span class="ico">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <rect x="2" y="5" width="20" height="14" rx="2" />
            <line x1="2" y1="10" x2="22" y2="10" />
          </svg>
        </span>
        <div class="txt">
          <div class="amt">{{ soms(service.deposit_tiyin) }} depozit</div>
          <div class="hint">Joyingizni kafolatlash uchun hozir to‘lang.</div>
        </div>
      </div>
      <div v-if="payError" class="alert">{{ payError }}</div>
      <button class="btn pay" :disabled="payLoading" @click="emit('pay')">
        <template v-if="!payLoading">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"
            stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <rect x="2" y="5" width="20" height="14" rx="2" />
            <line x1="2" y1="10" x2="22" y2="10" />
          </svg>
          Depozitni to‘lash (Payme)
        </template>
        <template v-else>Yo‘naltirilmoqda…</template>
      </button>
    </template>

    <button class="btn ghost" @click="emit('restart')">Yana navbat olish</button>
  </div>
</template>
