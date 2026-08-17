import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  base: '/app/',
  build: { outDir: '../../sms/web/app', emptyOutDir: true },
  server: { port: 5175, host: true },
})
