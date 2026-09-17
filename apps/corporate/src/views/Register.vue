<script setup>
import { ref, computed, watch } from 'vue'
import { api, auth, ApiError, config } from '@tizbiz/api-client'
import PhoneInput from '../components/PhoneInput.vue'

// Verticals (self-contained — no icon lib). Emoji instead of lucide so the
// corporate bundle stays dependency-free.
const VERTICALS = [
  { key: 'barber', engine: 'slot', category: 'barber', title: 'Barber / Go‘zallik saloni', hint: 'Sartaroshxona, go‘zallik, styling', emoji: '✂️', accent: '#3b82f6' },
  { key: 'cafe', engine: 'catalog', category: 'cafe', title: 'Kafe / Restoran / Tortlar', hint: 'Kafe, restoran, shirinliklar, tortlar', emoji: '🍰', accent: '#f97316' },
  { key: 'clinic', engine: 'medical', category: 'clinic', title: 'Klinika / UZI / Stomatologiya', hint: 'Klinika, diagnostika, stomatologiya', emoji: '🩺', accent: '#10b981' },
  { key: 'rental', engine: 'slot', category: 'rental', title: 'To‘yxona / Ijara', hint: 'To‘yxona, kelin libosi, ijara', emoji: '💍', accent: '#8b5cf6' },
]

const ADMIN_URL = `https://admin.${config.rootDomain || 'tizbiz.uz'}/app/`

const STEPS = ['Yo‘nalish', 'Biznes', 'Manzil', 'Egasi']
const step = ref(1)
const vertical = ref(null)
const form = ref({ bizName: '', staffCount: '', branches: '', slug: '', ownerName: '', phone: '', password: '' })
const slugEdited = ref(false)
const loading = ref(false)
const error = ref('')

const slugState = ref('idle') // idle | checking | ok | taken | invalid
let slugTimer = null

function slugify(v) {
  return v.toLowerCase().replace(/[^a-z0-9\s-]/g, '').trim().replace(/\s+/g, '-').replace(/-+/g, '-')
}

function checkSlug() {
  clearTimeout(slugTimer)
  const s = form.value.slug.trim()
  if (!s) { slugState.value = 'idle'; return }
  slugState.value = 'checking'
  slugTimer = setTimeout(async () => {
    try {
      const r = await api.get(`/v1/auth/check-slug?slug=${encodeURIComponent(s)}`)
      slugState.value = !r.valid ? 'invalid' : r.available ? 'ok' : 'taken'
    } catch { slugState.value = 'idle' }
  }, 400)
}

watch(() => form.value.bizName, (v) => {
  if (!slugEdited.value) { form.value.slug = slugify(v); checkSlug() }
})

const accent = computed(() => vertical.value?.accent || '#2563eb')

function next() {
  error.value = ''
  if (step.value === 1 && !vertical.value) { error.value = 'Biznes yo‘nalishini tanlang'; return }
  if (step.value === 2 && !form.value.bizName.trim()) { error.value = 'Biznes nomini kiriting'; return }
  if (step.value === 3) {
    if (!form.value.slug.trim()) { error.value = 'Manzil (slug) kiriting'; return }
    if (slugState.value === 'taken') { error.value = 'Bu manzil allaqachon band'; return }
    if (slugState.value === 'invalid') { error.value = 'Manzil noto‘g‘ri (kamida 3 belgi: a-z, 0-9, -)'; return }
  }
  if (step.value < 4) step.value++
}
function back() { error.value = ''; if (step.value > 1) step.value-- }

async function submit() {
  error.value = ''
  if (!form.value.ownerName.trim()) { error.value = 'Ismingizni kiriting'; return }
  if (form.value.phone.replace(/\D/g, '').length < 12) { error.value = 'Telefon raqamni to‘liq kiriting'; return }
  if (form.value.password.length < 6) { error.value = 'Parol kamida 6 ta belgidan iborat bo‘lsin'; return }
  loading.value = true
  try {
    const res = await api.post('/v1/auth/register', {
      business: {
        name: form.value.bizName.trim(),
        slug: form.value.slug.trim(),
        category: vertical.value?.category,
        engine: vertical.value?.engine,
        phone: form.value.phone.trim() || undefined,
        staff_count: form.value.staffCount !== '' ? Number(form.value.staffCount) : undefined,
        branches_count: form.value.branches !== '' ? Number(form.value.branches) : undefined,
      },
      owner: { phone: form.value.phone.trim(), name: form.value.ownerName.trim(), password: form.value.password },
    })
    // Hand the fresh token to the admin subdomain (localStorage is per-origin):
    // pass it in the URL hash so it never reaches server logs.
    if (res.token) auth.set(res.token)
    window.location.href = ADMIN_URL + '#t=' + encodeURIComponent(res.token || '')
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Ro‘yxatdan o‘tishda xatolik'
    loading.value = false
  }
}
</script>

<template>
  <div class="auth-wrap">
    <div class="auth-card" :style="{ '--accent': accent }">
      <a href="/" class="brand-row">
        <span class="brand-logo">TizBiz</span>
        <span class="brand-suffix">Ro‘yxatdan o‘tish</span>
      </a>
      <p class="muted">Biznesingizni bir daqiqada ulang — bepul</p>

      <div class="stepper">
        <div v-for="(s, i) in STEPS" :key="s" class="stepper__item" :class="{ done: step > i + 1, active: step === i + 1 }">
          <span class="stepper__dot"><template v-if="step > i + 1">✓</template><template v-else>{{ i + 1 }}</template></span>
          <span class="stepper__label">{{ s }}</span>
        </div>
      </div>

      <div v-if="error" class="alert-error">{{ error }}</div>

      <!-- Step 1: vertical -->
      <div v-if="step === 1" class="step">
        <p class="step-title">Biznes yo‘nalishini tanlang</p>
        <div class="vgrid">
          <button v-for="v in VERTICALS" :key="v.key" type="button" class="vcard" :class="{ selected: vertical?.key === v.key }" :style="{ '--vc': v.accent }" @click="vertical = v; error = ''">
            <span class="vcard__icon">{{ v.emoji }}</span>
            <span class="vcard__body">
              <span class="vcard__title">{{ v.title }}</span>
              <span class="vcard__hint">{{ v.hint }}</span>
            </span>
            <span v-if="vertical?.key === v.key" class="vcard__check">✓</span>
          </button>
        </div>
      </div>

      <!-- Step 2: business -->
      <div v-else-if="step === 2" class="step">
        <div class="field"><label>Biznes nomi</label><input v-model="form.bizName" placeholder="Aziza Tortlari" /></div>
        <div class="field-row">
          <div class="field"><label>Xodimlar soni</label><input v-model="form.staffCount" type="number" min="0" placeholder="3" /></div>
          <div class="field"><label>Filiallar soni</label><input v-model="form.branches" type="number" min="0" placeholder="1" /></div>
        </div>
      </div>

      <!-- Step 3: slug -->
      <div v-else-if="step === 3" class="step">
        <div class="field">
          <label>Sayt manzili</label>
          <div class="slug-wrap" :class="'is-' + slugState">
            <input v-model="form.slug" placeholder="aziza-tortlari" @input="slugEdited = true; checkSlug()" />
            <span class="slug-suffix">.tizbiz.uz</span>
          </div>
          <small v-if="slugState === 'checking'" class="muted">Tekshirilmoqda…</small>
          <small v-else-if="slugState === 'ok'" class="ok">✓ Bo‘sh — olsa bo‘ladi</small>
          <small v-else-if="slugState === 'taken'" class="bad">✕ Band, boshqasini tanlang</small>
          <small v-else-if="slugState === 'invalid'" class="bad">Kamida 3 belgi: a-z, 0-9, -</small>
          <small v-else class="muted">Mijozlar shu manzildan navbat oladi</small>
        </div>
        <p class="preview"><span class="muted">Sizning saytingiz:</span> <strong>{{ form.slug || 'nomi' }}.tizbiz.uz</strong></p>
      </div>

      <!-- Step 4: owner -->
      <div v-else-if="step === 4" class="step">
        <div class="field"><label>Ismingiz</label><input v-model="form.ownerName" placeholder="Aziza Karimova" /></div>
        <div class="field"><label>Telefon</label><PhoneInput v-model="form.phone" /></div>
        <div class="field"><label>Parol</label><input v-model="form.password" type="password" placeholder="Kamida 6 belgi" /></div>
      </div>

      <div class="wizard-nav">
        <button v-if="step > 1" type="button" class="btn ghost" :disabled="loading" @click="back">← Orqaga</button>
        <span style="flex: 1"></span>
        <button v-if="step < 4" type="button" class="btn" :style="{ background: accent, borderColor: accent }" @click="next">Davom etish →</button>
        <button v-else type="button" class="btn" :style="{ background: accent, borderColor: accent }" :disabled="loading" @click="submit">
          {{ loading ? 'Yaratilmoqda…' : "Ro'yxatdan o'tish" }}
        </button>
      </div>

      <p class="foot">Hisobingiz bormi? <a :href="ADMIN_URL + 'login'">Kirish</a></p>
    </div>
  </div>
</template>

<style scoped>
.auth-wrap { min-height: 100vh; display: grid; place-items: center; padding: 24px 20px; background: #f6f7fb; }
.auth-card { width: 100%; max-width: 480px; background: #fff; border: 1px solid #e5e7eb; border-radius: 18px; padding: 28px; box-shadow: 0 10px 40px rgba(0,0,0,.06); }
.brand-row { display: flex; align-items: center; gap: 10px; text-decoration: none; margin-bottom: 4px; }
.brand-logo { font-size: 22px; font-weight: 800; color: #2563eb; }
.brand-suffix { font-size: 15px; font-weight: 600; color: #6b7280; padding-left: 10px; border-left: 1px solid #e5e7eb; }
.muted { color: #6b7280; font-size: 13px; margin: 2px 0 0; }
.alert-error { margin-top: 14px; background: #fef2f2; color: #b91c1c; border: 1px solid #fecaca; border-radius: 10px; padding: 10px 12px; font-size: 13px; }

.stepper { display: flex; gap: 6px; margin-top: 18px; }
.stepper__item { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 6px; }
.stepper__dot { width: 26px; height: 26px; border-radius: 50%; display: grid; place-items: center; font-size: 12px; font-weight: 700; background: #eef1f6; color: #9ca3af; border: 1px solid #e5e7eb; }
.stepper__item.active .stepper__dot, .stepper__item.done .stepper__dot { background: var(--accent); border-color: var(--accent); color: #fff; }
.stepper__label { font-size: 11px; color: #9ca3af; }
.stepper__item.active .stepper__label { color: #111827; font-weight: 600; }

.step { margin-top: 16px; }
.step-title { font-size: 14px; font-weight: 600; margin: 0 0 12px; }
.field { margin-bottom: 12px; display: flex; flex-direction: column; gap: 6px; }
.field label { font-size: 13px; font-weight: 500; color: #374151; }
.field input { width: 100%; padding: 11px 13px; border: 1px solid #d1d5db; border-radius: 10px; font-size: 14px; box-sizing: border-box; }
.field input:focus { outline: none; border-color: var(--accent); }
.field-row { display: flex; gap: 12px; }
.field-row .field { flex: 1; }

.vgrid { display: grid; gap: 10px; }
.vcard { display: flex; align-items: center; gap: 12px; padding: 14px; border: 1.5px solid #e5e7eb; border-radius: 12px; background: #fff; cursor: pointer; text-align: left; }
.vcard:hover { border-color: var(--vc); }
.vcard.selected { border-color: var(--vc); background: color-mix(in srgb, var(--vc) 10%, transparent); }
.vcard__icon { width: 42px; height: 42px; flex: 0 0 42px; border-radius: 10px; display: grid; place-items: center; font-size: 22px; background: color-mix(in srgb, var(--vc) 15%, transparent); }
.vcard__body { display: flex; flex-direction: column; gap: 2px; }
.vcard__title { font-weight: 600; font-size: 14px; color: #111827; }
.vcard__hint { font-size: 12px; color: #6b7280; }
.vcard__check { margin-left: auto; color: var(--vc); font-weight: 700; }

.slug-wrap { display: flex; align-items: center; border: 1px solid #d1d5db; border-radius: 10px; overflow: hidden; }
.slug-wrap input { border: none; flex: 1; padding: 11px 13px; }
.slug-wrap input:focus { outline: none; }
.slug-wrap.is-ok { border-color: #10b981; }
.slug-wrap.is-taken, .slug-wrap.is-invalid { border-color: #ef4444; }
.slug-suffix { padding: 0 12px; color: #6b7280; font-size: 13px; white-space: nowrap; }
small.ok { color: #10b981; } small.bad { color: #ef4444; }
.preview { margin: 14px 0 0; padding: 12px 14px; border-radius: 10px; background: #f3f4f6; font-size: 14px; }

.wizard-nav { display: flex; align-items: center; gap: 10px; margin-top: 22px; }
.btn { display: inline-flex; align-items: center; justify-content: center; gap: 6px; padding: 11px 18px; border-radius: 10px; border: 1px solid transparent; background: #2563eb; color: #fff; font-weight: 600; font-size: 14px; cursor: pointer; }
.btn.ghost { background: transparent; color: #374151; border-color: #d1d5db; }
.btn:disabled { opacity: .6; cursor: default; }
.foot { text-align: center; margin: 16px 0 0; color: #6b7280; font-size: 13px; }
.foot a { color: #2563eb; text-decoration: none; }
</style>
