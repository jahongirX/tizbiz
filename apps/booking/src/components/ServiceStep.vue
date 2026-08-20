<script setup>
// Multi-select: a barbershop visit is often "soch + soqol", so the step adds up
// the chosen services and the slot search then looks for one long enough.
import { computed, ref } from 'vue'
import { soms, duration } from '../format.js'

const props = defineProps({
  services: { type: Array, default: () => [] },
  selectedIds: { type: Array, default: () => [] },
  // Ordered sections; empty means show one flat list.
  categories: { type: Array, default: () => [] },
  // Off for verticals that book one service at a time: no tick, no total, and a
  // tap goes straight to the next step.
  multi: { type: Boolean, default: false },
})
const emit = defineEmits(['toggle', 'next'])

const chosen = computed(() => props.services.filter((s) => props.selectedIds.includes(s.id)))
const totalMin = computed(() => chosen.value.reduce((n, s) => n + (Number(s.duration_min) || 0), 0))
const totalPrice = computed(() => chosen.value.reduce((n, s) => n + (Number(s.price_tiyin) || 0), 0))
const totalDeposit = computed(() =>
  chosen.value.reduce((n, s) => n + (Number(s.deposit_tiyin) || 0), 0),
)

function isOn(id) {
  return props.selectedIds.includes(id)
}

// Services under their section, in the shop's own order. Anything without a
// section lands in a trailing group, and a shop with no sections at all keeps a
// single unlabelled list.
// Section tabs. Filtering beats drilling in and out of a category, because a
// visit often spans two of them (soch + soqol) and the picks must survive the
// switch.
const activeTab = ref(0) // 0 = hammasi
const tabs = computed(() =>
  props.categories.length ? [{ id: 0, name: 'Hammasi' }, ...props.categories] : [],
)

const groups = computed(() => {
  if (!props.categories.length) {
    return [{ id: 0, name: '', items: props.services }]
  }
  const out = props.categories.map((c) => ({
    id: c.id,
    name: c.name,
    items: props.services.filter((s) => s.category_id === c.id),
  }))
  const rest = props.services.filter(
    (s) => !props.categories.some((c) => c.id === s.category_id),
  )
  if (rest.length) out.push({ id: 0, name: 'Boshqa', items: rest })
  const filled = out.filter((g) => g.items.length)
  return activeTab.value ? filled.filter((g) => g.id === activeTab.value) : filled
})

/** Selections made in other sections stay visible while a tab is active. */
const hiddenChosen = computed(() => {
  const shown = new Set(groups.value.flatMap((g) => g.items.map((s) => s.id)))
  return chosen.value.filter((s) => !shown.has(s.id))
})
</script>

<template>
  <div>
    <div class="step-head">
      <h2>Xizmatni tanlang</h2>
    </div>
    <p v-if="multi" class="section-label">Bir nechtasini birga tanlashingiz mumkin</p>

    <div v-if="tabs.length" class="tabs" role="tablist">
      <button
        v-for="t in tabs"
        :key="t.id"
        role="tab"
        type="button"
        class="tab"
        :class="{ on: activeTab === t.id }"
        :aria-selected="activeTab === t.id"
        @click="activeTab = t.id"
      >
        {{ t.name }}
      </button>
    </div>

    <p v-if="hiddenChosen.length" class="other-picked">
      Boshqa bo‘limdan tanlangan: {{ hiddenChosen.map((s) => s.name).join(', ') }}
    </p>

    <div v-if="!services.length" class="empty">
      <div class="emo">📋</div>
      <p>Hozircha xizmatlar mavjud emas.</p>
    </div>

    <template v-for="g in groups" :key="g.id">
    <p v-if="g.name && !activeTab" class="group-head">{{ g.name }}</p>
    <button
      v-for="s in g.items"
      :key="s.id"
      class="card"
      :class="{ selected: isOn(s.id) }"
      :aria-pressed="isOn(s.id)"
      @click="emit('toggle', s)"
    >
      <span v-if="multi" class="tick" :class="{ on: isOn(s.id) }" aria-hidden="true">
        <svg v-if="isOn(s.id)" viewBox="0 0 24 24" fill="none" stroke="currentColor"
          stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
          <path d="M20 6L9 17l-5-5" />
        </svg>
      </span>
      <img v-if="s.image" :src="s.image" alt="" class="svc-thumb" />
      <div class="grow">
        <div class="title">{{ s.name }}</div>
        <div class="meta">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <circle cx="12" cy="12" r="9" />
            <path d="M12 7v5l3 2" />
          </svg>
          {{ duration(s.duration_min) }}
        </div>
      </div>
      <div class="end">
        <div class="price">{{ soms(s.price_tiyin) }}</div>
        <span v-if="s.deposit_tiyin > 0" class="badge deposit">
          depozit {{ soms(s.deposit_tiyin) }}
        </span>
      </div>
      <span v-if="!multi" class="chev">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"
          stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M9 18l6-6-6-6" />
        </svg>
      </span>
    </button>
    </template>

    <div v-if="multi && chosen.length" class="basket">
      <div class="basket-sum">
        <strong>{{ soms(totalPrice) }}</strong>
        <span>{{ chosen.length }} ta xizmat · {{ duration(totalMin) }}</span>
        <span v-if="totalDeposit > 0" class="basket-dep">depozit {{ soms(totalDeposit) }}</span>
      </div>
      <button class="btn" @click="emit('next')">Davom etish</button>
    </div>
  </div>
</template>

<style scoped>
.tick {
  width: 22px;
  height: 22px;
  flex: 0 0 auto;
  border-radius: 6px;
  border: 1.5px solid var(--border);
  display: grid;
  place-items: center;
  color: #fff;
  margin-right: 12px;
}
.tick.on {
  background: var(--brand);
  border-color: var(--brand);
}
.tick svg {
  width: 13px;
  height: 13px;
}

/* Sticky summary: the total has to stay visible while the list scrolls. */
.basket {
  position: sticky;
  bottom: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  flex-wrap: wrap;
  margin-top: 14px;
  padding: 12px 14px;
  border: 1px solid var(--border);
  border-radius: 14px;
  background: var(--surface);
  box-shadow: 0 -6px 20px rgba(0, 0, 0, 0.18);
}
.basket-sum {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.basket-sum strong {
  font-size: 17px;
}
.basket-sum span {
  font-size: 12.5px;
  color: var(--muted);
}
.basket-dep {
  color: var(--warning, #d9a441) !important;
}
.basket .btn {
  margin: 0;
  width: auto;
  padding-inline: 22px;
  flex: 0 0 auto;
}
.svc-thumb {
  width: 52px;
  height: 52px;
  border-radius: 10px;
  object-fit: cover;
  flex: 0 0 auto;
  margin-right: 12px;
  box-shadow: inset 0 0 0 1px var(--border);
}
.group-head {
  margin: 18px 0 8px;
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--muted);
}
.group-head:first-of-type {
  margin-top: 6px;
}
.tabs {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding-bottom: 4px;
  margin-bottom: 6px;
  scrollbar-width: none;
}
.tabs::-webkit-scrollbar {
  display: none;
}
.tab {
  flex: 0 0 auto;
  padding: 8px 14px;
  border: 1px solid var(--border);
  border-radius: 999px;
  background: var(--surface);
  color: var(--muted);
  font: inherit;
  font-size: 13.5px;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
}
.tab.on {
  background: var(--brand);
  border-color: var(--brand);
  color: #fff;
}
.other-picked {
  margin: 0 0 10px;
  font-size: 12.5px;
  color: var(--muted);
}
</style>
