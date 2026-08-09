// Shared reactive navigation-loading state for the route preloader.
// The router toggles it (beforeEach -> start, afterEach -> stop) and App.vue
// renders <Preloader v-if="isLoading" />. A minimum visible duration keeps the
// animation readable even on instant client-side navigations.

import { ref } from 'vue'

export const isLoading = ref(false)

const MIN_VISIBLE = 600 // ms — how long the preloader stays up at minimum
let shownAt = 0
let hideTimer = null

export function startLoading() {
  if (hideTimer) {
    clearTimeout(hideTimer)
    hideTimer = null
  }
  shownAt = Date.now()
  isLoading.value = true
}

export function stopLoading() {
  const elapsed = Date.now() - shownAt
  const wait = Math.max(0, MIN_VISIBLE - elapsed)
  if (hideTimer) clearTimeout(hideTimer)
  hideTimer = setTimeout(() => {
    isLoading.value = false
    hideTimer = null
  }, wait)
}
