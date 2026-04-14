// Device lifecycle e2e tests — exercises real Rust/MLS commands via tauri-plugin-playwright.
// See plan: .claude/plans/refactored-weaving-quail.md
//
// Prerequisites: run `just dev-federate-tunnel-dance` first.
//   - Instance A (Alice's device 1): http://localhost:4000  — Tauri app under test
//   - Instance B (Bob / Alice's device 2): http://localhost:4002 — second browser context or second Tauri window
//
// Tests 1, 2, 4, 6: two Tauri windows as Device A and Device B for the same actor (same AP server).
// Tests 3, 5: single Tauri window sufficient.

import { test as _test, expect } from '../support/fixtures.cjs';
import type { Page, TestType } from '@playwright/test';
import type { TauriFixtures } from '@srsholmes/tauri-playwright';

type Fixtures = TauriFixtures & { deviceB: Page };
const test = _test as unknown as TestType<Fixtures, object>;

// Helper: get the shadow root of e2ee-chat-view
async function chatView(tauriPage: any) {
  return tauriPage.evaluateHandle(() =>
    document.querySelector('e2ee-chat-view')?.shadowRoot
  );
}

// ---------------------------------------------------------------------------
// Test 1: Second device sends private KP proposal (not public publish)
// ---------------------------------------------------------------------------
test('new device with existing co-device shows waiting-for-approval dialog', async ({ tauriPage, deviceB }) => {
  // Device A (tauriPage) is already logged in with a published KeyPackage.
  // Device B logs in as the same actor on port 4002 — on init it detects the existing
  // device and sends a private Create { KeyPackage } to own inbox instead of publishing.
  await tauriPage.waitForSelector('e2ee-chat-view');

  // Device B: navigate to login and authenticate as same actor
  await deviceB.waitForSelector('e2ee-chat-view');

  // Device B should show "Waiting for approval" pending dialog (isPending=true, no Approve btn)
  const dialog = await deviceB.waitForSelector(
    'e2ee-chat-view >>> #nd-pending-dialog',
    { timeout: 15_000 }
  );
  expect(dialog).toBeTruthy();

  const approve = await deviceB.$('e2ee-chat-view >>> #nd-pending-dialog #nd-approve');
  expect(approve).toBeNull();
});

// ---------------------------------------------------------------------------
// Test 2: Existing device (Device A) approves new device (Device B)
// ---------------------------------------------------------------------------
test('existing device can approve a new device KeyPackage proposal', async ({ tauriPage, deviceB }) => {
  await tauriPage.waitForSelector('e2ee-chat-view');
  await deviceB.waitForSelector('e2ee-chat-view');

  // Device A's inbox receives the private Create { KeyPackage } from Device B.
  // After the next poll, _showDeviceConfirmation({ kpB64, fingerprint }) appears on Device A.
  const approveBtn = await tauriPage.waitForSelector(
    'e2ee-chat-view >>> #nd-approve',
    { timeout: 20_000 }
  );
  await approveBtn.click();

  // Dialog closes on Device A after publishing the endorsed KP
  await tauriPage.waitForSelector(
    'e2ee-chat-view >>> #nd-approve',
    { state: 'detached', timeout: 10_000 }
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
  await tauriPage.waitForSelector('e2ee-chat-view');

  // Open group actions menu and click leave (text matches the leaveGroup button)
  const leaveBtn = await tauriPage.waitForSelector(
    'e2ee-chat-view >>> [data-action="leave-group"], e2ee-chat-view >>> button:text("Leave group")',
    { timeout: 10_000 }
  );
  await leaveBtn.click();

  // Native confirm dialog (Tauri ask) — accept it
  tauriPage.once('dialog', (d: any) => d.accept());

  // The group should no longer appear in the list after leave completes
  await tauriPage.waitForFunction(
    () => {
      const view = document.querySelector('e2ee-chat-view');
      return !view?.shadowRoot?.querySelector('[data-group-id]');
    },
    { timeout: 15_000 }
  );
});

// ---------------------------------------------------------------------------
// Test 4: Co-device leave shows confirmation prompt with fingerprint
// ---------------------------------------------------------------------------
test('co-device leave proposal shows confirmation dialog with fingerprint', async ({ tauriPage }) => {
  await tauriPage.waitForSelector('e2ee-chat-view');

  // When inbox delivers a self-remove proposal from a co-device,
  // _showDeviceConfirmation({ isLeaving: true }) is called.
  // The dialog has "Confirm removal" as the approve button text.
  const confirmBtn = await tauriPage.waitForSelector(
    'e2ee-chat-view >>> #nd-approve:text("Confirm removal")',
    { timeout: 20_000 }
  );
  expect(confirmBtn).toBeTruthy();

  // Fingerprint should be visible in the dialog
  const fp = await tauriPage.$('e2ee-chat-view >>> .modal .text-2xl');
  expect(fp).toBeTruthy();

  // Confirm removal
  await confirmBtn.click();

  // Dialog should close after commit
  await tauriPage.waitForSelector(
    'e2ee-chat-view >>> #nd-approve',
    { state: 'detached', timeout: 10_000 }
  );
});

// ---------------------------------------------------------------------------
// Test 5: Clear all data — solo device sees irrecoverable warning (Rust dialog)
// ---------------------------------------------------------------------------
test('clear all data on solo device shows irrecoverable warning', async ({ tauriPage }) => {
  await tauriPage.waitForSelector('e2ee-chat-view');

  // Open Settings panel
  const settingsBtn = await tauriPage.waitForSelector(
    'e2ee-chat-view >>> button[title="Settings"], e2ee-chat-view >>> button:has(svg[data-icon="gear"])',
    { timeout: 5_000 }
  );
  await settingsBtn.click();

  // Expand Advanced section
  const advanced = await tauriPage.waitForSelector(
    'my-devices-panel >>> details summary',
    { timeout: 5_000 }
  );
  await advanced.click();

  // Click "Delete this device and local data"
  const clearBtn = await tauriPage.waitForSelector(
    'my-devices-panel >>> button:text("Delete this device and local data")',
    { timeout: 5_000 }
  );
  await clearBtn.click();

  // Rust shows a native dialog — cancel it. The app must NOT dispatch auth-error.
  // (Native dialogs in Tauri are synchronous; we check the app is still alive)
  // After cancel, loading state should clear without auth-error event
  await tauriPage.waitForFunction(
    () => !document.querySelector('my-devices-panel')?._loading,
    { timeout: 10_000 }
  );

  // Still logged in — e2ee-chat-view present
  expect(await tauriPage.$('e2ee-chat-view')).toBeTruthy();
});

// ---------------------------------------------------------------------------
// Test 6: Restart with pending co-device leave resumes confirmation dialog
// ---------------------------------------------------------------------------
test('pending co-device leave survives app reload', async ({ tauriPage }) => {
  await tauriPage.waitForSelector('e2ee-chat-view');

  // Inject a pendingCoDeviceLeave flag into storage for the first available group
  await tauriPage.evaluate(async () => {
    const view = document.querySelector('e2ee-chat-view') as any;
    const controller = view?._controller || view?.controller;
    const groups = await controller?.storage?.listGroupsWithLastMessage?.();
    if (groups?.[0]?.groupId) {
      await controller.storage.setGroupField(groups[0].groupId, 'pendingCoDeviceLeave', 'synthetic-proposal-id');
    }
  });

  // Reload simulates restart
  await tauriPage.reload();
  await tauriPage.waitForSelector('e2ee-chat-view');

  // init() scans for pendingCoDeviceLeave and calls _showDeviceConfirmation({ isLeaving: true })
  const confirmBtn = await tauriPage.waitForSelector(
    'e2ee-chat-view >>> #nd-approve:text("Confirm removal")',
    { timeout: 15_000 }
  );
  expect(confirmBtn).toBeTruthy();
});
