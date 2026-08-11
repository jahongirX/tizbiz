<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { ApiError } from '@tizbiz/api-client'
import { LogIn } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth'
import { VERTICALS } from '../lib/verticals'
import PhoneInput from '../components/PhoneInput.vue'
import logoUrl from '../assets/logo.png'

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

// One-click demo login per business vertical — each opens into its own
// matching admin (accent + terminology + sample data).
const demoBusy = ref(null)
async function demoLogin(v) {
  error.value = ''
  demoBusy.value = v.key
  loading.value = true
  try {
    await auth.login(v.demoPhone, 'secret123')
    router.push('/')
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Demo hisobga kirishda xatolik'
  } finally {
    loading.value = false
    demoBusy.value = null
  }
}
</script>

<template>
  <div class="auth-wrap">
    <div class="auth-card card">
      <div class="brand-row">
        <img :src="logoUrl" alt="TizBiz" class="brand-logo" />
        <span class="brand-suffix">Admin</span>
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

      <div class="or-sep"><span>yoki demo sifatida kiring</span></div>

      <div class="demo-grid">
        <button
          v-for="v in VERTICALS"
          :key="v.key"
          type="button"
          class="demo-card"
          :style="{ '--vc': v.accent }"
          :disabled="loading"
          @click="demoLogin(v)"
        >
          <span class="demo-card__icon">
            <span
              v-if="demoBusy === v.key"
              class="spinner"
              style="width: 16px; height: 16px; border-width: 2px"
            ></span>
            <component :is="v.icon" v-else :size="18" />
          </span>
          <span class="demo-card__title">{{ v.title }}</span>
        </button>
      </div>

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
}
.brand-logo {
  height: 34px;
  width: auto;
  display: block;
}
.brand-suffix {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-soft, #6b7280);
  padding-left: 10px;
  border-left: 1px solid var(--border, #e5e7eb);
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
.demo-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}
.demo-card {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: var(--surface, transparent);
  color: var(--text); /* button doesn't inherit text colour -> theme-aware */
  cursor: pointer;
  text-align: left;
  transition: all 0.15s;
}
.demo-card:hover:not(:disabled) {
  border-color: var(--vc);
  background: color-mix(in srgb, var(--vc) 10%, transparent);
}
.demo-card:disabled {
  opacity: 0.6;
  cursor: default;
}
.demo-card__icon {
  width: 30px;
  height: 30px;
  flex: 0 0 30px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  color: #fff;
  background: var(--vc);
}
.demo-card__title {
  font-size: 12px;
  font-weight: 600;
  line-height: 1.2;
}
</style>
