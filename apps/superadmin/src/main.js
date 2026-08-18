import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import { useAuthStore } from './stores/auth'
import './style.css'

async function bootstrap() {
  const app = createApp(App)
  app.use(createPinia())

  const auth = useAuthStore()
  if (auth.isAuthed) {
    try {
      await auth.fetchMe()
    } catch (e) {
      // Only a real 401 (expired/invalid token) should end the session; a
      // transient network/TLS/CORS hiccup must not kick the user to login.
      if (e && e.status === 401) auth.logout(false)
    }
  }

  app.use(router)
  app.mount('#app')
}

bootstrap()
