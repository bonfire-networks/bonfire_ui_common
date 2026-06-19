import { defineConfig } from 'vite'

// TAURI_DEV_HOST is set by `tauri [ios|android] dev --host`: a physical device
// can't reach localhost on the Mac, so the dev server must bind the LAN address.
const host = process.env.TAURI_DEV_HOST

// Dev server used for e2e testing with tauri-plugin-playwright and for
// mobile dev (`just tauri-ios-dev`). Proxies /pw-poll + /pw to the plugin's
// HTTP server when running e2e tests.
export default defineConfig({
  root: '.',
  resolve: {
    // ap_c2s_client is a symlink to a directory outside this repo;
    // preserve symlinks so Vite doesn't resolve the real path outside root.
    preserveSymlinks: true,
  },
  server: {
    host: host || '127.0.0.1',
    port: 1430,
    strictPort: true,
    hmr: host ? { protocol: 'ws', host, port: 1431 } : undefined,
    proxy: {
      '/pw-poll': 'http://127.0.0.1:6275',
      '/pw': 'http://127.0.0.1:6275',
    },
    fs: {
      // Allow serving files through the symlink target outside the Vite root.
      strict: false,
    },
  },
})
