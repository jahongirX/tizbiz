import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  base: '/app/',
  build: { outDir: '../../superadmin/web/app', emptyOutDir: true },
  server: { port: 5176, host: true },
})
