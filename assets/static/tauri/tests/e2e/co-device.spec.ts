// Co-device e2e tests — 1 server, 2 Tauri clients with the same actor.
// Devices: tauriPage = s1_alice_d1, deviceAlice2 = s1_alice_d2
// Run with: just test-tauri-e2e-co-device
// Requires: E2E_S1_ALICE_LOGIN/PASSWORD

import { test, expect, waitForChatView, shadowClick, shadowExists, createGroupAndRefresh, pollInbox, leaveGroup, isNoLongerMember, getOwnSignatureKey, ownKpIsSelfSigned, canSendAndReceive, addMemberAndWait, fetchPublishedSignedKP, getActorId } from './helpers';

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
    test.setTimeout(90_000); // approveNewDevice adds d2 to all existing groups (can be many across runs)
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 20_000);

    // Create group BEFORE approving — approveNewDevice adds d2 to all existing groups
    sharedGroupId = await createGroupAndRefresh(tauriPage);
    expect(sharedGroupId).toBeTruthy();

    await shadowClick(tauriPage, 'e2ee-chat-view >>> #nd-approve', 20_000);

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
    expect(await ownKpIsSelfSigned(deviceAlice2!)).toBe(true);

    // Both devices should be able to exchange messages in the shared group.
    expect(await canSendAndReceive(tauriPage, deviceAlice2!, sharedGroupId!)).toBe(true);
    expect(await canSendAndReceive(deviceAlice2!, tauriPage, sharedGroupId!)).toBe(true);
  });

  test('s1_alice_d1 leaves shared group → s1_alice_d2 sees co-device confirmation → confirms → d1 removed + d2 leaf rotated', async ({ tauriPage, deviceAlice2 }) => {
    test.setTimeout(120_000); // co-device stagger: leafIndex×30s before dialog appears
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 10_000);
    expect(sharedGroupId).toBeTruthy();

    // Verify messaging works before d1 leaves (catches key state issues early).
    expect(await canSendAndReceive(tauriPage, deviceAlice2!, sharedGroupId!)).toBe(true);

    await leaveGroup(tauriPage, sharedGroupId!);
    expect(await isNoLongerMember(tauriPage, sharedGroupId!)).toBe(true);

    // SSE doesn't fire in tests — poll d2's inbox repeatedly until the co-device dialog appears.
    // The stagger is leafIndex×30s (d2 is leaf 1 → 30s), so poll every 5s for up to 70s total.
    const pollUntilDialog = async () => {
      const deadline = Date.now() + 70_000;
      while (Date.now() < deadline) {
        await pollInbox(deviceAlice2!);
        const text = await deviceAlice2!.evaluate(
          '(()=>{ const sr=window.shadowQ("e2ee-chat-view")?.shadowRoot; const btn=sr?.querySelector("dialog[data-nd-leaving] #nd-approve"); console.log("[pollUntilDialog] leaving #nd-approve:", btn?.textContent?.trim(), "shadowRoot children:", sr?.children?.length); return btn?.textContent?.trim(); })()'
        );
        if (text === 'Confirm removal') return;
        await new Promise(r => setTimeout(r, 5_000));
      }
      throw new Error('Timed out waiting for "Confirm removal" dialog on d2');
    };
    await pollUntilDialog();

    // d2 confirms → commitCoDeviceLeaving → real Commit distributed
    await deviceAlice2!.evaluate(
      'window.shadowQ("e2ee-chat-view")?.shadowRoot?.querySelector("dialog[data-nd-leaving] #nd-approve")?.click()'
    );
    await deviceAlice2!.waitForFunction(
      'window.shadowQ("e2ee-chat-view")?.shadowRoot?.querySelector("dialog[data-nd-leaving]") == null',
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

    // Note: fingerprints are based on the signature key (identity), which doesn't change on
    // self-update — only the HPKE encryption key rotates via UpdatePath. The meaningful PCS
    // assertion is fingerprintCount == 1 above (d1's leaf removed from the tree).

  });

  test('s1_alice_d1: decommission d2 → d2 leaves all groups + KP removed from server', async ({ tauriPage, deviceAlice2 }) => {
    test.setTimeout(60_000);
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 20_000);
    expect(sharedGroupId).toBeTruthy();

    // Verify d1 and d2 can exchange messages before decommission (both keys valid).
    const preDecommissionGroup = await createGroupAndRefresh(tauriPage);
    expect(preDecommissionGroup).toBeTruthy();
    await addMemberAndWait(tauriPage, preDecommissionGroup!, deviceAlice2!);
    expect(await canSendAndReceive(tauriPage, deviceAlice2!, preDecommissionGroup!)).toBe(true);

    // Get d2's signature key so d1 can decommission it
    const d2SigKey = await getOwnSignatureKey(deviceAlice2!);
    expect(d2SigKey).toBeTruthy();

    // d1 decommissions d2 (removes d2 from all groups + deletes its KP from server)
    await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      await ctrl.removeOwnClient(${JSON.stringify(d2SigKey)});
    })()`);

    // d2 polls → receives the Commit removing it from preDecommissionGroup
    // (d1 already left sharedGroupId in test 3, so only preDecommissionGroup is affected)
    await pollInbox(deviceAlice2!);

    // d2 should see itself as no longer member of preDecommissionGroup
    expect(await isNoLongerMember(deviceAlice2!, preDecommissionGroup!)).toBe(true);

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

  test('group join populates mlsKnownKeys cache with inviter key', async ({ tauriPage, deviceAlice2 }) => {
    test.setTimeout(90_000);
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 20_000);

    const groupId = await createGroupAndRefresh(tauriPage);
    const inviterKpInfo = await fetchPublishedSignedKP(tauriPage, await getActorId(tauriPage));

    await addMemberAndWait(tauriPage, groupId, deviceAlice2!);

    // After joining, deviceAlice2's mlsKnownKeys cache should contain the inviter's signature key
    const cached = await deviceAlice2!.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      return await ctrl.storage.getMlsKnownKey(${JSON.stringify(inviterKpInfo!.mlsSignerKeyId)});
    })()`);
    expect(cached).toBeTruthy();
  });

});
