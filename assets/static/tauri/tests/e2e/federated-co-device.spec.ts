// Federated co-device e2e tests — 2 servers, 3 Tauri clients.
// Devices: tauriPage = s1_alice_d1, deviceAlice2 = s1_alice_d2, deviceCharlie = s2_charlie_d1
// Run with: just test-tauri-e2e-federated-co-device
// Requires: E2E_S1_ALICE_LOGIN/PASSWORD, E2E_S2_CHARLIE_LOGIN/PASSWORD

import { test, expect, waitForChatView, shadowClick, pollInbox, createGroupAndRefresh, addMemberAndWait, leaveGroup, isNoLongerMember, canSendAndReceive, allCanSendAndReceive, waitForMlsMembers, getActorId } from './helpers';

async function createThreeWayGroup(tauriPage: any, deviceAlice2: any, deviceCharlie: any): Promise<{ groupId: string }> {
  const groupId = await createGroupAndRefresh(tauriPage);
  if (!groupId) throw new Error('Failed to create group');
  await addMemberAndWait(tauriPage, groupId, deviceCharlie);
  // Poll d1 so it receives d2's Create {KeyPackage} request and shows #nd-approve.
  await pollInbox(tauriPage);
  // If d2 is not yet approved, use the approval flow (mirrors co-device.spec.ts):
  // approveNewDevice adds d2 to all existing groups including this one.
  // If d2 is already approved (second test in suite), fall back to explicit addMember.
  const approved = await shadowClick(tauriPage, 'e2ee-chat-view >>> #nd-approve', 10_000)
    .then(() => true, () => false);
  if (approved) {
    // approveNewDevice processes ALL accumulated groups — allow up to 2 min for Welcome to arrive.
    await waitForMlsMembers(deviceAlice2, groupId, 3, 80);
    await waitForMlsMembers(deviceCharlie, groupId, 3, 80);
  } else {
    await addMemberAndWait(tauriPage, groupId, deviceAlice2);
    await waitForMlsMembers(deviceAlice2, groupId, 3);
    await waitForMlsMembers(deviceCharlie, groupId, 3);
  }
  return { groupId };
}

test.describe('federated-co-device', { tag: '@federated-co-device' }, () => {

  test('co-device + federated group message delivery — all 3 clients send and all others receive', async ({ tauriPage, deviceAlice2, deviceCharlie }) => {
    test.setTimeout(240_000);
    await waitForChatView(tauriPage, 60_000);
    await waitForChatView(deviceAlice2!, 60_000);
    await waitForChatView(deviceCharlie!, 60_000);

    const { groupId } = await createThreeWayGroup(tauriPage, deviceAlice2!, deviceCharlie!);

    await allCanSendAndReceive([tauriPage, deviceAlice2!, deviceCharlie!], groupId);
  });

  // https://github.com/swicg/activitypub-e2ee/issues/65
  // https://github.com/swicg/activitypub-e2ee/issues/80

  test('s1_alice_d2 leaves → co-device s1_alice_d1 confirms → s2_charlie_d1 updated', { tag: '@proposal' }, async ({ tauriPage, deviceAlice2, deviceCharlie }) => {
    test.setTimeout(240_000);
    await waitForChatView(tauriPage, 60_000);
    await waitForChatView(deviceAlice2!, 60_000);
    await waitForChatView(deviceCharlie!, 60_000);

    const { groupId } = await createThreeWayGroup(tauriPage, deviceAlice2!, deviceCharlie!);

    // Verify messaging works before d2 leaves.
    expect(await canSendAndReceive(tauriPage, deviceCharlie!, groupId, 10)).toBe(true);
    expect(await canSendAndReceive(deviceAlice2!, deviceCharlie!, groupId, 10)).toBe(true);

    await leaveGroup(deviceAlice2!, groupId);

    // d1 and charlie both poll:
    // d1 gets co-device dialog (leafIndex×30s), charlie gets 10min+leafIndex×2s fallback
    await Promise.all([pollInbox(tauriPage), pollInbox(deviceCharlie!)]);

    // d1 confirms — charlie's 10-min timer is still pending
    await tauriPage.waitForFunction('window.shadowQ("e2ee-chat-view >>> #nd-approve")?.textContent?.trim() === "Confirm removal"', 40_000);
    await shadowClick(tauriPage, 'e2ee-chat-view >>> #nd-approve');
    await tauriPage.waitForFunction('window.shadowQ("e2ee-chat-view >>> #nd-approve") == null', 10_000);

    // charlie polls to receive d1's Commit — its pending timer cancels
    await pollInbox(deviceCharlie!);

    // charlie: d2 removed (2 remaining: alice as d1, charlie)
    await deviceCharlie!.waitForFunction(
      `(async () => {
        const ctrl = (() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })();
        const members = await ctrl?.getGroupMembers(${JSON.stringify(groupId)}) ?? [];
        return members.length === 2;
      })()`,
      10_000
    );

    expect(await isNoLongerMember(deviceAlice2!, groupId)).toBe(true);

    // After d2 removal, d1 and charlie should still exchange messages.
    expect(await canSendAndReceive(tauriPage, deviceCharlie!, groupId, 10)).toBe(true);
  });

  test('s1_alice_d2 leaves → co-device s1_alice_d1 unresponsive → s2_charlie_d1 fallback commits after 10min', { tag: '@proposal' }, async ({ tauriPage, deviceAlice2, deviceCharlie }) => {
    test.setTimeout(180_000); // charlie fallback: 10s (debug) + leafIndex×2s + group setup overhead + 60s startup
    await waitForChatView(tauriPage, 60_000);
    await waitForChatView(deviceAlice2!, 60_000);
    await waitForChatView(deviceCharlie!, 60_000);

    const { groupId } = await createThreeWayGroup(tauriPage, deviceAlice2!, deviceCharlie!);

    expect(await canSendAndReceive(tauriPage, deviceCharlie!, groupId, 10)).toBe(true);

    await leaveGroup(deviceAlice2!, groupId);

    // Only charlie polls — d1 is unresponsive (never confirms)
    await pollInbox(deviceCharlie!);

    // charlie's fallback fires after 10min + leafIndex×2s
    // NOTE: intentionally slow — verifies the safety fallback property, not speed
    await deviceCharlie!.waitForFunction(
      `(async () => {
        const ctrl = (() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })();
        const members = await ctrl?.getGroupMembers(${JSON.stringify(groupId)}) ?? [];
        return members.length === 2;
      })()`,
      45_000
    );

    expect(await isNoLongerMember(deviceAlice2!, groupId)).toBe(true);

    // After fallback commit, charlie and d1 should still exchange messages.
    expect(await canSendAndReceive(tauriPage, deviceCharlie!, groupId, 10)).toBe(true);
  });

  // Co-device self-CC: _distributeCommit always sends to actor.id so co-devices (same actor inbox)
  // receive Commits from operations d1 performs and advance their epoch accordingly.

  test('d1 adds charlie — d2 epoch advances so d2 can still send to charlie', async ({ tauriPage, deviceAlice2, deviceCharlie }) => {
    test.setTimeout(240_000);
    await waitForChatView(tauriPage, 60_000);
    await waitForChatView(deviceAlice2!, 20_000);
    await waitForChatView(deviceCharlie!, 20_000);

    // Start with d1+d2 only (no charlie), so d2 is at the initial epoch
    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();
    await addMemberAndWait(tauriPage, groupId!, deviceAlice2!);

    const charlieId = await getActorId(deviceCharlie!);

    // d1 adds charlie — produces a Commit; _distributeCommit sends it to d2 via actor.id CC
    await tauriPage.evaluate(`(async () => {
      const ctrl = (() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })();
      await ctrl.addMemberToGroup(${JSON.stringify(groupId)}, ${JSON.stringify(charlieId)});
    })()`);

    // Wait for charlie to receive his Welcome and join
    await waitForMlsMembers(deviceCharlie!, groupId!, 3, 30);

    // d2 polls to receive the Commit — epoch must advance before d2 can encrypt for charlie
    for (let i = 0; i < 10; i++) {
      await pollInbox(deviceAlice2!);
      const count = await deviceAlice2!.evaluate(`(async () => {
        const ctrl = (() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })();
        return (await ctrl.getGroupMembers(${JSON.stringify(groupId)}) ?? []).length;
      })()`) as number;
      if (count >= 2) break; // d2 sees charlie (excludes self, so ≥2 means d1+charlie)
      await new Promise(r => setTimeout(r, 1500));
    }

    // d2 can send to charlie (proves d2's epoch matches the 3-member group state)
    expect(await canSendAndReceive(deviceAlice2!, deviceCharlie!, groupId!)).toBe(true);
  });

  test('d1 removes charlie — d2 epoch advances so d2 can still send to d1', async ({ tauriPage, deviceAlice2, deviceCharlie }) => {
    test.setTimeout(300_000);
    await waitForChatView(tauriPage, 60_000);
    await waitForChatView(deviceAlice2!, 20_000);
    await waitForChatView(deviceCharlie!, 20_000);

    // 3-way group: d1 + d2 + charlie
    const { groupId } = await createThreeWayGroup(tauriPage, deviceAlice2, deviceCharlie);
    expect(await canSendAndReceive(tauriPage, deviceCharlie!, groupId)).toBe(true);

    const charlieId = await getActorId(deviceCharlie!);

    // d1 removes charlie — produces a Commit; _distributeCommit sends it to d2 via actor.id CC
    await tauriPage.evaluate(`(async () => {
      const ctrl = (() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })();
      await ctrl.removeGroupMember(${JSON.stringify(groupId)}, ${JSON.stringify(charlieId)});
    })()`);

    // d2 polls to receive the Commit — epoch must advance before d2 can encrypt in the new state
    for (let i = 0; i < 10; i++) {
      await pollInbox(deviceAlice2!);
      const count = await deviceAlice2!.evaluate(`(async () => {
        const ctrl = (() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })();
        return (await ctrl.getGroupMembers(${JSON.stringify(groupId)}) ?? []).length;
      })()`) as number;
      if (count < 2) break; // d2 sees charlie gone (only d1 remains, excluding self)
      await new Promise(r => setTimeout(r, 1500));
    }

    // d2 can still send to d1 in the now-2-member group (proves d2's epoch advanced correctly)
    expect(await canSendAndReceive(deviceAlice2!, tauriPage, groupId)).toBe(true);
  });

});
