// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  projects: [
    {
      name: 'browser-only',
      use: { ...devices['Desktop Chrome'], mode: 'browser' },
    },
    {
      name: 'tauri',
      use: { mode: 'tauri' },
    },
  ],
  webServer: {
    command: 'watch -n100 "echo 0"', // 'yarn dev', // TODO?
    port: 1430,
    reuseExistingServer: !process.env.CI,
  },
});
