import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg}'],
        runtimeCaching: [
          {
            // API local — network-first con fallback a cache
            urlPattern: /^http:\/\/localhost:3000\/api\/.*/i,
            handler: 'NetworkFirst',
            options: {
              cacheName: 'resilios-api-cache',
              networkTimeoutSeconds: 3,
              expiration: { maxEntries: 200, maxAgeSeconds: 86400 },
              cacheableResponse: { statuses: [0, 200] }
            }
          },
          {
            // Assets estáticos — cache-first
            urlPattern: /\.(?:js|css|woff2|png|svg|ico)$/,
            handler: 'CacheFirst',
            options: {
              cacheName: 'resilios-assets',
              expiration: { maxEntries: 60, maxAgeSeconds: 2592000 }
            }
          }
        ]
      },
      manifest: {
        name:             'ResiliOS POS',
        short_name:       'ResiliOS',
        description:      'Sistema de pedidos offline-first para restaurantes',
        theme_color:      '#534AB7',
        background_color: '#ffffff',
        display:          'standalone',
        orientation:      'landscape',
        start_url:        '/',
        icons: [
          { src: '/icons/icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png' }
        ]
      }
    })
  ],
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:3001',
        changeOrigin: true
      },
      '/health': {
        target: 'http://localhost:3001',
        changeOrigin: true
      }
    }
  }
})
