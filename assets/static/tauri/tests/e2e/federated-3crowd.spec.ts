// 3-crowd federated e2e tests — 2 servers, 3 actors (alice + bob + charlie).
// Devices: tauriPage = s1_alice_d1, deviceBob = s1_bob_d1, deviceCharlie = s2_charlie_d1
// Run with: just test-tauri-e2e-federated-3crowd
// Requires: E2E_S1_ALICE_LOGIN/PASSWORD, E2E_S1_BOB_LOGIN/PASSWORD, E2E_S2_CHARLIE_LOGIN/PASSWORD

import { test, expect, waitForChatView, pollInbox, createGroupAndRefresh, addMemberAndWait, leaveGroup, isNoLongerMember, getActorId, injectKeyPackageAdd, signData, getKeyPackageB64, canSendAndReceive, allCanSendAndReceive } from './helpers';

test.describe('federated-3crowd', { tag: '@federated-3crowd' }, () => {

  test('3-way group message delivery — all members send and all others receive', async ({ tauriPage, deviceBob, deviceCharlie }) => {
    test.setTimeout(180_000);
    await waitForChatView(tauriPage);
    await waitForChatView(deviceBob!, 20_000);
    await waitForChatView(deviceCharlie!, 20_000);

    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();
    await addMemberAndWait(tauriPage, groupId!, deviceCharlie!, 30);
    await addMemberAndWait(tauriPage, groupId!, deviceBob!);

    await allCanSendAndReceive([tauriPage, deviceBob!, deviceCharlie!], groupId!);
  });

  test('remove member — remaining members can still exchange messages in updated epoch', async ({ tauriPage, deviceBob, deviceCharlie }) => {
    test.setTimeout(180_000);
    await waitForChatView(tauriPage);
    await waitForChatView(deviceBob!, 20_000);
    await waitForChatView(deviceCharlie!, 20_000);

    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();
    await addMemberAndWait(tauriPage, groupId!, deviceCharlie!, 30);
    await addMemberAndWait(tauriPage, groupId!, deviceBob!);
    await allCanSendAndReceive([tauriPage, deviceBob!, deviceCharlie!], groupId!);

    const charlieId = await getActorId(deviceCharlie!);
    expect(charlieId).toBeTruthy();

    // Alice removes charlie — Commit goes to bob (epoch advances) and charlie (learns he's excluded)
    await tauriPage.evaluate(`(async () => {
      const ctrl = (() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })();
      await ctrl.removeGroupMember(${JSON.stringify(groupId)}, ${JSON.stringify(charlieId)});
    })()`);

    // Charlie polls until he sees himself removed
    for (let i = 0; i < 10; i++) {
      await pollInbox(deviceCharlie!);
      if (await isNoLongerMember(deviceCharlie!, groupId!)) break;
      await new Promise(r => setTimeout(r, 1500));
    }
    expect(await isNoLongerMember(deviceCharlie!, groupId!)).toBe(true);

    // Bob polls to receive the Commit and advance his epoch
    for (let i = 0; i < 5; i++) {
      await pollInbox(deviceBob!);
      await new Promise(r => setTimeout(r, 1000));
    }

    // Remaining members (alice + bob) can still exchange messages in the updated epoch
    expect(await canSendAndReceive(tauriPage, deviceBob!, groupId!)).toBe(true);
  });

  test('staggered commit: first committer wins, second cancels on receiving Commit', { tag: '@proposal' }, async ({ tauriPage, deviceBob, deviceCharlie }) => {
    // https://github.com/swicg/activitypub-e2ee/issues/68
    await waitForChatView(tauriPage);
    await waitForChatView(deviceBob!, 20_000);
    await waitForChatView(deviceCharlie!, 20_000);

    // alice creates group with bob (s1) and charlie (s2) as members
    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();
    await addMemberAndWait(tauriPage, groupId!, deviceCharlie!, 30); // cross-server via Oban
    await addMemberAndWait(tauriPage, groupId!, deviceBob!);

    // Verify messaging works before alice leaves.
    expect(await canSendAndReceive(tauriPage, deviceCharlie!, groupId!)).toBe(true);

    // alice leaves — distributes Proposal to bob and charlie
    await leaveGroup(tauriPage, groupId!);
    expect(await isNoLongerMember(tauriPage, groupId!)).toBe(true);

    // Both bob and charlie poll — their leafIndex×2s timers fire in order
    await Promise.all([pollInbox(deviceBob!), pollInbox(deviceCharlie!)]);

    // Poll every 1.5s so the second committer can receive the first Commit via federation
    // and cancel its own timer before it fires. A single 10s wait is too late — the 4s timer
    // fires before the federated Commit reaches the second device's inbox.
    for (let i = 0; i < 15; i++) {
      await new Promise(r => setTimeout(r, 1_500));
      await Promise.all([pollInbox(deviceBob!), pollInbox(deviceCharlie!)]);
    }

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

  test('Add signed by a different actor\'s key is rejected', { tag: '@proposal' }, async ({ tauriPage, deviceBob }) => {
    // https://github.com/swicg/activitypub-e2ee/issues/43
    await waitForChatView(tauriPage);
    await waitForChatView(deviceBob!, 20_000);

    const aliceId = await getActorId(tauriPage);
    const aliceKpB64 = await getKeyPackageB64(tauriPage, aliceId);

    // Bob signs alice's KP bytes — bob's key won't verify against alice's known MLS keys
    const bobSig = await signData(deviceBob!, aliceKpB64);

    // Inject into alice's controller: receiver tries all alice's known keys; bob's sig verifies with none
    const stored = await injectKeyPackageAdd(tauriPage, aliceId, aliceKpB64, bobSig.signature);
    expect(stored).toBe(false);
  });

});
