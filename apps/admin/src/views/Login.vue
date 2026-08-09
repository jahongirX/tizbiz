<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { ApiError } from '@tizbiz/api-client'
import { LogIn } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth'
import PhoneInput from '../components/PhoneInput.vue'

const auth = useAuthStore()
const router = useRouter()

const phone = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')

async function submit() {
  error.value = ''
  if (phone.value.replace(/\D/g, '').length < 12) {
    error.value = 'Telefon raqamni to‘liq kiriting'
    return
  }
  if (!password.value) {
    error.value = 'Parolni kiriting'
    return
  }
  loading.value = true
  try {
    await auth.login(phone.value.trim(), password.value)
    router.push('/')
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Kirishda xatolik yuz berdi'
  } finally {
    loading.value = false
  }
}

// One-click demo login with the seeded owner account.
async function demoLogin() {
  error.value = ''
  loading.value = true
  try {
    await auth.login('+998900000001', 'secret123')
    router.push('/')
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Demo hisobga kirishda xatolik'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="auth-wrap">
    <div class="auth-card card">
      <div class="brand-row">
        <span class="logo">N</span>
        <strong>TizBiz Admin</strong>
      </div>
      <h1>Tizimga kirish</h1>
      <p class="muted mb-0" style="margin-top: -6px">Biznesingizni boshqaring</p>

      <form style="margin-top: 20px" @submit.prevent="submit">
        <div v-if="error" class="alert alert-error">{{ error }}</div>

        <div class="field">
          <label for="phone">Telefon</label>
          <PhoneInput id="phone" v-model="phone" autocomplete="username" />
        </div>
        <div class="field">
          <label for="pw">Parol</label>
          <input id="pw" v-model="password" type="password" placeholder="••••••••" autocomplete="current-password" />
        </div>

        <button class="btn btn-primary submit-btn" style="width: 100%" :disabled="loading" type="submit">
          <span v-if="loading" class="spinner" style="width: 15px; height: 15px; border-width: 2px"></span>
          <LogIn v-else :size="16" />
          {{ loading ? 'Kirilmoqda…' : 'Kirish' }}
        </button>
      </form>

      <div class="or-sep"><span>yoki</span></div>

      <button
        class="btn demo-btn"
        style="width: 100%"
        :disabled="loading"
        type="button"
        @click="demoLogin"
      >
        🚀 Demo sifatida kirish
      </button>

      <p class="muted" style="text-align: center; margin: 18px 0 0">
        Hisobingiz yo'qmi?
        <RouterLink to="/register">Ro'yxatdan o'tish</RouterLink>
      </p>
    </div>
  </div>
</template>

<style scoped>
.auth-wrap {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 20px;
}
.auth-card {
  width: 100%;
  max-width: 400px;
}
.brand-row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 18px;
  font-size: 16px;
}
.logo {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: var(--primary);
  color: #fff;
  display: grid;
  place-items: center;
  font-weight: 700;
}
h1 {
  font-size: 22px;
  margin-bottom: 6px;
}
.or-sep {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 16px 0 12px;
  color: var(--muted);
  font-size: 12px;
}
.or-sep::before,
.or-sep::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--border);
}
.submit-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}
.demo-btn {
  border: 1px dashed var(--primary);
  background: var(--primary-soft);
  color: var(--primary);
  font-weight: 600;
}
.demo-btn:hover:not(:disabled) {
  background: var(--primary);
  color: #fff;
}
</style>
