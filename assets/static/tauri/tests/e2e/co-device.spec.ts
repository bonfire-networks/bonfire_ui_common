// Co-device e2e tests — 1 server, 2 Tauri clients with the same actor.
// Devices: tauriPage = s1_alice_d1, deviceAlice2 = s1_alice_d2
// Run with: just test-tauri-e2e-co-device
// Requires: E2E_S1_ALICE_LOGIN/PASSWORD

import { test, expect, waitForChatView, shadowClick, shadowExists, createGroupAndRefresh, pollInbox, leaveGroup, isNoLongerMember, getOwnSignatureKey } from './helpers';

const GET_CTRL = `(() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })()`;

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

    // After joining from Welcome, d2 must have replenished its KP (old init_key was consumed).
    // Verify: stored KP is self-signable with d2's own identity key (same signature_key, new init_key).
    const kpSelfValid = await deviceAlice2!.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const kpB64 = await ctrl.mlsService.getKeyPackageHex(ctrl.currentActorId);
      if (!kpB64) return false;
      const fp = await ctrl.mlsService.getKeyPackageFingerprint(kpB64);
      const { signerKey } = await ctrl.mlsService.signData(ctrl.currentActorId, kpB64);
      return signerKey === fp?.signatureKey;
    })()`);
    expect(kpSelfValid).toBe(true);
  });

  test('s1_alice_d1 leaves shared group → s1_alice_d2 sees co-device confirmation → confirms → d1 removed + d2 leaf rotated', async ({ tauriPage, deviceAlice2 }) => {
    test.setTimeout(90_000); // co-device stagger: leafIndex×30s before dialog appears
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 10_000);
    expect(sharedGroupId).toBeTruthy();

    // Capture d2's fingerprint before confirming (to verify UpdatePath rotated the leaf after)
    const d2FingerprintBefore = await deviceAlice2!.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const fp = await ctrl.mlsService.getOwnFingerprint(ctrl.currentActorId);
      return fp?.fingerprint?.map(f => f.emoji).join('');
    })()`);

    await leaveGroup(tauriPage, sharedGroupId!);
    expect(await isNoLongerMember(tauriPage, sharedGroupId!)).toBe(true);

    // d2 polls → co-device dialog appears at leafIndex×30s slot
    await pollInbox(deviceAlice2!);

    // Wait specifically for the co-device leaving confirmation (not a new-device "Approve" dialog)
    await deviceAlice2!.waitForFunction(
      'window.shadowQ("e2ee-chat-view >>> #nd-approve")?.textContent?.trim() === "Confirm removal"',
      40_000
    );

    // d2 confirms → commitCoDeviceLeaving → real Commit distributed
    await shadowClick(deviceAlice2!, 'e2ee-chat-view >>> #nd-approve');
    await deviceAlice2!.waitForFunction(
      'window.shadowQ("e2ee-chat-view >>> #nd-approve") == null',
      10_000
    );

    // d2: only d2's leaf remains in the MLS tree (d1 removed)
    const fingerprintCount = await deviceAlice2!.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const actor = await ctrl.mlsService.getActor?.() || { id: ctrl.currentActorId };
      const fps = await ctrl.mlsService.getGroupFingerprints(actor.id, ${JSON.stringify(sharedGroupId)});
      return fps.filter(f => f.isOwn).length;
    })()`);
    expect(fingerprintCount).toBe(1);

    // d2's leaf should have been rotated by the Commit's UpdatePath (PCS)
    const d2FingerprintAfter = await deviceAlice2!.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const fp = await ctrl.mlsService.getOwnFingerprint(ctrl.currentActorId);
      return fp?.fingerprint?.map(f => f.emoji).join('');
    })()`);
    expect(d2FingerprintAfter).not.toBe(d2FingerprintBefore);
  });

  test('s1_alice_d1: decommission d2 → d2 leaves all groups + KP removed from server', async ({ tauriPage, deviceAlice2 }) => {
    test.setTimeout(60_000);
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 20_000);
    expect(sharedGroupId).toBeTruthy();

    // Get d2's signature key so d1 can decommission it
    const d2SigKey = await getOwnSignatureKey(deviceAlice2!);
    expect(d2SigKey).toBeTruthy();

    // d1 decommissions d2 (removes d2 from all groups + deletes its KP from server)
    await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      await ctrl.removeOwnClient(${JSON.stringify(d2SigKey)});
    })()`);

    // d2 polls → receives the Commit removing it from sharedGroupId
    await pollInbox(deviceAlice2!);

    // d2 should see itself as no longer member of sharedGroupId
    expect(await isNoLongerMember(deviceAlice2!, sharedGroupId!)).toBe(true);

    // d1 re-fetches actor keyPackages — only d1's KP should remain
    const remainingKpCount = await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const actorJson = localStorage.getItem('actor');
      const actor = actorJson ? JSON.parse(actorJson) : { id: ctrl.currentActorId };
      return await ctrl._actorHasOtherDevices(actor, await ctrl.mlsService.getOwnSignatureKey(ctrl.currentActorId))
        ? 2 : 1; // _actorHasOtherDevices returns true only if a DIFFERENT key exists
    })()`);
    expect(remainingKpCount).toBe(1); // only d1 remains
  });

});
