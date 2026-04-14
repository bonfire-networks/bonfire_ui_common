// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  use: {
    mode: 'tauri',
  } as any,
  // No webServer — the Tauri app must be running before tests start.
  // Build and launch with: just test-tauri-e2e
  // The tauri-plugin-playwright socket bridge connects Playwright to the live webview.
});
