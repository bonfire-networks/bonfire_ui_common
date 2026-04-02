// see https://lib.rs/crates/tauri-plugin-playwright for docs

import { test, expect } from '../support/fixtures.cjs';
test('greets via Tauri IPC', async ({ tauriPage }) => {
    await tauriPage.fill('[data-testid="greet-input"]', 'World');
    await tauriPage.click('[data-testid="btn-greet"]');
    await expect(tauriPage.getByTestId('greet-result')).toContainText('Hello, World!');
});