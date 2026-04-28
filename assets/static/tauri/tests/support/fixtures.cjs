const { createTauriTest, PluginClient, TauriPage } = require('../../node_modules/@srsholmes/tauri-playwright/dist/index.js');

// Device A1 — primary Tauri window (server A, port 4000)
const { test: baseTauriTest, expect } = createTauriTest({
  devUrl: 'http://localhost:1430/assets/ap_c2s_client/index.html',
  mcpSocket: '/tmp/tauri-playwright.sock',
});

// Helper: connect to a tauri-plugin-playwright socket and return a TauriPage.
// Returns null if E2E_DEVICE_* env var is unset (test must skip).
// The app is already on the correct URL from Tauri startup config, so no navigation needed.
// We wait for __PW_ACTIVE__ (set by tauri-plugin-playwright's init script) before returning.
async function connectDevice(envVar, socketPath) {
  if (!process.env[envVar]) return null;
  const client = new PluginClient(socketPath);
  await client.connect();
  const ping = await client.send({ type: 'ping' });
  if (!ping.ok) throw new Error(`Plugin ping failed on ${socketPath}`);
  const page = new TauriPage(client);
  await page.waitForFunction('document.readyState === "complete" && !!window.__PW_ACTIVE__', 30_000);
  return page;
}

// Extend A1's test with deviceA2 and deviceB fixtures.
// Each yields null when the corresponding env var is unset (test must skip via test.describe tag).
const test = baseTauriTest.extend({
  deviceA2: async ({}, use) => {
    const page = await connectDevice('E2E_DEVICE_A2', '/tmp/tauri-playwright-2.sock');
    await use(page);
  },
  deviceB: async ({}, use) => {
    const page = await connectDevice('E2E_DEVICE_B', '/tmp/tauri-playwright-3.sock');
    await use(page);
  },
});

module.exports = { test, expect };
