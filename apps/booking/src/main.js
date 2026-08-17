import { createApp } from 'vue'
import App from './App.vue'
import './style.css'
import { initTelegram } from './telegram'

// Prepare the Telegram Mini App (no-op in a normal browser) before mounting.
initTelegram()

createApp(App).mount('#app')
