<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { ApiError } from '@tizbiz/api-client'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const router = useRouter()

const phone = ref('+998')
const password = ref('')
const error = ref('')
const busy = ref(false)

async function submit() {
  error.value = ''
  busy.value = true
  try {
    await auth.login(phone.value.trim(), password.value)
    router.push('/')
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Kirishda xatolik'
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <div class="auth">
    <div class="auth-card card">
      <div class="auth-brand">💬 TizBiz <span class="tag" style="color: var(--brand)">SMS</span></div>
      <p class="muted" style="margin: 0 0 20px">SMS shlyuz boshqaruvi</p>

      <div v-if="error" class="alert err">{{ error }}</div>

      <form @submit.prevent="submit">
        <div class="field">
          <label>Telefon</label>
          <input v-model="phone" type="tel" autocomplete="username" placeholder="+998901234567" />
        </div>
        <div class="field">
          <label>Parol</label>
          <input v-model="password" type="password" autocomplete="current-password" placeholder="••••••••" />
        </div>
        <button class="btn" style="width: 100%" type="submit" :disabled="busy">
          {{ busy ? 'Kirilmoqda…' : 'Kirish' }}
        </button>
      </form>
    </div>
  </div>
</template>
