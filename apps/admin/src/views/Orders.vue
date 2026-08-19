<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { api, ApiError } from '@tizbiz/api-client'
import { RefreshCw, Package, X, Phone } from 'lucide-vue-next'

const orders = ref([])
const loading = ref(true)
const error = ref('')
const selected = ref(null) // order shown in the detail modal

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

const grouped = computed(() => {
  const map = Object.fromEntries(STATUS.map((s) => [s.v, []]))
  for (const o of orders.value) (map[o.status] ??= []).push(o)
  return map
})
const colTotal = (v) => (grouped.value[v] || []).reduce((s, o) => s + (o.total_tiyin || 0), 0)

async function load() {
  loading.value = true
  error.value = ''
  try {
    orders.value = await api.get('/v1/orders')
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Yuklashda xatolik'
  } finally {
    loading.value = false
  }
}

async function setStatus(o, status) {
  if (!o || o.status === status) return
  const prev = o.status
  o.status = status // optimistic
  try {
    const upd = await api.patch(`/v1/orders/${o.id}`, { status })
    Object.assign(o, upd)
  } catch (e) {
    o.status = prev
    error.value = e instanceof ApiError ? e.message : 'Holatni o‘zgartirib bo‘lmadi'
  }
}

/* ---------- drag & drop ---------- */
const dragId = ref(null)
const overCol = ref('')
function onDragStart(o, e) {
  dragId.value = o.id
  if (e.dataTransfer) {
    e.dataTransfer.effectAllowed = 'move'
    e.dataTransfer.setData('text/plain', String(o.id))
  }
}
function onDragEnd() {
  dragId.value = null
  overCol.value = ''
}
function onDrop(status) {
  const id = dragId.value
  overCol.value = ''
  dragId.value = null
  const o = orders.value.find((x) => x.id === id)
  if (o) setStatus(o, status)
}

/* ---------- detail modal ---------- */
function open(o) {
  if (dragId.value) return // was a drag, not a click
  selected.value = o
}
function onKey(e) {
  if (e.key === 'Escape') selected.value = null
}
onMounted(() => {
  load()
  window.addEventListener('keydown', onKey)
})
onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
</script>

<template>
  <div class="page">
    <div class="page-head">
      <div>
        <h1>Buyurtmalar</h1>
        <p class="muted">Sayt va Telegram bot orqali kelgan buyurtmalar — holat bo‘yicha kanban</p>
      </div>
      <div class="head-right">
        <span class="head-total muted">{{ orders.length }} ta · <strong>{{ soms(total) }}</strong></span>
        <button class="btn btn-ghost btn-sm" :disabled="loading" @click="load">
          <RefreshCw :size="15" /> Yangilash
        </button>
      </div>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>
    <div v-if="loading" class="muted pad">Yuklanmoqda…</div>

    <div v-else-if="!orders.length" class="empty card">
      <Package :size="34" />
      <p>Hozircha buyurtmalar yo‘q.</p>
    </div>

    <div v-else class="board">
      <section
        v-for="s in STATUS"
        :key="s.v"
        class="col"
        :class="{ 'col--over': overCol === s.v }"
        @dragover.prevent="overCol = s.v"
        @drop.prevent="onDrop(s.v)"
      >
        <header class="col-head" :style="{ '--dot': s.c }">
          <span class="dot"></span>
          <span class="col-title">{{ s.l }}</span>
          <span class="col-count">{{ grouped[s.v].length }}</span>
        </header>
        <div v-if="grouped[s.v].length" class="col-sub muted">{{ soms(colTotal(s.v)) }}</div>

        <div class="col-body">
          <article
            v-for="o in grouped[s.v]"
            :key="o.id"
            class="kcard"
            :class="{ dragging: dragId === o.id }"
            draggable="true"
            @dragstart="onDragStart(o, $event)"
            @dragend="onDragEnd"
            @click="open(o)"
          >
            <div class="k-top">
              <strong>#{{ o.id }}</strong>
              <span class="k-when">{{ when(o.created_at) }}</span>
            </div>
            <div class="k-cust">
              <span class="k-name">{{ o.customer_name || '—' }}</span>
              <span v-if="o.note" class="k-note-dot" title="Izoh bor">📝</span>
            </div>
            <ul class="k-items">
              <li v-for="i in o.items.slice(0, 3)" :key="i.id">
                <span class="k-iname">{{ i.name }} × {{ i.qty }}</span>
              </li>
              <li v-if="o.items.length > 3" class="k-more">+{{ o.items.length - 3 }} ta</li>
            </ul>
            <div class="k-foot">
              <strong>{{ soms(o.total_tiyin) }}</strong>
            </div>
          </article>

          <p v-if="!grouped[s.v].length" class="col-empty">Bo‘sh</p>
        </div>
      </section>
    </div>

    <!-- ===== Detail modal ===== -->
    <transition name="modal">
      <div v-if="selected" class="overlay" @click.self="selected = null">
        <div class="modal">
          <button class="modal-x" aria-label="Yopish" @click="selected = null"><X :size="20" /></button>

          <div class="m-head">
            <div class="m-id">Buyurtma <strong>#{{ selected.id }}</strong></div>
            <span
              class="m-pill"
              :style="{ background: statusOf(selected.status).c + '22', color: statusOf(selected.status).c }"
            >{{ statusOf(selected.status).l }}</span>
          </div>
          <div class="m-when">{{ when(selected.created_at) }}</div>

          <div class="m-cust">
            <div class="m-cust-name">{{ selected.customer_name || 'Mijoz' }}</div>
            <a v-if="selected.customer_phone" class="m-phone" :href="`tel:${selected.customer_phone}`">
              <Phone :size="16" /> {{ selected.customer_phone }}
            </a>
          </div>

          <div class="m-items">
            <div v-for="i in selected.items" :key="i.id" class="m-item">
              <div class="m-item-l">
                <span class="m-name">{{ i.name }}</span>
                <span class="m-qty">× {{ i.qty }}</span>
              </div>
              <div class="m-item-r">
                <span class="muted m-unit">{{ soms(i.price_tiyin) }}</span>
                <strong>{{ soms(i.price_tiyin * i.qty) }}</strong>
              </div>
            </div>
          </div>

          <p v-if="selected.note" class="m-note">📝 {{ selected.note }}</p>

          <div class="m-total">
            <span>Jami</span>
            <strong>{{ soms(selected.total_tiyin) }}</strong>
          </div>

          <div class="m-status-wrap">
            <div class="muted m-status-label">Holatni o‘zgartirish</div>
            <div class="m-status">
              <button
                v-for="s in STATUS"
                :key="s.v"
                class="m-st"
                :class="{ on: selected.status === s.v }"
                :style="selected.status === s.v ? { background: s.c + '22', color: s.c, borderColor: s.c } : {}"
                @click="setStatus(selected, s.v)"
              >
                {{ s.l }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </transition>
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
h1 { font-size: 22px; margin: 0 0 2px; }
.head-right { display: flex; align-items: center; gap: 14px; }
.head-total { font-size: 14px; white-space: nowrap; }
.head-total strong { color: var(--text); }

/* ---------- Board: all 6 columns fit one screen ---------- */
.board {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 10px;
  align-items: start;
}
.col {
  min-width: 0;
  background: color-mix(in srgb, var(--text-muted) 8%, transparent);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 9px;
  transition: background 0.15s ease, box-shadow 0.15s ease;
}
.col--over {
  background: var(--primary-soft);
  box-shadow: inset 0 0 0 2px var(--primary);
}
.col-head { display: flex; align-items: center; gap: 6px; padding: 2px 2px 0; }
.dot { width: 8px; height: 8px; border-radius: 50%; background: var(--dot); flex: none; }
.col-title { font-weight: 700; font-size: 12.5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.col-count {
  margin-left: auto;
  background: color-mix(in srgb, var(--text-muted) 18%, transparent);
  color: var(--text);
  font-size: 11px;
  font-weight: 700;
  min-width: 20px;
  text-align: center;
  padding: 1px 6px;
  border-radius: 999px;
  flex: none;
}
.col-sub { font-size: 11px; padding: 3px 2px 0; }
.col-body { display: flex; flex-direction: column; gap: 8px; margin-top: 8px; min-height: 36px; }
.col-empty {
  text-align: center;
  color: var(--text-muted);
  font-size: 12px;
  padding: 12px 0;
  border: 1px dashed var(--border);
  border-radius: 9px;
  margin: 0;
}

/* ---------- Compact card ---------- */
.kcard {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 9px;
  box-shadow: var(--shadow);
  padding: 9px;
  display: flex;
  flex-direction: column;
  gap: 5px;
  cursor: pointer;
  transition: transform 0.08s ease, box-shadow 0.15s ease, opacity 0.15s ease;
}
.kcard:hover { box-shadow: 0 4px 14px rgba(0, 0, 0, 0.14); transform: translateY(-1px); }
.kcard.dragging { opacity: 0.4; }
.k-top { display: flex; justify-content: space-between; align-items: baseline; gap: 6px; }
.k-top strong { font-size: 12.5px; }
.k-when { font-size: 10px; color: var(--text-muted); white-space: nowrap; }
.k-cust { display: flex; align-items: center; gap: 5px; }
.k-name {
  font-weight: 600;
  font-size: 12px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.k-note-dot { font-size: 11px; flex: none; }
.k-items {
  list-style: none;
  margin: 0;
  padding: 6px 0 0;
  border-top: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.k-items li { font-size: 11px; color: var(--text-muted); }
.k-iname { display: block; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.k-more { font-weight: 600; }
.k-foot { display: flex; justify-content: flex-end; margin-top: 2px; }
.k-foot strong { font-size: 13px; }

/* ---------- Detail modal ---------- */
.overlay {
  position: fixed;
  inset: 0;
  z-index: 100;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}
.modal {
  position: relative;
  width: 100%;
  max-width: 460px;
  max-height: 88vh;
  overflow-y: auto;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 16px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.35);
  padding: 24px;
}
.modal-x {
  position: absolute;
  top: 14px;
  right: 14px;
  border: none;
  background: transparent;
  color: var(--text-muted);
  cursor: pointer;
  padding: 4px;
  border-radius: 8px;
}
.modal-x:hover { background: color-mix(in srgb, var(--text-muted) 14%, transparent); color: var(--text); }
.m-head { display: flex; align-items: center; gap: 12px; padding-right: 30px; }
.m-id { font-size: 20px; }
.m-id strong { font-size: 22px; }
.m-pill { border-radius: 999px; padding: 4px 12px; font-size: 13px; font-weight: 700; }
.m-when { color: var(--text-muted); font-size: 13px; margin-top: 4px; }

.m-cust {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
  margin: 18px 0;
  padding: 14px 16px;
  background: color-mix(in srgb, var(--text-muted) 7%, transparent);
  border-radius: 12px;
}
.m-cust-name { font-size: 17px; font-weight: 700; }
.m-phone {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: var(--primary);
  font-weight: 600;
  font-size: 15px;
  text-decoration: none;
}

.m-items { display: flex; flex-direction: column; }
.m-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 0;
  border-bottom: 1px solid var(--border);
}
.m-item-l { display: flex; align-items: baseline; gap: 8px; min-width: 0; }
.m-name { font-size: 16px; font-weight: 600; }
.m-qty { font-size: 14px; color: var(--text-muted); white-space: nowrap; }
.m-item-r { display: flex; flex-direction: column; align-items: flex-end; gap: 2px; white-space: nowrap; }
.m-unit { font-size: 12px; }
.m-item-r strong { font-size: 15px; }

.m-note {
  margin: 14px 0 0;
  padding: 12px 14px;
  background: color-mix(in srgb, var(--warning) 12%, transparent);
  border-radius: 10px;
  font-size: 14px;
}
.m-total {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 18px;
  padding-top: 16px;
  border-top: 2px solid var(--border);
}
.m-total span { font-size: 15px; color: var(--text-muted); }
.m-total strong { font-size: 24px; }

.m-status-wrap { margin-top: 22px; }
.m-status-label { font-size: 13px; margin-bottom: 8px; }
.m-status { display: flex; flex-wrap: wrap; gap: 8px; }
.m-st {
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text);
  border-radius: 999px;
  padding: 7px 14px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.12s ease, border-color 0.12s ease;
}
.m-st:hover { border-color: var(--text-muted); }
.m-st.on { font-weight: 700; }

/* modal transition */
.modal-enter-active, .modal-leave-active { transition: opacity 0.18s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.modal-enter-active .modal, .modal-leave-active .modal { transition: transform 0.18s ease; }
.modal-enter-from .modal, .modal-leave-to .modal { transform: translateY(12px) scale(0.98); }

.empty {
  text-align: center;
  padding: 40px;
  color: var(--text-muted);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
}
.pad { padding: 20px 0; }

/* ---------- Responsive: narrow screens scroll horizontally ---------- */
@media (max-width: 1024px) {
  .board {
    display: flex;
    overflow-x: auto;
    padding-bottom: 10px;
    scroll-snap-type: x proximity;
  }
  .col { flex: 0 0 240px; scroll-snap-align: start; }
}
@media (max-width: 600px) {
  .page-head { flex-direction: column; }
  .col { flex-basis: 80vw; }
}
</style>
