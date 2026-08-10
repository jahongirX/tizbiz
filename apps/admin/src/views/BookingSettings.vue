<script setup>
import { ref, computed, onMounted } from 'vue'
import { api, ApiError, publicSiteUrl } from '@tizbiz/api-client'
import { ExternalLink } from 'lucide-vue-next'

const publicUrl = computed(() => publicSiteUrl((form.value.slug || '').trim() || 'demo'))

const loading = ref(true)
const error = ref('')
const saving = ref(false)
const saved = ref(false)
const formError = ref('')

const form = ref({
  slug: '',
  online_booking_enabled: false,
  booking_lead_min: 60,
  booking_horizon_days: 30,
})

// Telegram bot connection (token is write-only; server returns only status).
const tgToken = ref('')
const telegramConnected = ref(false)
const telegramUsername = ref(null)
const tgSaving = ref(false)
const tgError = ref('')
const tgSaved = ref('')

async function load() {
  loading.value = true
  error.value = ''
  try {
    const res = await api.get('/v1/settings/booking')
    form.value = {
      slug: res.slug || '',
      online_booking_enabled: !!res.online_booking_enabled,
      booking_lead_min: Number(res.booking_lead_min ?? 60),
      booking_horizon_days: Number(res.booking_horizon_days ?? 30),
    }
    telegramConnected.value = !!res.telegram_connected
    telegramUsername.value = res.telegram_bot_username || null
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Yuklab bo\'lmadi'
  } finally {
    loading.value = false
  }
}

async function save() {
  formError.value = ''
  saved.value = false
  saving.value = true
  try {
    const payload = {
      slug: form.value.slug.trim(),
      online_booking_enabled: form.value.online_booking_enabled,
      booking_lead_min: Number(form.value.booking_lead_min),
      booking_horizon_days: Number(form.value.booking_horizon_days),
    }
    const res = await api.put('/v1/settings/booking', payload)
    form.value = {
      slug: res.slug ?? payload.slug,
      online_booking_enabled: !!res.online_booking_enabled,
      booking_lead_min: Number(res.booking_lead_min ?? payload.booking_lead_min),
      booking_horizon_days: Number(res.booking_horizon_days ?? payload.booking_horizon_days),
    }
    saved.value = true
    setTimeout(() => (saved.value = false), 2500)
  } catch (e) {
    formError.value = e instanceof ApiError ? e.message : 'Saqlab bo\'lmadi'
  } finally {
    saving.value = false
  }
}

async function saveTelegram(clear = false) {
  tgError.value = ''
  tgSaved.value = ''
  const token = clear ? '' : tgToken.value.trim()
  if (!clear && token === '') {
    tgError.value = 'Token kiriting'
    return
  }
  tgSaving.value = true
  try {
    const res = await api.put('/v1/settings/booking', { telegram_bot_token: token })
    telegramConnected.value = !!res.telegram_connected
    telegramUsername.value = res.telegram_bot_username || null
    tgToken.value = ''
    tgSaved.value = telegramConnected.value ? '✓ Token saqlandi' : '✓ O‘chirildi'
    setTimeout(() => (tgSaved.value = ''), 2500)
  } catch (e) {
    tgError.value = e instanceof ApiError ? e.message : 'Saqlab bo\'lmadi'
  } finally {
    tgSaving.value = false
  }
}

onMounted(load)
</script>

<template>
  <div>
    <div class="page-head">
      <h1>Onlayn-yozuv sozlamalari</h1>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>
    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

    <section v-else class="card" style="max-width: 520px">
      <div v-if="formError" class="alert alert-error">{{ formError }}</div>

      <form @submit.prevent="save">
        <div class="field">
          <label>Sayt manzili (slug)</label>
          <div class="slug-row">
            <input v-model="form.slug" placeholder="aziza-tortlari" />
            <span class="slug-suffix">.tizbiz.uz</span>
          </div>
          <span class="muted" style="font-size: 12px">
            Public saytingiz manzili. O‘zgartirsangiz, eski havolalar ishlamay qoladi.
          </span>
          <a :href="publicUrl" target="_blank" rel="noopener" class="site-link">
            <ExternalLink :size="14" /> Saytni ochish
            <span class="muted">— {{ publicUrl }}</span>
          </a>
        </div>

        <hr class="sep" />

        <label class="row" style="gap: 10px; cursor: pointer; margin-bottom: 6px">
          <input v-model="form.online_booking_enabled" type="checkbox" style="width: auto" />
          <span style="font-weight: 600">Onlayn yozuvni yoqish</span>
        </label>
        <p class="muted" style="margin: 0 0 20px; font-size: 13px">
          Yoqilganda mijozlar sayt orqali o'zlari navbatga yozila oladi.
        </p>

        <div class="field-row">
          <div class="field">
            <label>Minimal oldindan (daqiqa)</label>
            <input
              v-model.number="form.booking_lead_min"
              type="number"
              min="0"
              step="5"
              placeholder="60"
            />
            <span class="muted" style="font-size: 12px">Shu daqiqadan yaqinroq vaqtga yozib bo'lmaydi.</span>
          </div>
          <div class="field">
            <label>Maksimal oldindan (kun)</label>
            <input
              v-model.number="form.booking_horizon_days"
              type="number"
              min="1"
              step="1"
              placeholder="30"
            />
            <span class="muted" style="font-size: 12px">Shu kundan uzoqroq sanaga yozib bo'lmaydi.</span>
          </div>
        </div>

        <div class="row" style="margin-top: 20px; gap: 12px">
          <button class="btn btn-primary" type="submit" :disabled="saving">
            {{ saving ? 'Saqlanmoqda…' : 'Saqlash' }}
          </button>
          <span v-if="saved" style="color: var(--success); font-weight: 600">✓ Saqlandi</span>
        </div>
      </form>
    </section>

    <!-- Telegram bot -->
    <section v-if="!loading" class="card tg-card" style="max-width: 520px; margin-top: 18px">
      <div class="tg-head">
        <span class="tg-ico">✈️</span>
        <div>
          <h2>Telegram bot</h2>
          <p class="muted" style="margin: 2px 0 0; font-size: 13px">
            Bot orqali mijozlar katalogni ko‘radi va buyurtma beradi.
          </p>
        </div>
      </div>

      <div v-if="telegramConnected" class="tg-status ok">
        ✓ Ulangan<span v-if="telegramUsername"> · @{{ telegramUsername }}</span>
      </div>
      <div v-else class="tg-status off">Ulanmagan</div>

      <div v-if="tgError" class="alert alert-error" style="margin-top: 12px">{{ tgError }}</div>

      <ol class="tg-steps muted">
        <li>Telegramda <strong>@BotFather</strong> ni oching → <code>/newbot</code></li>
        <li>Bot nomi va foydalanuvchi nomini bering</li>
        <li>Berilgan <strong>token</strong> ni shu yerga joylang</li>
      </ol>

      <div class="field">
        <label>Bot token</label>
        <input
          v-model="tgToken"
          type="password"
          autocomplete="off"
          placeholder="123456789:AA... (BotFather'dan)"
        />
      </div>

      <div class="row" style="gap: 12px; margin-top: 6px; align-items: center">
        <button class="btn btn-primary" :disabled="tgSaving" @click="saveTelegram(false)">
          {{ tgSaving ? 'Saqlanmoqda…' : telegramConnected ? 'Tokenni yangilash' : 'Ulash' }}
        </button>
        <button
          v-if="telegramConnected"
          class="btn btn-ghost"
          :disabled="tgSaving"
          @click="saveTelegram(true)"
        >
          Uzish
        </button>
        <span v-if="tgSaved" style="color: var(--success); font-weight: 600">{{ tgSaved }}</span>
      </div>

      <p class="muted tg-note">
        ⓘ Bot ishga tushishi uchun serverda ochiq (HTTPS) webhook manzil kerak. Token saqlangach,
        deploy paytida bot avtomatik ulanadi.
      </p>
    </section>
  </div>
</template>

<style scoped>
.slug-row {
  display: flex;
  align-items: center;
  border: 1px solid var(--border);
  border-radius: 10px;
  overflow: hidden;
}
.slug-row input {
  border: none;
  flex: 1;
  background: transparent;
}
.slug-row input:focus {
  outline: none;
}
.slug-suffix {
  padding: 0 12px;
  color: var(--text-muted);
  font-size: 13px;
  white-space: nowrap;
}
.sep {
  border: none;
  border-top: 1px solid var(--border);
  margin: 18px 0;
}
.site-link {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  margin-top: 8px;
  font-size: 13px;
  font-weight: 600;
  color: var(--primary);
  text-decoration: none;
}
.site-link:hover {
  text-decoration: underline;
}
.site-link .muted {
  font-weight: 400;
}
.tg-head {
  display: flex;
  gap: 12px;
  align-items: flex-start;
  margin-bottom: 14px;
}
.tg-head h2 {
  font-size: 17px;
  margin: 0;
}
.tg-ico {
  font-size: 26px;
}
.tg-status {
  display: inline-block;
  border-radius: 999px;
  padding: 4px 12px;
  font-size: 13px;
  font-weight: 700;
}
.tg-status.ok {
  background: var(--success-soft, rgba(16, 185, 129, 0.14));
  color: var(--success, #10b981);
}
.tg-status.off {
  background: var(--surface-2, rgba(127, 127, 127, 0.14));
  color: var(--text-muted);
}
.tg-steps {
  font-size: 13px;
  line-height: 1.7;
  margin: 14px 0;
  padding-left: 18px;
}
.tg-steps code {
  background: var(--surface-2, rgba(127, 127, 127, 0.14));
  padding: 1px 6px;
  border-radius: 6px;
}
.tg-note {
  font-size: 12px;
  margin: 14px 0 0;
  line-height: 1.5;
}
</style>
