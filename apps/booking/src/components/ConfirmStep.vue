<script setup>
import { ref, computed, watch } from 'vue'
import PhoneInput from './PhoneInput.vue'
import { soms, duration, prettyLocal } from '../format.js'

const props = defineProps({
  business: { type: Object, required: true },
  service: { type: Object, required: true },
  staff: { type: Object, required: true },
  slot: { type: Object, required: true },
  client: { type: Object, required: true },
  submitting: { type: Boolean, default: false },
  error: { type: String, default: '' },
})
const emit = defineEmits(['confirm', 'back', 'update:client'])

// The client's details live here instead of a separate step: a returning
// visitor sees them prefilled and only has to confirm.
const name = ref(props.client.name || '')
const phone = ref(props.client.phone || '')
const editing = ref(!props.client.phone)
const touched = ref(false)

const invalid = computed(() => !name.value.trim() || phone.value.replace(/\D/g, '').length < 12)

watch([name, phone], () => {
  emit('update:client', { name: name.value.trim(), phone: phone.value.trim() })
})

function onConfirm() {
  touched.value = true
  if (invalid.value) {
    editing.value = true
    return
  }
  emit('update:client', { name: name.value.trim(), phone: phone.value.trim() })
  emit('confirm')
}
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

    <div v-if="!editing" class="you">
      <div>
        <div class="you-name">{{ name }}</div>
        <div class="you-phone">{{ phone }}</div>
      </div>
      <button class="link" @click="editing = true">O‘zgartirish</button>
    </div>

    <template v-else>
      <div class="field">
        <label for="n">Ismingiz</label>
        <input id="n" v-model="name" type="text" placeholder="Ism familiya" autocomplete="name" />
      </div>
      <div class="field">
        <label for="p">Telefon raqam</label>
        <PhoneInput id="p" v-model="phone" autocomplete="tel" />
      </div>
    </template>

    <p v-if="touched && invalid" class="alert">
      Iltimos, ism va to‘g‘ri telefon raqamni kiriting.
    </p>

    <div v-if="error" class="alert">{{ error }}</div>

    <button class="btn" :disabled="submitting" @click="onConfirm">
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

<style scoped>
.you {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin: 14px 0 4px;
  padding: 12px 14px;
  border: 1px solid var(--line, rgba(255, 255, 255, 0.12));
  border-radius: 12px;
}
.you-name {
  font-weight: 600;
}
.you-phone {
  font-size: 13px;
  opacity: 0.7;
}
.link {
  border: 0;
  background: none;
  padding: 0;
  color: var(--accent, #6b8afd);
  font: inherit;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
}
</style>
