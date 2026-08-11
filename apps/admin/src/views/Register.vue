<script setup>
import { ref, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { api, ApiError } from '@tizbiz/api-client'
import { UserPlus, ArrowLeft, ArrowRight, Check, X } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth'
import { VERTICALS } from '../lib/verticals'
import PhoneInput from '../components/PhoneInput.vue'
import logoUrl from '../assets/logo.png'

const auth = useAuthStore()
const router = useRouter()

const STEPS = ['Yo‘nalish', 'Biznes', 'Manzil', 'Egasi']
const step = ref(1)
const vertical = ref(null)
const form = ref({
  bizName: '',
  staffCount: '',
  branches: '',
  slug: '',
  ownerName: '',
  phone: '',
  password: '',
})
const slugEdited = ref(false)
const loading = ref(false)
const error = ref('')

// --- slug availability ---
const slugState = ref('idle') // idle | checking | ok | taken | invalid
let slugTimer = null

function slugify(v) {
  return v
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
}

function checkSlug() {
  clearTimeout(slugTimer)
  const s = form.value.slug.trim()
  if (!s) {
    slugState.value = 'idle'
    return
  }
  slugState.value = 'checking'
  slugTimer = setTimeout(async () => {
    try {
      const r = await api.get(`/v1/auth/check-slug?slug=${encodeURIComponent(s)}`)
      slugState.value = !r.valid ? 'invalid' : r.available ? 'ok' : 'taken'
    } catch {
      slugState.value = 'idle'
    }
  }, 400)
}

watch(
  () => form.value.bizName,
  (v) => {
    if (!slugEdited.value) {
      form.value.slug = slugify(v)
      checkSlug()
    }
  },
)

const accent = computed(() => vertical.value?.accent || 'var(--primary)')

function pickVertical(v) {
  vertical.value = v
  error.value = ''
}

function next() {
  error.value = ''
  if (step.value === 1 && !vertical.value) {
    error.value = 'Biznes yo‘nalishini tanlang'
    return
  }
  if (step.value === 2 && !form.value.bizName.trim()) {
    error.value = 'Biznes nomini kiriting'
    return
  }
  if (step.value === 3) {
    if (!form.value.slug.trim()) {
      error.value = 'Manzil (slug) kiriting'
      return
    }
    if (slugState.value === 'taken') {
      error.value = 'Bu manzil allaqachon band'
      return
    }
    if (slugState.value === 'invalid') {
      error.value = 'Manzil noto‘g‘ri (kamida 3 belgi: a-z, 0-9, -)'
      return
    }
  }
  if (step.value < 4) step.value++
}

function back() {
  error.value = ''
  if (step.value > 1) step.value--
}

async function submit() {
  error.value = ''
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
        category: vertical.value?.category,
        engine: vertical.value?.engine,
        phone: form.value.phone.trim() || undefined,
        staff_count: form.value.staffCount !== '' ? Number(form.value.staffCount) : undefined,
        branches_count: form.value.branches !== '' ? Number(form.value.branches) : undefined,
      },
      owner: {
        phone: form.value.phone.trim(),
        name: form.value.ownerName.trim(),
        password: form.value.password,
      },
    })
    router.push('/')
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Ro‘yxatdan o‘tishda xatolik'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="auth-wrap">
    <div class="auth-card card" :style="{ '--accent': accent }">
      <div class="brand-row">
        <img :src="logoUrl" alt="TizBiz" class="brand-logo" />
        <span class="brand-suffix">Admin</span>
      </div>
      <h1>Ro'yxatdan o'tish</h1>
      <p class="muted" style="margin-top: -6px">Biznesingizni bir daqiqada ulang</p>

      <!-- Stepper -->
      <div class="stepper">
        <div
          v-for="(s, i) in STEPS"
          :key="s"
          class="stepper__item"
          :class="{ done: step > i + 1, active: step === i + 1 }"
        >
          <span class="stepper__dot">
            <Check v-if="step > i + 1" :size="13" />
            <template v-else>{{ i + 1 }}</template>
          </span>
          <span class="stepper__label">{{ s }}</span>
        </div>
      </div>

      <div v-if="error" class="alert alert-error" style="margin-top: 14px">{{ error }}</div>

      <!-- Step 1: vertical -->
      <div v-if="step === 1" class="step">
        <p class="step-title">Biznes yo'nalishini tanlang</p>
        <div class="vgrid">
          <button
            v-for="v in VERTICALS"
            :key="v.key"
            type="button"
            class="vcard"
            :class="{ selected: vertical?.key === v.key }"
            :style="{ '--vc': v.accent }"
            @click="pickVertical(v)"
          >
            <span class="vcard__icon"><component :is="v.icon" :size="22" /></span>
            <span class="vcard__body">
              <span class="vcard__title">{{ v.title }}</span>
              <span class="vcard__hint">{{ v.hint }}</span>
            </span>
            <span v-if="vertical?.key === v.key" class="vcard__check"><Check :size="15" /></span>
          </button>
        </div>
      </div>

      <!-- Step 2: business -->
      <div v-else-if="step === 2" class="step">
        <div class="field">
          <label for="bn">Biznes nomi</label>
          <input id="bn" v-model="form.bizName" placeholder="Aziza Beauty" autofocus />
        </div>
        <div class="field-row">
          <div class="field">
            <label for="sc">Xodimlar soni</label>
            <input id="sc" v-model="form.staffCount" type="number" min="0" placeholder="Masalan, 3" />
          </div>
          <div class="field">
            <label for="br">Filiallar soni</label>
            <input id="br" v-model="form.branches" type="number" min="0" placeholder="1" />
            <small class="muted">Bitta joy bo‘lsa — 1</small>
          </div>
        </div>
      </div>

      <!-- Step 3: slug -->
      <div v-else-if="step === 3" class="step">
        <div class="field">
          <label for="slug">Sayt manzili (slug)</label>
          <div class="slug-wrap" :class="'is-' + slugState">
            <input
              id="slug"
              v-model="form.slug"
              placeholder="aziza-tortlari"
              @input="slugEdited = true; checkSlug()"
            />
            <span class="slug-suffix">.tizbiz.uz</span>
          </div>
          <small v-if="slugState === 'checking'" class="muted">Tekshirilmoqda…</small>
          <small v-else-if="slugState === 'ok'" class="ok"><Check :size="12" /> Bo‘sh — olsa bo‘ladi</small>
          <small v-else-if="slugState === 'taken'" class="bad"><X :size="12" /> Band, boshqasini tanlang</small>
          <small v-else-if="slugState === 'invalid'" class="bad">Kamida 3 belgi: a-z, 0-9, -</small>
          <small v-else class="muted">Mijozlar shu manzildan navbat oladi</small>
        </div>
        <p class="preview">
          <span class="muted">Sizning saytingiz:</span>
          <strong>{{ form.slug || 'nomi' }}.tizbiz.uz</strong>
        </p>
      </div>

      <!-- Step 4: owner -->
      <div v-else-if="step === 4" class="step">
        <div class="field">
          <label for="on">Ismingiz</label>
          <input id="on" v-model="form.ownerName" placeholder="Aziza Karimova" autofocus />
        </div>
        <div class="field">
          <label for="ph">Telefon</label>
          <PhoneInput id="ph" v-model="form.phone" />
        </div>
        <div class="field">
          <label for="pw">Parol</label>
          <input id="pw" v-model="form.password" type="password" placeholder="Kamida 6 belgi" />
        </div>
      </div>

      <!-- Nav -->
      <div class="wizard-nav">
        <button v-if="step > 1" type="button" class="btn btn-ghost" :disabled="loading" @click="back">
          <ArrowLeft :size="16" /> Orqaga
        </button>
        <span style="flex: 1"></span>
        <button
          v-if="step < 4"
          type="button"
          class="btn btn-primary"
          :style="{ background: accent, borderColor: accent }"
          @click="next"
        >
          Davom etish <ArrowRight :size="16" />
        </button>
        <button
          v-else
          type="button"
          class="btn btn-primary"
          :style="{ background: accent, borderColor: accent }"
          :disabled="loading"
          @click="submit"
        >
          <span v-if="loading" class="spinner" style="width: 15px; height: 15px; border-width: 2px"></span>
          <UserPlus v-else :size="16" />
          {{ loading ? 'Yaratilmoqda…' : "Ro'yxatdan o'tish" }}
        </button>
      </div>

      <p class="muted" style="text-align: center; margin: 16px 0 0">
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
  max-width: 480px;
}
.brand-row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 16px;
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

/* Stepper */
.stepper {
  display: flex;
  gap: 6px;
  margin-top: 18px;
}
.stepper__item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  position: relative;
}
.stepper__dot {
  width: 26px;
  height: 26px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  font-size: 12px;
  font-weight: 700;
  background: var(--surface-2, rgba(127, 127, 127, 0.12));
  color: var(--text-muted);
  border: 1px solid var(--border);
  transition: all 0.15s;
}
.stepper__item.active .stepper__dot {
  background: var(--accent);
  border-color: var(--accent);
  color: #fff;
}
.stepper__item.done .stepper__dot {
  background: var(--accent);
  border-color: var(--accent);
  color: #fff;
  opacity: 0.85;
}
.stepper__label {
  font-size: 11px;
  color: var(--text-muted);
}
.stepper__item.active .stepper__label {
  color: var(--text);
  font-weight: 600;
}

.step {
  margin-top: 16px;
}
.step-title {
  font-size: 14px;
  font-weight: 600;
  margin: 0 0 12px;
}

/* Vertical cards */
.vgrid {
  display: grid;
  gap: 10px;
}
.vcard {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px;
  border: 1.5px solid var(--border);
  border-radius: 12px;
  background: var(--surface, transparent);
  color: var(--text); /* button doesn't inherit text colour -> theme-aware */
  cursor: pointer;
  text-align: left;
  transition: all 0.15s;
  position: relative;
}
.vcard:hover {
  border-color: var(--vc);
}
.vcard.selected {
  border-color: var(--vc);
  background: color-mix(in srgb, var(--vc) 10%, transparent);
}
.vcard__icon {
  width: 42px;
  height: 42px;
  flex: 0 0 42px;
  border-radius: 10px;
  display: grid;
  place-items: center;
  color: #fff;
  background: var(--vc);
}
.vcard__body {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.vcard__title {
  font-weight: 600;
  font-size: 14px;
}
.vcard__hint {
  font-size: 12px;
  color: var(--text-muted);
}
.vcard__check {
  margin-left: auto;
  color: var(--vc);
}

/* Slug */
.slug-wrap {
  display: flex;
  align-items: center;
  border: 1px solid var(--border);
  border-radius: 10px;
  overflow: hidden;
}
.slug-wrap input {
  border: none;
  flex: 1;
  background: transparent;
}
.slug-wrap input:focus {
  outline: none;
}
.slug-wrap.is-ok {
  border-color: #10b981;
}
.slug-wrap.is-taken,
.slug-wrap.is-invalid {
  border-color: #ef4444;
}
.slug-suffix {
  padding: 0 12px;
  color: var(--text-muted);
  font-size: 13px;
  white-space: nowrap;
}
small.ok {
  color: #10b981;
  display: inline-flex;
  align-items: center;
  gap: 3px;
}
small.bad {
  color: #ef4444;
  display: inline-flex;
  align-items: center;
  gap: 3px;
}
.preview {
  margin: 14px 0 0;
  padding: 12px 14px;
  border-radius: 10px;
  background: var(--surface-2, rgba(127, 127, 127, 0.08));
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.wizard-nav {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 22px;
}
.wizard-nav .btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
}
</style>
