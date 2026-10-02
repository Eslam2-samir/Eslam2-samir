import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.svg'],
      manifest: {
        name: 'El Saidy Travel · Student Bus Reservations',
        short_name: 'El Saidy',
        description: 'Student transportation reservations between Suez and Galala.',
        lang: 'ar',
        dir: 'rtl',
        theme_color: '#0b2421',
        background_color: '#f4f7f8',
        display: 'standalone',
        start_url: '/auth/login',
        icons: [
          { src: '/icons/icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png' },
          { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any maskable' },
        ],
      },
      workbox: {
        cleanupOutdatedCaches: true,
        navigateFallback: '/index.html',
        runtimeCaching: [],
      },
    }),
  ],
  resolve: { alias: { '@': '/src' } },
  server: { host: '0.0.0.0', port: 3000 },
})
