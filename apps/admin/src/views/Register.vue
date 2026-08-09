<script setup>
import { ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { ApiError } from '@tizbiz/api-client'
import { UserPlus } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth'
import PhoneInput from '../components/PhoneInput.vue'

const auth = useAuthStore()
const router = useRouter()

const form = ref({
  bizName: '',
  slug: '',
  category: '',
  ownerName: '',
  phone: '',
  password: '',
})
const slugEdited = ref(false)
const loading = ref(false)
const error = ref('')

const categories = [
  { v: 'barber', l: 'Sartaroshxona' },
  { v: 'salon', l: 'Go\'zallik saloni' },
  { v: 'clinic', l: 'Klinika' },
  { v: 'dentistry', l: 'Stomatologiya' },
  { v: 'diagnostics', l: 'Diagnostika (UZI)' },
  { v: 'tutor', l: 'Repetitor' },
  { v: 'other', l: 'Boshqa' },
]

function slugify(v) {
  return v
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
}

watch(
  () => form.value.bizName,
  (v) => {
    if (!slugEdited.value) form.value.slug = slugify(v)
  },
)

async function submit() {
  error.value = ''
  if (!form.value.bizName.trim()) {
    error.value = 'Biznes nomini kiriting'
    return
  }
  if (!form.value.slug.trim()) {
    error.value = 'Manzil (slug) ni kiriting'
    return
  }
  if (!form.value.ownerName.trim()) {
    error.value = 'Ismingizni kiriting'
    return
  }
  if (form.value.phone.replace(/\D/g, '').length < 12) {
    error.value = 'Telefon raqamni to‘liq kiriting'
    return
  }
  if (form.value.password.length < 6) {
    error.value = 'Parol kamida 6 ta belgidan iborat bo‘lsin'
    return
  }
  loading.value = true
  try {
    await auth.register({
      business: {
        name: form.value.bizName.trim(),
        slug: form.value.slug.trim(),
        category: form.value.category || undefined,
        phone: form.value.phone.trim() || undefined,
      },
      owner: {
        phone: form.value.phone.trim(),
        name: form.value.ownerName.trim(),
        password: form.value.password,
      },
    })
    router.push('/')
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Ro\'yxatdan o\'tishda xatolik'
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
      <h1>Ro'yxatdan o'tish</h1>
      <p class="muted" style="margin-top: -6px">Biznesingizni bir daqiqada ulang</p>

      <form style="margin-top: 18px" @submit.prevent="submit">
        <div v-if="error" class="alert alert-error">{{ error }}</div>

        <h3 style="font-size: 13px; text-transform: uppercase; color: var(--text-muted); letter-spacing: 0.03em">
          Biznes
        </h3>
        <div class="field">
          <label for="bn">Biznes nomi</label>
          <input id="bn" v-model="form.bizName" placeholder="Aziza Beauty" />
        </div>
        <div class="field-row">
          <div class="field">
            <label for="slug">Manzil (slug)</label>
            <input id="slug" v-model="form.slug" placeholder="aziza-beauty" @input="slugEdited = true" />
            <small class="muted">{{ form.slug || 'slug' }}.tizbiz.uz</small>
          </div>
          <div class="field">
            <label for="cat">Kategoriya</label>
            <select id="cat" v-model="form.category">
              <option value="">Tanlang…</option>
              <option v-for="c in categories" :key="c.v" :value="c.v">{{ c.l }}</option>
            </select>
          </div>
        </div>

        <h3 style="font-size: 13px; text-transform: uppercase; color: var(--text-muted); letter-spacing: 0.03em; margin-top: 18px">
          Egasi
        </h3>
        <div class="field">
          <label for="on">Ismingiz</label>
          <input id="on" v-model="form.ownerName" placeholder="Aziza Karimova" />
        </div>
        <div class="field">
          <label for="ph">Telefon</label>
          <PhoneInput id="ph" v-model="form.phone" />
        </div>
        <div class="field">
          <label for="pw">Parol</label>
          <input id="pw" v-model="form.password" type="password" placeholder="Kamida 6 belgi" />
        </div>

        <button class="btn btn-primary submit-btn" style="width: 100%" :disabled="loading" type="submit">
          <span v-if="loading" class="spinner" style="width: 15px; height: 15px; border-width: 2px"></span>
          <UserPlus v-else :size="16" />
          {{ loading ? 'Yaratilmoqda…' : 'Ro\'yxatdan o\'tish' }}
        </button>
      </form>

      <p class="muted" style="text-align: center; margin: 18px 0 0">
        Hisobingiz bormi?
        <RouterLink to="/login">Kirish</RouterLink>
      </p>
    </div>
  </div>
</template>

<style scoped>
.auth-wrap {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 24px 20px;
}
.auth-card {
  width: 100%;
  max-width: 440px;
}
.brand-row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 16px;
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
.submit-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}
</style>
