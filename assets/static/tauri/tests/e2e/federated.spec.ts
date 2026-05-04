// Federated e2e tests — 2 servers, 3 Tauri clients (different actors).
// Devices: tauriPage = s1_alice_d1, deviceBob = s1_bob_d1, deviceCharlie = s2_charlie_d1
// Run with: just test-tauri-e2e-federated
// Requires: E2E_S1_ALICE_LOGIN/PASSWORD, E2E_S1_BOB_LOGIN/PASSWORD, E2E_S2_CHARLIE_LOGIN/PASSWORD

import { test, expect, waitForChatView, pollInbox, createGroupAndRefresh, addMemberAndWait, leaveGroup, isNoLongerMember, getActorId, injectKeyPackageAdd, signData, getKeyPackageB64, canSendAndReceive } from './helpers';

test.describe('federated', { tag: '@federated' }, () => {

  test('cross-server message delivery', async ({ tauriPage, deviceCharlie }) => {
    await waitForChatView(tauriPage);
    await waitForChatView(deviceCharlie!, 20_000);

    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();
    await addMemberAndWait(tauriPage, groupId!, deviceCharlie!);

    expect(await canSendAndReceive(tauriPage, deviceCharlie!, groupId!)).toBe(true);
    expect(await canSendAndReceive(deviceCharlie!, tauriPage, groupId!)).toBe(true);
  });

  test('staggered commit: first committer wins, second cancels on receiving Commit', async ({ tauriPage, deviceBob, deviceCharlie }) => {
    await waitForChatView(tauriPage);
    await waitForChatView(deviceBob!, 20_000);
    await waitForChatView(deviceCharlie!, 20_000);

    // alice creates group with bob (s1) and charlie (s2) as members
    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();
    await addMemberAndWait(tauriPage, groupId!, deviceCharlie!);
    await addMemberAndWait(tauriPage, groupId!, deviceBob!);

    // Verify messaging works before alice leaves.
    expect(await canSendAndReceive(tauriPage, deviceCharlie!, groupId!)).toBe(true);

    // alice leaves — distributes Proposal to bob and charlie
    await leaveGroup(tauriPage, groupId!);
    expect(await isNoLongerMember(tauriPage, groupId!)).toBe(true);

    // Both bob and charlie poll — their leafIndex×2s timers fire in order
    await Promise.all([pollInbox(deviceBob!), pollInbox(deviceCharlie!)]);

    // Wait for the first committer's timer to fire (leafIndex×2s, max ~10s for small groups),
    // then poll again so the second device receives the winning Commit and cancels its timer
    await new Promise(r => setTimeout(r, 10_000));
    await Promise.all([pollInbox(deviceBob!), pollInbox(deviceCharlie!)]);

    // Both end up with alice removed (2 remaining members: bob + charlie)
    for (const device of [deviceBob!, deviceCharlie!]) {
      await device.waitForFunction(
        `(async () => {
          const ctrl = (() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })();
          const members = await ctrl?.getGroupMembers(${JSON.stringify(groupId)}) ?? [];
          return members.length === 2;
        })()`,
        15_000
      );
    }

    // After alice's removal is committed, bob and charlie should still exchange messages.
    expect(await canSendAndReceive(deviceBob!, deviceCharlie!, groupId!)).toBe(true);
  });

  test('Add signed by a different actor\'s key is rejected', async ({ tauriPage, deviceBob }) => {
    await waitForChatView(tauriPage);
    await waitForChatView(deviceBob!, 20_000);

    const aliceId = await getActorId(tauriPage);
    const aliceKpB64 = await getKeyPackageB64(tauriPage, aliceId);

    // Bob signs alice's KP bytes — bob's signature key is not in alice's known device keys
    const bobSig = await signData(deviceBob!, aliceKpB64);

    // Inject into alice's controller: should be rejected because bobSig.signerKey ∉ alice's validSigners
    const stored = await injectKeyPackageAdd(tauriPage, aliceId, aliceKpB64, bobSig);
    expect(stored).toBe(false);
  });

});
