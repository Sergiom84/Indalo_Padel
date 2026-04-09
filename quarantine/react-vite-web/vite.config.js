import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const API_TARGET = env.VITE_API_URL || `http://localhost:${env.VITE_API_PORT || 3010}`
  const FRONT_PORT = Number(env.VITE_PORT || 5173)
  const isDemoMode = env.VITE_DEMO_MODE === 'true' || !env.DATABASE_URL

  return {
    plugins: [react()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src'),
      },
    },
    server: {
      port: FRONT_PORT,
      strictPort: false,
      proxy: isDemoMode
        ? undefined
        : {
            '/api': {
              target: API_TARGET,
              changeOrigin: true,
              secure: false,
            }
          }
    },
    build: {
      rollupOptions: {
        output: {
          manualChunks(id) {
            if (id.includes('node_modules')) {
              if (id.includes('react') || id.includes('react-dom') || id.includes('react-router')) {
                return 'react-vendor';
              }
              if (id.includes('framer-motion') || id.includes('@radix-ui') || id.includes('lucide-react')) {
                return 'ui-vendor';
              }
              if (id.includes('recharts')) {
                return 'charts-vendor';
              }
              if (id.includes('react-hook-form') || id.includes('zod')) {
                return 'forms-vendor';
              }
              return 'vendor';
            }
            if (id.includes('components/Padel/')) {
              return 'padel';
            }
          }
        }
      },
      target: 'esnext',
      minify: 'terser',
      terserOptions: {
        compress: {
          drop_console: true,
          drop_debugger: true,
        }
      },
      chunkSizeWarningLimit: 1000,
    }
  }
})
