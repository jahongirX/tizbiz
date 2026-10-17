<script setup>
// "Where to go" card shown on the success screen: address + a button that opens
// the spot on a map. Falls back to a Google Maps search on the address when the
// business has no explicit map link. Renders nothing when there's no location.
import { computed } from 'vue'

const props = defineProps({
  business: { type: Object, default: null },
})

const address = computed(() => props.business?.address || '')
const phone = computed(() => props.business?.phone || props.business?.phone_number || '')
const mapUrl = computed(() => {
  const b = props.business || {}
  if (b.map_url) return b.map_url
  const q = [b.name, b.address].filter(Boolean).join(', ')
  return q ? `https://maps.google.com/?q=${encodeURIComponent(q)}` : ''
})
const show = computed(() => !!(address.value || mapUrl.value))
</script>

<template>
  <div v-if="show" class="loc">
    <div class="loc-top">
      <span class="loc-pin">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
          stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
          <circle cx="12" cy="10" r="3" />
        </svg>
      </span>
      <div class="loc-txt">
        <div class="loc-label">Manzil</div>
        <div v-if="address" class="loc-addr">{{ address }}</div>
        <a v-if="phone" class="loc-phone" :href="`tel:${phone}`">{{ phone }}</a>
      </div>
    </div>
    <a v-if="mapUrl" class="loc-btn" :href="mapUrl" target="_blank" rel="noopener">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
        stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <polygon points="3 6 9 3 15 6 21 3 21 18 15 21 9 18 3 21 3 6" />
        <line x1="9" y1="3" x2="9" y2="18" />
        <line x1="15" y1="6" x2="15" y2="21" />
      </svg>
      Xaritada ochish
    </a>
  </div>
</template>

<style scoped>
.loc {
  border: 1px solid var(--line, #2a2d3a);
  border-radius: 16px;
  padding: 14px;
  margin-top: 14px;
}
.loc-top {
  display: flex;
  gap: 12px;
  align-items: flex-start;
}
.loc-pin {
  flex-shrink: 0;
  width: 40px;
  height: 40px;
  border-radius: 12px;
  display: grid;
  place-items: center;
  background: color-mix(in srgb, var(--brand, #5850ec) 16%, transparent);
  color: var(--brand, #5850ec);
}
.loc-pin svg {
  width: 22px;
  height: 22px;
}
.loc-txt {
  min-width: 0;
}
.loc-label {
  font-size: 12px;
  color: var(--muted, #8b90a3);
}
.loc-addr {
  font-weight: 600;
  margin-top: 1px;
  line-height: 1.35;
}
.loc-phone {
  display: inline-block;
  margin-top: 4px;
  font-size: 14px;
  color: var(--brand, #5850ec);
  text-decoration: none;
}
.loc-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  width: 100%;
  height: 46px;
  margin-top: 12px;
  border-radius: 14px;
  background: var(--brand, #5850ec);
  color: var(--brand-ink, #fff);
  font-size: 15px;
  font-weight: 600;
  text-decoration: none;
}
.loc-btn svg {
  width: 18px;
  height: 18px;
}
</style>
