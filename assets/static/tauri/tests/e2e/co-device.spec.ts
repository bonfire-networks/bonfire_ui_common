// Co-device e2e tests — 1 server, 2 Tauri clients with the same actor.
// Devices: tauriPage = s1_alice_d1, deviceAlice2 = s1_alice_d2
// Run with: just test-tauri-e2e-co-device
// Requires: E2E_S1_ALICE_LOGIN/PASSWORD

import { test, expect, waitForChatView, shadowClick, shadowExists, createGroupAndRefresh, pollInbox, leaveGroup, isNoLongerMember } from './helpers';

// Set by test 2 (before approval) and consumed by test 3
let sharedGroupId: string | null = null;

test.describe('co-device', { tag: '@co-device' }, () => {

  test('s1_alice_d2: new device with existing co-device shows waiting-for-approval dialog', async ({ tauriPage, deviceAlice2 }) => {
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 20_000);

    await deviceAlice2!.waitForFunction(
      'window.shadowQ("e2ee-chat-view >>> #nd-pending-dialog") != null',
      15_000
    );

    const approve = await shadowExists(deviceAlice2!, 'e2ee-chat-view >>> #nd-pending-dialog #nd-approve');
    expect(approve).toBeFalsy();
  });

  test('s1_alice_d1: existing device can approve s1_alice_d2 KeyPackage proposal', async ({ tauriPage, deviceAlice2 }) => {
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 20_000);

    // Create group BEFORE approving — approveNewDevice adds d2 to all existing groups
    sharedGroupId = await createGroupAndRefresh(tauriPage);
    expect(sharedGroupId).toBeTruthy();

    await shadowClick(tauriPage, 'e2ee-chat-view >>> #nd-approve', 20_000);

    await tauriPage.waitForFunction(
      'window.shadowQ("e2ee-chat-view >>> #nd-approve") == null',
      10_000
    );
    await deviceAlice2!.waitForFunction(
      'window.shadowQ("e2ee-chat-view >>> #nd-pending-dialog") == null',
      20_000
    );

    // Wait for d2 to receive and join the Welcome for sharedGroupId
    await deviceAlice2!.waitForFunction(
      `(async () => {
        const view = window.shadowQ('e2ee-chat-view');
        const ctrl = view?._controller || view?.controller;
        await ctrl?.pollInbox();
        const groups = await ctrl?.storage?.listGroupsWithLastMessage?.() ?? [];
        return groups.some(g => g.groupId === ${JSON.stringify(sharedGroupId)});
      })()`,
      15_000
    );
  });

  test('s1_alice_d1 leaves shared group → s1_alice_d2 sees co-device confirmation → confirms → d1 removed', async ({ tauriPage, deviceAlice2 }) => {
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 10_000);
    expect(sharedGroupId).toBeTruthy();

    await leaveGroup(tauriPage, sharedGroupId!);
    expect(await isNoLongerMember(tauriPage, sharedGroupId!)).toBe(true);

    // d2 polls → co-device dialog appears at leafIndex×30s slot
    await pollInbox(deviceAlice2!);

    await deviceAlice2!.waitForFunction(
      'window.shadowQ("e2ee-chat-view >>> #nd-approve") != null',
      40_000
    );
    expect(await deviceAlice2!.evaluate(
      'window.shadowQ("e2ee-chat-view >>> #nd-approve")?.textContent?.trim()'
    )).toContain('Confirm removal');

    // d2 confirms → commitCoDeviceLeaving → real Commit distributed
    await shadowClick(deviceAlice2!, 'e2ee-chat-view >>> #nd-approve');
    await deviceAlice2!.waitForFunction(
      'window.shadowQ("e2ee-chat-view >>> #nd-approve") == null',
      10_000
    );

    // d2: only d2's leaf remains in the MLS tree (d1 removed)
    const fingerprintCount = await deviceAlice2!.evaluate(`(async () => {
      const ctrl = (() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })();
      const actor = await ctrl.mlsService.getActor?.() || { id: ctrl.currentActorId };
      const fps = await ctrl.mlsService.getGroupFingerprints(actor.id, ${JSON.stringify(sharedGroupId)});
      return fps.filter(f => f.isOwn).length;
    })()`);
    expect(fingerprintCount).toBe(1);
  });

});
