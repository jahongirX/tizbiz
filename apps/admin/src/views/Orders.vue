<script setup>
import { ref, computed, onMounted } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { RefreshCw, Package } from 'lucide-vue-next'

const orders = ref([])
const loading = ref(true)
const error = ref('')
const filter = ref('')

const STATUS = [
  { v: 'new', l: 'Yangi', c: '#3b82f6' },
  { v: 'confirmed', l: 'Tasdiqlangan', c: '#8b5cf6' },
  { v: 'preparing', l: 'Tayyorlanmoqda', c: '#f59e0b' },
  { v: 'ready', l: 'Tayyor', c: '#10b981' },
  { v: 'delivered', l: 'Yetkazildi', c: '#6b7280' },
  { v: 'cancelled', l: 'Bekor qilingan', c: '#ef4444' },
]
const statusOf = (v) => STATUS.find((s) => s.v === v) || { l: v, c: '#6b7280' }
const soms = (t) => Math.round((Number(t) || 0) / 100).toLocaleString('ru-RU') + " so'm"
const when = (ts) => new Date((Number(ts) || 0) * 1000).toLocaleString('ru-RU', { timeZone: 'Asia/Tashkent' })

const total = computed(() => orders.value.reduce((s, o) => s + (o.total_tiyin || 0), 0))

async function load() {
  loading.value = true
  error.value = ''
  try {
    const q = filter.value ? `?status=${filter.value}` : ''
    orders.value = await api.get(`/v1/orders${q}`)
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Yuklashda xatolik'
  } finally {
    loading.value = false
  }
}

async function setStatus(o, status) {
  try {
    const upd = await api.patch(`/v1/orders/${o.id}`, { status })
    Object.assign(o, upd)
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Holatni o‘zgartirib bo‘lmadi'
  }
}

onMounted(load)
</script>

<template>
  <div class="page">
    <div class="page-head">
      <div>
        <h1>Buyurtmalar</h1>
        <p class="muted">Sayt va Telegram bot orqali kelgan buyurtmalar tarixi</p>
      </div>
      <button class="btn btn-ghost btn-sm" :disabled="loading" @click="load">
        <RefreshCw :size="15" /> Yangilash
      </button>
    </div>

    <div class="filters">
      <button class="chip" :class="{ on: filter === '' }" @click="filter = ''; load()">Hammasi</button>
      <button
        v-for="s in STATUS"
        :key="s.v"
        class="chip"
        :class="{ on: filter === s.v }"
        @click="filter = s.v; load()"
      >
        {{ s.l }}
      </button>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div v-if="loading" class="muted pad">Yuklanmoqda…</div>

    <div v-else-if="!orders.length" class="empty card">
      <Package :size="34" />
      <p>Hozircha buyurtmalar yo‘q.</p>
    </div>

    <template v-else>
      <div class="summary">
        <span>{{ orders.length }} ta buyurtma</span>
        <strong>Jami: {{ soms(total) }}</strong>
      </div>

      <div class="orders">
        <article v-for="o in orders" :key="o.id" class="order card">
          <div class="o-top">
            <div>
              <strong>#{{ o.id }}</strong>
              <span class="o-when muted">{{ when(o.created_at) }}</span>
            </div>
            <span class="pill" :style="{ background: statusOf(o.status).c + '22', color: statusOf(o.status).c }">
              {{ statusOf(o.status).l }}
            </span>
          </div>

          <div class="o-cust">
            {{ o.customer_name || '—' }}
            <a v-if="o.customer_phone" :href="`tel:${o.customer_phone}`" class="muted">{{ o.customer_phone }}</a>
          </div>

          <ul class="o-items">
            <li v-for="i in o.items" :key="i.id">
              <span>{{ i.name }} × {{ i.qty }}</span>
              <span class="muted">{{ soms(i.price_tiyin * i.qty) }}</span>
            </li>
          </ul>
          <p v-if="o.note" class="o-note muted">📝 {{ o.note }}</p>

          <div class="o-foot">
            <strong>{{ soms(o.total_tiyin) }}</strong>
            <select class="status-select" :value="o.status" @change="setStatus(o, $event.target.value)">
              <option v-for="s in STATUS" :key="s.v" :value="s.v">{{ s.l }}</option>
            </select>
          </div>
        </article>
      </div>
    </template>
  </div>
</template>

<style scoped>
.page-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 16px;
}
h1 {
  font-size: 22px;
  margin: 0 0 2px;
}
.filters {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 16px;
}
.chip {
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text);
  border-radius: 999px;
  padding: 6px 14px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
}
.chip.on {
  background: var(--primary-soft);
  color: var(--primary);
  border-color: var(--primary);
}
.summary {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
  color: var(--text-muted);
  font-size: 14px;
}
.orders {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 14px;
}
.order {
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.o-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.o-when {
  margin-left: 8px;
  font-size: 12px;
}
.pill {
  border-radius: 999px;
  padding: 3px 10px;
  font-size: 12px;
  font-weight: 700;
}
.o-cust {
  display: flex;
  gap: 10px;
  align-items: center;
  font-weight: 600;
  font-size: 14px;
}
.o-items {
  list-style: none;
  margin: 0;
  padding: 10px 0;
  border-top: 1px solid var(--border);
  border-bottom: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.o-items li {
  display: flex;
  justify-content: space-between;
  font-size: 13px;
}
.o-note {
  font-size: 13px;
  margin: 0;
}
.o-foot {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.o-foot strong {
  font-size: 16px;
}
.status-select {
  width: auto;
  font-size: 13px;
  font-weight: 600;
}
.empty {
  text-align: center;
  padding: 40px;
  color: var(--text-muted);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
}
.pad {
  padding: 20px 0;
}
</style>
