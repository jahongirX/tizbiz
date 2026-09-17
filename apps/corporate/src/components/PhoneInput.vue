<script setup>
import { computed } from 'vue'

// Reusable masked Uzbek phone input (shared shape with the admin app).
// Always shows the "+998 " prefix and formats subscriber digits as
// "+998 XX XXX XX XX". v-model is the human-readable string.

const props = defineProps({
  modelValue: { type: String, default: '' },
  placeholder: { type: String, default: '+998 90 123 45 67' },
})
const emit = defineEmits(['update:modelValue'])

function subscriberDigits(str) {
  let d = String(str).replace(/\D/g, '')
  if (d.startsWith('998')) d = d.slice(3)
  return d.slice(0, 9)
}

function format(d) {
  let out = '+998 '
  if (d.length > 0) out += d.slice(0, 2)
  if (d.length > 2) out += ' ' + d.slice(2, 5)
  if (d.length > 5) out += ' ' + d.slice(5, 7)
  if (d.length > 7) out += ' ' + d.slice(7, 9)
  return out
}

const digits = computed(() => subscriberDigits(props.modelValue))
const display = computed(() => format(digits.value))

function onInput(e) {
  const d = subscriberDigits(e.target.value)
  e.target.value = format(d)
  emit('update:modelValue', d.length ? format(d) : '')
}

function onKeydown(e) {
  const el = e.target
  const start = el.selectionStart ?? 0
  if ((e.key === 'Backspace' || e.key === 'ArrowLeft') && start <= 5 && el.selectionStart === el.selectionEnd) {
    e.preventDefault()
  }
}

function onFocus(e) {
  const el = e.target
  if ((el.selectionStart ?? 0) < 5) {
    requestAnimationFrame(() => el.setSelectionRange(el.value.length, el.value.length))
  }
}

function onPaste(e) {
  e.preventDefault()
  const text = (e.clipboardData || window.clipboardData).getData('text')
  const d = subscriberDigits(text)
  e.target.value = format(d)
  emit('update:modelValue', d.length ? format(d) : '')
}
</script>

<template>
  <input
    type="tel"
    inputmode="tel"
    :value="display"
    :placeholder="placeholder"
    @input="onInput"
    @keydown="onKeydown"
    @focus="onFocus"
    @paste="onPaste"
  />
</template>
