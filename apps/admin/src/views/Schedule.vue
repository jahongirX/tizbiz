<script setup>
import { ref, watch, onMounted } from 'vue'
import { api, ApiError } from '@navbat/api-client'
import { confirm } from '../composables/useConfirm'

const WEEKDAYS = [
  { n: 1, l: 'Dushanba' },
  { n: 2, l: 'Seshanba' },
  { n: 3, l: 'Chorshanba' },
  { n: 4, l: 'Payshanba' },
  { n: 5, l: 'Juma' },
  { n: 6, l: 'Shanba' },
  { n: 0, l: 'Yakshanba' },
]

const staff = ref([])
const staffId = ref(null)
const loadingStaff = ref(true)
const loading = ref(false)
const error = ref('')

const hours = ref(defaultHours())
const savingHours = ref(false)
const hoursSaved = ref(false)

const timeOff = ref([])
const toForm = ref({ starts_at: '', ends_at: '', reason: '' })
const savingOff = ref(false)

function defaultHours() {
  return WEEKDAYS.map((d) => ({
    weekday: d.n,
    enabled: d.n >= 1 && d.n <= 6,
    start: '09:00',
    end: '18:00',
  }))
}

async function loadStaff() {
  loadingStaff.value = true
  try {
    const res = await api.get('/v1/staff')
    staff.value = Array.isArray(res) ? res : res?.items || []
    if (staff.value.length && staffId.value == null) staffId.value = staff.value[0].id
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Xodimlarni yuklab bo\'lmadi'
  } finally {
    loadingStaff.value = false
  }
}

function hhmm(v) {
  if (!v) return ''
  const m = String(v).match(/(\d{1,2}):(\d{2})/)
  return m ? `${m[1].padStart(2, '0')}:${m[2]}` : v
}

async function loadSchedule() {
  if (!staffId.value) return
  loading.value = true
  error.value = ''
  hoursSaved.value = false
  try {
    const [wh, off] = await Promise.all([
      api.get(`/v1/staff/${staffId.value}/working-hours`).catch(() => []),
      api.get(`/v1/staff/${staffId.value}/time-off`).catch(() => []),
    ])
    const rows = Array.isArray(wh) ? wh : wh?.items || wh?.days || []
    hours.value = WEEKDAYS.map((d) => {
      const found = rows.find((r) => Number(r.weekday ?? r.day) === d.n)
      if (found) {
        const enabled = found.enabled ?? found.is_working ?? !(found.is_off ?? false)
        return {
          weekday: d.n,
          enabled: !!enabled && !!(found.start || found.start_time),
          start: hhmm(found.start || found.start_time || '09:00'),
          end: hhmm(found.end || found.end_time || '18:00'),
        }
      }
      return { weekday: d.n, enabled: false, start: '09:00', end: '18:00' }
    })
    timeOff.value = Array.isArray(off) ? off : off?.items || []
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Jadvalni yuklab bo\'lmadi'
  } finally {
    loading.value = false
  }
}

async function saveHours() {
  savingHours.value = true
  error.value = ''
  hoursSaved.value = false
  try {
    const payload = {
      days: hours.value.map((h) => ({
        weekday: h.weekday,
        enabled: h.enabled,
        start: h.enabled ? h.start : null,
        end: h.enabled ? h.end : null,
      })),
    }
    await api.put(`/v1/staff/${staffId.value}/working-hours`, payload)
    hoursSaved.value = true
    setTimeout(() => (hoursSaved.value = false), 2500)
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Saqlab bo\'lmadi'
  } finally {
    savingHours.value = false
  }
}

async function addTimeOff() {
  if (!toForm.value.starts_at) return
  savingOff.value = true
  error.value = ''
  try {
    await api.post(`/v1/staff/${staffId.value}/time-off`, {
      starts_at: toForm.value.starts_at,
      ends_at: toForm.value.ends_at || toForm.value.starts_at,
      reason: toForm.value.reason.trim() || null,
    })
    toForm.value = { starts_at: '', ends_at: '', reason: '' }
    await loadSchedule()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Qo\'shib bo\'lmadi'
  } finally {
    savingOff.value = false
  }
}

async function removeTimeOff(t) {
  if (!(await confirm({ message: 'Dam olish davri o\'chirilsinmi?', danger: true, confirmText: 'O‘chirish' }))) return
  try {
    await api.del(`/v1/staff/${staffId.value}/time-off/${t.id}`)
    await loadSchedule()
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'O\'chirib bo\'lmadi'
  }
}

watch(staffId, loadSchedule)
onMounted(async () => {
  await loadStaff()
  await loadSchedule()
})
</script>

<template>
  <div>
    <div class="page-head">
      <h1>Ish jadvali</h1>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div v-if="loadingStaff" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>
    <div v-else-if="!staff.length" class="empty card">
      Avval <RouterLink to="/staff">xodim qo'shing</RouterLink>.
    </div>

    <template v-else>
      <div class="field" style="max-width: 320px">
        <label>Xodim</label>
        <select v-model="staffId">
          <option v-for="s in staff" :key="s.id" :value="s.id">{{ s.name }}</option>
        </select>
      </div>

      <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

      <div v-else class="grid">
        <section class="card">
          <h2 style="font-size: 16px">Haftalik ish vaqti</h2>
          <table class="hours">
            <tbody>
              <tr v-for="(h, i) in hours" :key="h.weekday">
                <td class="day">
                  <label class="row" style="gap: 8px; margin: 0; cursor: pointer">
                    <input v-model="h.enabled" type="checkbox" style="width: auto" />
                    <span>{{ WEEKDAYS[i].l }}</span>
                  </label>
                </td>
                <td>
                  <input v-model="h.start" type="time" :disabled="!h.enabled" />
                </td>
                <td class="dash">–</td>
                <td>
                  <input v-model="h.end" type="time" :disabled="!h.enabled" />
                </td>
              </tr>
            </tbody>
          </table>
          <div class="row" style="margin-top: 16px; gap: 12px">
            <button class="btn btn-primary" :disabled="savingHours" @click="saveHours">
              {{ savingHours ? 'Saqlanmoqda…' : 'Saqlash' }}
            </button>
            <span v-if="hoursSaved" style="color: var(--success); font-weight: 600">✓ Saqlandi</span>
          </div>
        </section>

        <section class="card">
          <h2 style="font-size: 16px">Dam olish / ta'til</h2>

          <div v-if="!timeOff.length" class="muted" style="padding: 8px 0">Yozuvlar yo'q.</div>
          <ul v-else class="off-list">
            <li v-for="t in timeOff" :key="t.id">
              <div>
                <strong>{{ (t.starts_at || '').slice(0, 16).replace('T', ' ') }}</strong>
                <span class="muted"> → {{ (t.ends_at || '').slice(0, 16).replace('T', ' ') }}</span>
                <div v-if="t.reason" class="muted" style="font-size: 12px">{{ t.reason }}</div>
              </div>
              <button class="btn btn-sm btn-danger" @click="removeTimeOff(t)">O'chirish</button>
            </li>
          </ul>

          <form class="off-form" @submit.prevent="addTimeOff">
            <div class="field-row">
              <div class="field">
                <label>Boshlanishi</label>
                <input v-model="toForm.starts_at" type="datetime-local" required />
              </div>
              <div class="field">
                <label>Tugashi</label>
                <input v-model="toForm.ends_at" type="datetime-local" />
              </div>
            </div>
            <div class="field">
              <label>Sabab</label>
              <input v-model="toForm.reason" placeholder="Ta'til, kasallik…" />
            </div>
            <button class="btn" :disabled="savingOff" type="submit">
              {{ savingOff ? 'Qo\'shilmoqda…' : '+ Qo\'shish' }}
            </button>
          </form>
        </section>
      </div>
    </template>
  </div>
</template>

<style scoped>
.grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 18px;
  margin-top: 8px;
}
@media (max-width: 820px) {
  .grid { grid-template-columns: 1fr; }
}
.hours {
  width: 100%;
  border-collapse: collapse;
}
.hours td {
  padding: 6px 4px;
}
.hours .day {
  width: 46%;
  font-weight: 550;
}
.hours .dash {
  width: 18px;
  text-align: center;
  color: var(--text-muted);
}
.hours input[type='time'] {
  padding: 6px 8px;
}
.off-list {
  list-style: none;
  margin: 8px 0 18px;
  padding: 0;
}
.off-list li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  padding: 10px 0;
  border-bottom: 1px solid var(--border);
}
.off-form {
  border-top: 1px solid var(--border);
  padding-top: 14px;
}
</style>
