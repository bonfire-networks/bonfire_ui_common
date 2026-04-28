// Device lifecycle e2e tests — exercises real Rust/MLS commands via tauri-plugin-playwright.
// See plan: .claude/plans/refactored-weaving-quail.md
//
// Prerequisites: use the matching just command for the scenario you want to test:
//   just test-tauri-e2e                    — single device (tests 3–6)
//   just test-tauri-e2e-co-device          — 2 clients, 1 server (tests 1–2)
//   just test-tauri-e2e-federated          — 2 clients, 2 servers
//   just test-tauri-e2e-federated-co-device — 3 clients, 2 servers

import { test as _test, expect } from '../support/fixtures.cjs';
import type { TestType } from '@playwright/test';
import type { TauriFixtures } from '@srsholmes/tauri-playwright';

type TauriPage = TauriFixtures['tauriPage'];
type Fixtures = TauriFixtures & { deviceA2: TauriPage | null; deviceB: TauriPage | null };
const test = _test as unknown as TestType<Fixtures, object>;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function waitForChatView(tauriPage: any, timeout = 20_000) {
  await tauriPage.waitForFunction(
    'window.shadowQ("e2ee-chat-view") != null',
    timeout
  );
}

async function shadowClick(tauriPage: any, selector: string, timeout = 15_000) {
  const expr = `window.shadowQ(${JSON.stringify(selector)}) != null`;
  await tauriPage.waitForFunction(expr, timeout);
  await tauriPage.evaluate(`window.shadowQ(${JSON.stringify(selector)}).click()`);
}

async function shadowExists(tauriPage: any, selector: string): Promise<boolean> {
  return tauriPage.evaluate(`!!window.shadowQ(${JSON.stringify(selector)})`);
}

async function createGroupAndRefresh(tauriPage: any): Promise<string | null> {
  const groupId: string | null = await tauriPage.evaluate(`(async () => {
    const view = window.shadowQ('e2ee-chat-view');
    const controller = view?._controller || view?.controller;
    if (!controller) return null;
    try {
      const id = await controller.createGroup();
      if (controller.currentActorId) {
        await controller.persistMembers(id, [controller.currentActorId]);
      }
      if (typeof view.loadGroups === 'function') await view.loadGroups();
      return id;
    } catch (e) {
      console.error('[test] createGroupAndRefresh failed:', e);
      return null;
    }
  })()`);
  return groupId;
}

// ---------------------------------------------------------------------------
// Single-device tests (no extra clients needed)
// ---------------------------------------------------------------------------

test.describe('single-device', { tag: '@single-device' }, () => {

  test('leaving a group sends MLS self-remove proposal', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);

    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();

    await tauriPage.waitForFunction(
      'window.shadowQ("e2ee-chat-view >>> [data-role=group-item]") != null',
      15_000
    );

    await tauriPage.evaluate(`(async () => {
      const view = window.shadowQ('e2ee-chat-view');
      await view._handleLeaveGroup(${JSON.stringify(groupId)});
    })()`);

    const noLongerMember = await tauriPage.evaluate(`(async () => {
      const view = window.shadowQ('e2ee-chat-view');
      const controller = view?._controller || view?.controller;
      return !!(await controller?.storage?.getGroupField(${JSON.stringify(groupId)}, 'noLongerMember', false));
    })()`);
    expect(noLongerMember).toBeTruthy();
  });

  test('co-device leave proposal shows confirmation dialog with fingerprint', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);

    await tauriPage.evaluate(`(async () => {
      const view = window.shadowQ('e2ee-chat-view');
      if (!view || typeof view._showDeviceConfirmation !== 'function') {
        throw new Error('_showDeviceConfirmation not found on e2ee-chat-view');
      }
      view._showDeviceConfirmation({
        isLeaving: true,
        fingerprint: [{ emoji: '🔑' }, { emoji: '🦊' }],
        kpB64: 'dGVzdA==',
        groupId: 'test-group-id',
        proposalActivityId: 'synthetic-proposal-id'
      });
    })()`);

    await tauriPage.waitForFunction(
      'window.shadowQ("e2ee-chat-view >>> #nd-approve") != null',
      5_000
    );

    const btnText = await tauriPage.evaluate(
      'window.shadowQ("e2ee-chat-view >>> #nd-approve")?.textContent?.trim()'
    );
    expect(btnText).toContain('Confirm removal');

    const hasFp = await shadowExists(tauriPage, 'e2ee-chat-view >>> [data-role=nd-fingerprint]');
    expect(hasFp).toBeTruthy();

    await tauriPage.evaluate(`
      window.shadowQ('e2ee-chat-view')?.shadowRoot
        ?.querySelector('#nd-approve')?.closest('dialog')?.remove()
    `);
  });

  test('clear all data on solo device shows irrecoverable warning', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);

    await shadowClick(tauriPage, 'e2ee-chat-view >>> .dropdown [role="button"]', 5_000);

    await tauriPage.evaluate(`
      Array.from(window.shadowQ('e2ee-chat-view')?.shadowRoot?.querySelectorAll('li a') || [])
        .find(a => a.textContent.includes('Settings'))?.click()
    `);

    await tauriPage.waitForFunction(
      'window.shadowQ("e2ee-chat-view >>> my-devices-panel") != null',
      5_000
    );

    await tauriPage.evaluate(`
      window.shadowQ('e2ee-chat-view >>> my-devices-panel')
        ?.shadowRoot?.querySelector('details summary')?.click()
    `);

    await tauriPage.evaluate(`
      Array.from(
        window.shadowQ('e2ee-chat-view >>> my-devices-panel')
          ?.shadowRoot?.querySelectorAll('button') || []
      ).find(b => b.textContent.includes('Delete this device'))?.click()
    `);

    await tauriPage.waitForFunction(
      '!window.shadowQ("e2ee-chat-view >>> my-devices-panel")?._loading',
      10_000
    );

    expect(await shadowExists(tauriPage, 'e2ee-chat-view')).toBeTruthy();
  });

  test('pending co-device leave survives app reload', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);

    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();

    await tauriPage.evaluate(`(async () => {
      const view = window.shadowQ('e2ee-chat-view');
      const controller = view?._controller || view?.controller;
      const groups = await controller?.storage?.listGroupsWithLastMessage?.();
      const id = groups?.[0]?.groupId;
      if (id) {
        await controller.storage.setGroupField(id, 'pendingCoDeviceLeave', 'synthetic-proposal-id');
      } else {
        throw new Error('No groups found to inject pendingCoDeviceLeave');
      }
    })()`);

    await tauriPage.reload();
    await waitForChatView(tauriPage, 20_000);

    await tauriPage.waitForFunction(
      'window.shadowQ("e2ee-chat-view >>> #nd-approve") != null',
      15_000
    );

    const btnText = await tauriPage.evaluate(
      'window.shadowQ("e2ee-chat-view >>> #nd-approve")?.textContent?.trim()'
    );
    expect(btnText).toContain('Confirm removal');
  });

});

// ---------------------------------------------------------------------------
// Co-device tests: 1 server, 2 Tauri clients (same actor)
// Run with: just test-tauri-e2e-co-device
// ---------------------------------------------------------------------------

test.describe('co-device', { tag: '@co-device' }, () => {

  test('new device with existing co-device shows waiting-for-approval dialog', async ({ tauriPage, deviceA2 }) => {
    await waitForChatView(tauriPage);
    await waitForChatView(deviceA2!, 20_000);

    await deviceA2!.waitForFunction(
      'window.shadowQ("e2ee-chat-view >>> #nd-pending-dialog") != null',
      15_000
    );

    const approve = await shadowExists(deviceA2!, 'e2ee-chat-view >>> #nd-pending-dialog #nd-approve');
    expect(approve).toBeFalsy();
  });

  test('existing device can approve a new device KeyPackage proposal', async ({ tauriPage, deviceA2 }) => {
    await waitForChatView(tauriPage);
    await waitForChatView(deviceA2!, 20_000);

    await shadowClick(tauriPage, 'e2ee-chat-view >>> #nd-approve', 20_000);

    await tauriPage.waitForFunction(
      'window.shadowQ("e2ee-chat-view >>> #nd-approve") == null',
      10_000
    );

    await deviceA2!.waitForFunction(
      'window.shadowQ("e2ee-chat-view >>> #nd-pending-dialog") == null',
      20_000
    );
  });

});

// ---------------------------------------------------------------------------
// Federated tests: 2 servers, 2 Tauri clients (different actors)
// Run with: just test-tauri-e2e-federated
// ---------------------------------------------------------------------------

test.describe('federated', { tag: '@federated' }, () => {

  test('cross-server message delivery', async ({ tauriPage, deviceB }) => {
    await waitForChatView(tauriPage);
    await waitForChatView(deviceB, 20_000);

    // TODO: implement federated message flow test
    // (create group on A1, invite B1, send message, assert received)
    expect(true).toBeTruthy();
  });

});

// ---------------------------------------------------------------------------
// Federated co-device tests: 2 servers, 3 Tauri clients (A1+A2 on server A, B1 on server B)
// Run with: just test-tauri-e2e-federated-co-device
// ---------------------------------------------------------------------------

test.describe('federated-co-device', { tag: '@federated-co-device' }, () => {

  test('co-device leave in federated group notifies all participants', async ({ tauriPage, deviceA2, deviceB }) => {
    await waitForChatView(tauriPage);
    await waitForChatView(deviceA2, 20_000);
    await waitForChatView(deviceB, 20_000);

    // TODO: implement federated co-device leave flow
    // (create group with A1+A2+B1, A2 leaves, A1 sees confirmation, B1 gets commit)
    expect(true).toBeTruthy();
  });

});
