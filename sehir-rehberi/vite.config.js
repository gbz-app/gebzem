import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// base: './' — build cikti dosyalari GORECELI yol kullanir.
// Boylece dist/ herhangi bir alt dizinden (GitHub Pages, R2, Artifact)
// servis edilebilir; kok dizin varsayimi YOK.
export default defineConfig({
  plugins: [react()],
  base: './',
  server: { host: true, port: 5173 },
})
