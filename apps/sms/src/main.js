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
    } catch (_) {
      auth.logout(false)
    }
  }

  app.use(router)
  app.mount('#app')
}

bootstrap()
