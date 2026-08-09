<script setup>
// Public tenant SPA shell ({slug}.tizbiz.uz). It loads the site payload once,
// reads the business `engine` and renders that engine's layout (stage 6). Adding
// a vertical = one entry in ENGINES + a component under ./engines/<key>/ ; the
// slot engine is the current online-booking flow. Engines are lazy-loaded so a
// visitor only downloads the layout their business actually uses.
import { ref, computed, onMounted, defineAsyncComponent } from 'vue'
import { api, config, ApiError } from '@tizbiz/api-client'

const ENGINES = {
  slot: defineAsyncComponent(() => import('./engines/slot/SlotEngineApp.vue')),
}

const slug =
  config.tenantSlug || new URLSearchParams(location.search).get('slug') || 'demo'

const loading = ref(true)
const notFound = ref(false)
const loadError = ref('')
const payload = ref(null)

const engineKey = computed(() => payload.value?.engine || 'slot')
const engineComp = computed(() => ENGINES[engineKey.value] || ENGINES.slot)

onMounted(async () => {
  try {
    const data = await api.get(`/v1/site/${encodeURIComponent(slug)}`)
    if (!data.business) notFound.value = true
    else payload.value = data
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) notFound.value = true
    else loadError.value = e instanceof ApiError ? e.message : 'Sahifani yuklab bo‘lmadi.'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <!-- Loading -->
  <div v-if="loading" class="center">
    <div>
      <div class="spinner"></div>
      <p class="note">Yuklanmoqda…</p>
    </div>
  </div>

  <!-- Not found -->
  <div v-else-if="notFound" class="center">
    <div>
      <div style="font-size: 44px">🔍</div>
      <h2>Biznes topilmadi</h2>
      <p class="note">"{{ slug }}" manzili bo‘yicha biznes mavjud emas.</p>
    </div>
  </div>

  <!-- Load error -->
  <div v-else-if="loadError" class="center">
    <div>
      <div style="font-size: 44px">⚠️</div>
      <h2>Xatolik</h2>
      <p class="note">{{ loadError }}</p>
    </div>
  </div>

  <!-- Engine layout -->
  <component
    v-else
    :is="engineComp"
    :slug="slug"
    :business="payload.business"
    :services="payload.services || []"
    :staff="payload.staff || []"
  />
</template>
