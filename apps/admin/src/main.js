import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { auth as apiAuth } from '@tizbiz/api-client'
import App from './App.vue'
import router from './router'
import { useAuthStore } from './stores/auth'
import './style.css'

// Cross-subdomain handoff: registration happens on tizbiz.uz/register, which
// sends the freshly issued JWT here as `#t=<jwt>` (hash → never hits server
// logs). Consume it before the auth check so the new owner lands logged in.
const _handoff = location.hash.match(/[#&]t=([^&]+)/)
if (_handoff) {
  apiAuth.set(decodeURIComponent(_handoff[1]))
  history.replaceState({}, document.title, location.pathname + location.search)
}

// Apply a saved theme override early (before mount) to avoid a flash.
const savedTheme = localStorage.getItem('tizbiz_theme')
if (savedTheme === 'light' || savedTheme === 'dark') {
  document.documentElement.setAttribute('data-theme', savedTheme)
}

async function bootstrap() {
  const app = createApp(App)
  const pinia = createPinia()
  app.use(pinia)

  const auth = useAuthStore()
  if (auth.isAuthed) {
    try {
      await auth.fetchMe()
    } catch (_) {
      auth.logout(false)
    }
  }

  app.use(router)
  app.mount('#app')
}

bootstrap()
