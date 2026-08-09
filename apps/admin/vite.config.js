import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  base: '/app/',
  build: { outDir: '../../backend/web/app', emptyOutDir: true },
  server: { port: 5172, host: true },
})
