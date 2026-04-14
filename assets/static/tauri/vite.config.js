import { defineConfig } from 'vite'

// Dev server used only for e2e testing with tauri-plugin-playwright.
// Serves static assets and proxies /pw-poll + /pw to the plugin's HTTP server.
export default defineConfig({
  root: '.',
  server: {
    port: 1430,
    proxy: {
      '/pw-poll': 'http://127.0.0.1:6275',
      '/pw': 'http://127.0.0.1:6275',
    },
  },
})
