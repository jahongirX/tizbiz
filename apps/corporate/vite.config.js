import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  base: '/app/',
  build: { outDir: '../../frontend/web/app', emptyOutDir: true },
  server: { port: 5171, host: true },
})
