const { createTauriTest } = require('../../node_modules/@srsholmes/tauri-playwright/dist/index.js');

const { test, expect } = createTauriTest({
  devUrl: 'http://localhost:1430',
  ipcMocks: {
    greet: (args) => `Hello, ${args?.name || 'Guest'}!`,
  },
  mcpSocket: '/tmp/tauri-playwright.sock',
});

module.exports = { test, expect };