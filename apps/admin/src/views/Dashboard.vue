<script setup>
import { ref, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { todayInput, localDayStartUtc, localDayEndUtc, formatTime } from '../lib/datetime'

const loading = ref(true)
const error = ref('')
const appointments = ref([])

const today = todayInput()

const counts = computed(() => {
  const c = { total: 0, upcoming: 0, completed: 0, no_show: 0 }
  for (const a of appointments.value) {
    c.total++
    if (a.status === 'completed') c.completed++
    else if (a.status === 'no_show') c.no_show++
    else if (['pending', 'confirmed', 'arrived'].includes(a.status)) c.upcoming++
  }
  return c
})

const sorted = computed(() =>
  [...appointments.value].sort((a, b) =>
    (a.starts_at || '').localeCompare(b.starts_at || ''),
  ),
)

const statusLabels = {
  pending: 'Kutilmoqda',
  confirmed: 'Tasdiqlangan',
  arrived: 'Keldi',
  completed: 'Yakunlandi',
  no_show: 'Kelmadi',
  canceled: 'Bekor',
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const from = localDayStartUtc(today)
    const to = localDayEndUtc(today)
    const res = await api.get(
      `/v1/appointments?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`,
    )
    appointments.value = Array.isArray(res) ? res : res?.items || []
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Ma\'lumotni yuklab bo\'lmadi'
  } finally {
    loading.value = false
  }
}

function timeOf(a) {
  return a.starts_at ? formatTime(a.starts_at) : ''
}

onMounted(load)
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <h1>Boshqaruv paneli</h1>
        <p class="muted mb-0">Bugungi kun · {{ today }}</p>
      </div>
      <button class="btn btn-sm" @click="load">Yangilash</button>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div v-if="loading" class="loading-block"><span class="spinner"></span> Yuklanmoqda…</div>

    <template v-else>
      <div class="stat-grid" style="margin-bottom: 22px">
        <div class="stat">
          <div class="value">{{ counts.total }}</div>
          <div class="label">Bugungi yozuvlar</div>
        </div>
        <div class="stat">
          <div class="value" style="color: var(--primary)">{{ counts.upcoming }}</div>
          <div class="label">Kutilayotgan</div>
        </div>
        <div class="stat">
          <div class="value" style="color: var(--success)">{{ counts.completed }}</div>
          <div class="label">Yakunlangan</div>
        </div>
        <div class="stat">
          <div class="value" style="color: var(--danger)">{{ counts.no_show }}</div>
          <div class="label">Kelmadi</div>
        </div>
      </div>

      <div class="row between" style="margin-bottom: 12px">
        <h2 style="font-size: 17px; margin: 0">Bugungi yozuvlar</h2>
        <RouterLink to="/appointments">Barchasi →</RouterLink>
      </div>

      <div v-if="!sorted.length" class="empty card">Bugun uchun yozuvlar yo'q.</div>

      <div v-else class="table-wrap">
        <table class="data">
          <thead>
            <tr>
              <th>Vaqt</th>
              <th>Mijoz</th>
              <th>Xizmat</th>
              <th>Xodim</th>
              <th>Holat</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="a in sorted" :key="a.id">
              <td><strong>{{ timeOf(a) }}</strong></td>
              <td>{{ a.client?.name || a.client_name || '—' }}</td>
              <td>{{ a.service?.name || a.service_name || '—' }}</td>
              <td>{{ a.staff?.name || a.staff_name || '—' }}</td>
              <td><span class="badge" :class="a.status">{{ statusLabels[a.status] || a.status }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </div>
</template>
