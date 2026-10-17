<script setup>
// Guest-count step for the wedding-hall engine. No packages — the client picked
// a session (morning/evening) which carries a flat per-guest price; here they
// only enter the guest count. Guests drive tables (≈10/table) and the total.
import { ref, computed } from 'vue'

const props = defineProps({
  guests: { type: Number, default: 100 },
  perGuest: { type: Number, default: 20000 }, // so'm per guest for the chosen session
  canBack: { type: Boolean, default: false },
})
const emit = defineEmits(['submit', 'back'])

const MIN = 30
const MAX = 1000
const SEATS_PER_TABLE = 10

const count = ref(props.guests || 100)

function clamp(n) {
  n = Math.round(Number(n) || 0)
  return Math.min(MAX, Math.max(MIN, n))
}
function step(delta) {
  count.value = clamp(count.value + delta)
}
function onInput(e) {
  const v = parseInt(e.target.value, 10)
  count.value = Number.isNaN(v) ? MIN : v
}
function onBlur() {
  count.value = clamp(count.value)
}

function money(som) {
  return Math.round(Number(som) || 0).toLocaleString('ru-RU').replace(/\s/g, ' ') + " so'm"
}
const tables = computed(() => Math.ceil(clamp(count.value) / SEATS_PER_TABLE))
const perLabel = computed(() => money(props.perGuest))
const totalLabel = computed(() => money(clamp(count.value) * props.perGuest))

function submit() {
  emit('submit', clamp(count.value))
}
</script>

<template>
  <div>
    <div class="step-head">
      <button v-if="canBack" class="back" aria-label="Orqaga" @click="emit('back')">‹</button>
      <h2>Mehmonlar soni</h2>
    </div>

    <p class="section-label">Nechta mehmon kutilyapti?</p>

    <div class="guest-picker">
      <button class="gp-btn" aria-label="Kamaytirish" @click="step(-10)">−</button>
      <input
        class="gp-input"
        type="number"
        inputmode="numeric"
        :min="MIN"
        :max="MAX"
        :value="count"
        @input="onInput"
        @blur="onBlur"
      />
      <button class="gp-btn" aria-label="Ko‘paytirish" @click="step(10)">+</button>
    </div>
    <p class="gp-hint">{{ MIN }}–{{ MAX }} kishi · har stolga ~{{ SEATS_PER_TABLE }} kishi</p>

    <div class="gp-summary">
      <div class="gp-row">
        <span>Stollar soni</span>
        <b>{{ tables }} ta stol</b>
      </div>
      <div class="gp-row">
        <span>Bir kishiga</span>
        <b>{{ perLabel }}</b>
      </div>
      <div class="gp-row total">
        <span>Jami taxminan</span>
        <b>{{ totalLabel }}</b>
      </div>
    </div>

    <button class="cta" @click="submit">Davom etish</button>
  </div>
</template>

<style scoped>
.guest-picker {
  display: flex;
  align-items: center;
  gap: 12px;
  justify-content: center;
  margin: 8px 0 6px;
}
.gp-btn {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  border: 1px solid var(--line, #2a2d3a);
  background: var(--card, #171a24);
  color: inherit;
  font-size: 28px;
  line-height: 1;
  cursor: pointer;
}
.gp-btn:active {
  transform: scale(0.96);
}
.gp-input {
  width: 130px;
  height: 56px;
  border-radius: 16px;
  border: 1px solid var(--line, #2a2d3a);
  background: var(--card, #171a24);
  color: inherit;
  text-align: center;
  font-size: 28px;
  font-weight: 700;
  -moz-appearance: textfield;
  appearance: textfield;
}
.gp-input::-webkit-outer-spin-button,
.gp-input::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}
.gp-hint {
  text-align: center;
  font-size: 13px;
  color: var(--muted, #8b90a3);
  margin: 0 0 16px;
}
.gp-summary {
  border: 1px solid var(--line, #2a2d3a);
  border-radius: 16px;
  padding: 6px 14px;
  margin-bottom: 18px;
}
.gp-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  padding: 11px 0;
  border-bottom: 1px solid var(--line, #2a2d3a);
}
.gp-row:last-child {
  border-bottom: none;
}
.gp-row.total {
  font-size: 16px;
}
.gp-row.total b {
  color: var(--brand, #8b5cf6);
}
.gp-row b {
  text-align: right;
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
</style>
