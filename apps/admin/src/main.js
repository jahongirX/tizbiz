import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import { useAuthStore } from './stores/auth'
import './style.css'

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
