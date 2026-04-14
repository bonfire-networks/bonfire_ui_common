// Device lifecycle e2e tests — exercises real Rust/MLS commands via tauri-plugin-playwright.
// See plan: .claude/plans/refactored-weaving-quail.md
//
// Prerequisites: `just test-tauri-e2e` — starts the dev server, obtains OAuth token,
// and launches the Tauri app in e2e-testing mode (chat webview opens directly).
//
// Tests 1, 2: require a second Bonfire instance on port 4002 (set E2E_INSTANCE_B).
// Tests 3–6: single Tauri window sufficient.

import { test as _test, expect } from '../support/fixtures.cjs';
import type { Page, TestType } from '@playwright/test';
import type { TauriFixtures } from '@srsholmes/tauri-playwright';

type Fixtures = TauriFixtures & { deviceB: Page };
const test = _test as unknown as TestType<Fixtures, object>;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Wait until e2ee-chat-view exists anywhere in the shadow tree.
// shadowQ is injected by tauri-init.js and traverses shadow roots.
async function waitForChatView(tauriPage: any, timeout = 20_000) {
  await tauriPage.waitForFunction(
    'window.shadowQ("e2ee-chat-view") != null',
    timeout
  );
}

// Wait for a deep shadow-piercing selector (split on >>>) then click it.
async function shadowClick(tauriPage: any, selector: string, timeout = 15_000) {
  const expr = `window.shadowQ(${JSON.stringify(selector)}) != null`;
  await tauriPage.waitForFunction(expr, timeout);
  await tauriPage.evaluate(`window.shadowQ(${JSON.stringify(selector)}).click()`);
}

// Evaluate a shadow-piercing selector and return the truthy/falsy result.
async function shadowExists(tauriPage: any, selector: string): Promise<boolean> {
  return tauriPage.evaluate(`!!window.shadowQ(${JSON.stringify(selector)})`);
}

// ---------------------------------------------------------------------------
// Test 1: Second device sends private KP proposal (not public publish)
// ---------------------------------------------------------------------------
test('new device with existing co-device shows waiting-for-approval dialog', async ({ tauriPage, deviceB }) => {
  // Device A (Tauri) is already logged in with a published KeyPackage.
  // Device B (browser page at port 4002) logs in as the same actor — it should
  // detect the existing device and show a "Waiting for approval" dialog.
  await waitForChatView(tauriPage);

  // Device B uses standard Playwright API (plain browser context, not TauriPage)
  await deviceB.waitForSelector('e2ee-chat-view', { timeout: 20_000 });

  const dialog = await deviceB.waitForSelector(
    'e2ee-chat-view >>> #nd-pending-dialog',
    { timeout: 15_000 }
  );
  expect(dialog).toBeTruthy();

  // No Approve button on the pending side
  const approve = await deviceB.$('e2ee-chat-view >>> #nd-pending-dialog #nd-approve');
  expect(approve).toBeNull();
});

// ---------------------------------------------------------------------------
// Test 2: Existing device (Device A) approves new device (Device B)
// ---------------------------------------------------------------------------
test('existing device can approve a new device KeyPackage proposal', async ({ tauriPage, deviceB }) => {
  await waitForChatView(tauriPage);
  await deviceB.waitForSelector('e2ee-chat-view', { timeout: 20_000 });

  // Device A's inbox receives the private Create { KeyPackage } from Device B.
  // After the next poll, _showDeviceConfirmation appears with an Approve button.
  await shadowClick(tauriPage, 'e2ee-chat-view >>> #nd-approve', 20_000);

  // Dialog closes on Device A after publishing the endorsed KP
  await tauriPage.waitForFunction(
    'window.shadowQ("e2ee-chat-view >>> #nd-approve") == null',
    10_000
  );

  // Device B's pending dialog closes once it receives the published Add { KeyPackage }
  await deviceB.waitForSelector(
    'e2ee-chat-view >>> #nd-pending-dialog',
    { state: 'detached', timeout: 20_000 }
  );
});

// ---------------------------------------------------------------------------
// Test 3: Leave group sends Proposal, dialog confirms departure
// ---------------------------------------------------------------------------
test('leaving a group sends MLS self-remove proposal', async ({ tauriPage }) => {
  await waitForChatView(tauriPage);

  // Prerequisite: a group must exist in the sidebar. Select the first one.
  await tauriPage.waitForFunction(
    'window.shadowQ("e2ee-chat-view >>> .group-list [data-group-id]") != null',
    15_000
  );
  await tauriPage.evaluate(
    '(window.shadowQ("e2ee-chat-view >>> .group-list [data-group-id]")).click()'
  );

  // Open the members panel by clicking on own user in the member list
  await tauriPage.waitForFunction(
    'window.shadowQ("e2ee-chat-view >>> .members-panel [data-self]") != null',
    5_000
  );
  await tauriPage.evaluate(
    'window.shadowQ("e2ee-chat-view >>> .members-panel [data-self]").click()'
  );

  // The "Leave group" button appears in the member footer (btn-warning)
  await shadowClick(tauriPage, 'e2ee-chat-view >>> .btn-warning', 5_000);

  // The group should no longer appear in the list after the leave Proposal is sent
  await tauriPage.waitForFunction(
    'window.shadowQ("e2ee-chat-view >>> [data-group-id]") == null',
    15_000
  );
});

// ---------------------------------------------------------------------------
// Test 4: Co-device leave shows confirmation prompt with fingerprint
// ---------------------------------------------------------------------------
test('co-device leave proposal shows confirmation dialog with fingerprint', async ({ tauriPage }) => {
  await waitForChatView(tauriPage);

  // When inbox delivers a self-remove proposal from a co-device,
  // _showDeviceConfirmation({ isLeaving: true }) is called.
  // The dialog has "Confirm removal" as the approve button text.
  await tauriPage.waitForFunction(
    'window.shadowQ("e2ee-chat-view >>> #nd-approve") != null',
    20_000
  );

  const btnText = await tauriPage.evaluate(
    'window.shadowQ("e2ee-chat-view >>> #nd-approve")?.textContent?.trim()'
  );
  expect(btnText).toContain('Confirm removal');

  // Fingerprint emoji visible in dialog
  const hasFp = await shadowExists(tauriPage, 'e2ee-chat-view >>> .modal .text-2xl');
  expect(hasFp).toBeTruthy();

  // Confirm removal
  await shadowClick(tauriPage, 'e2ee-chat-view >>> #nd-approve', 5_000);

  // Dialog closes after commit
  await tauriPage.waitForFunction(
    'window.shadowQ("e2ee-chat-view >>> #nd-approve") == null',
    10_000
  );
});

// ---------------------------------------------------------------------------
// Test 5: Clear all data — solo device sees irrecoverable warning (Rust dialog)
// ---------------------------------------------------------------------------
test('clear all data on solo device shows irrecoverable warning', async ({ tauriPage }) => {
  await waitForChatView(tauriPage);

  // Open the user dropdown menu (top-right button with caret-down icon)
  await shadowClick(tauriPage, 'e2ee-chat-view >>> .dropdown [role="button"]', 5_000);

  // Click "Settings" link in the dropdown — calls _openMyDevicesPanel()
  await tauriPage.evaluate(`
    Array.from(window.shadowQ('e2ee-chat-view')?.shadowRoot?.querySelectorAll('li a') || [])
      .find(a => a.textContent.includes('Settings'))?.click()
  `);

  // Wait for my-devices-panel to be appended to the shadow root
  await tauriPage.waitForFunction(
    'window.shadowQ("e2ee-chat-view >>> my-devices-panel") != null',
    5_000
  );

  // Expand the "Advanced" details section
  await tauriPage.evaluate(`
    window.shadowQ('e2ee-chat-view >>> my-devices-panel')
      ?.shadowRoot?.querySelector('details summary')?.click()
  `);

  // Click "Delete this device and local data" — triggers Rust native dialog
  await tauriPage.evaluate(`
    Array.from(
      window.shadowQ('e2ee-chat-view >>> my-devices-panel')
        ?.shadowRoot?.querySelectorAll('button') || []
    ).find(b => b.textContent.includes('Delete this device'))?.click()
  `);

  // After the Rust dialog is dismissed, _loading clears and app stays alive
  await tauriPage.waitForFunction(
    '!window.shadowQ("e2ee-chat-view >>> my-devices-panel")?._loading',
    10_000
  );

  expect(await shadowExists(tauriPage, 'e2ee-chat-view')).toBeTruthy();
});

// ---------------------------------------------------------------------------
// Test 6: Restart with pending co-device leave resumes confirmation dialog
// ---------------------------------------------------------------------------
test('pending co-device leave survives app reload', async ({ tauriPage }) => {
  await waitForChatView(tauriPage);

  // Inject a pendingCoDeviceLeave flag into storage for the first available group
  await tauriPage.evaluate(`(async () => {
    const view = window.shadowQ('e2ee-chat-view');
    const controller = view?._controller || view?.controller;
    const groups = await controller?.storage?.listGroupsWithLastMessage?.();
    if (groups?.[0]?.groupId) {
      await controller.storage.setGroupField(groups[0].groupId, 'pendingCoDeviceLeave', 'synthetic-proposal-id');
    }
  })()`);

  // Reload simulates restart
  await tauriPage.reload();
  await waitForChatView(tauriPage, 20_000);

  // init() scans for pendingCoDeviceLeave and calls _showDeviceConfirmation({ isLeaving: true })
  await tauriPage.waitForFunction(
    'window.shadowQ("e2ee-chat-view >>> #nd-approve") != null',
    15_000
  );

  const btnText = await tauriPage.evaluate(
    'window.shadowQ("e2ee-chat-view >>> #nd-approve")?.textContent?.trim()'
  );
  expect(btnText).toContain('Confirm removal');
});
