<script setup>
import { ref, computed } from 'vue'
import PhoneInput from './PhoneInput.vue'

const props = defineProps({
  name: { type: String, default: '' },
  phone: { type: String, default: '' },
})
const emit = defineEmits(['submit', 'back'])

const name = ref(props.name)
const phone = ref(props.phone)
const touched = ref(false)

const invalid = computed(
  () => !name.value.trim() || phone.value.replace(/\D/g, '').length < 12,
)

function submit() {
  touched.value = true
  if (invalid.value) return
  emit('submit', { name: name.value.trim(), phone: phone.value.trim() })
}
</script>

<template>
  <div>
    <div class="step-head">
      <button class="back" aria-label="Orqaga" @click="emit('back')">‹</button>
      <h2>Ma'lumotlaringiz</h2>
    </div>

    <div class="field">
      <label for="n">Ismingiz</label>
      <input id="n" v-model="name" type="text" placeholder="Ism familiya" autocomplete="name" />
    </div>

    <div class="field">
      <label for="p">Telefon raqam</label>
      <PhoneInput id="p" v-model="phone" autocomplete="tel" />
    </div>

    <p v-if="touched && invalid" class="alert">
      Iltimos, ism va to‘g‘ri telefon raqamni kiriting.
    </p>

    <button class="btn" @click="submit">Davom etish</button>
  </div>
</template>
