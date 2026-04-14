const { createTauriTest } = require('../../node_modules/@srsholmes/tauri-playwright/dist/index.js');

// Primary Tauri window — Device A (connects to instance on port 4000)
const { test: baseTauriTest, expect } = createTauriTest({
  devUrl: 'http://localhost:1430/assets/ap_c2s_client/index.html',
  mcpSocket: '/tmp/tauri-playwright.sock',
});

// Extend with a second browser page for Device B (same actor, second window).
// Used in co-device tests. Opens a plain browser page at port 4002 (second federated instance).
const test = baseTauriTest.extend({
  deviceB: async ({ browser }, use) => {
    const context = await browser.newContext();
    const page = await context.newPage();
    await page.goto('http://localhost:4002');
    await use(page);
    await context.close();
  },
});

module.exports = { test, expect };
