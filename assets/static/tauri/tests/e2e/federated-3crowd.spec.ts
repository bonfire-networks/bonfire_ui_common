// 3-crowd federated e2e tests — 2 servers, 3 actors (alice + bob + charlie).
// Devices: tauriPage = s1_alice_d1, deviceBob = s1_bob_d1, deviceCharlie = s2_charlie_d1
// Run with: just test-tauri-e2e-federated-3crowd
// Requires: E2E_S1_ALICE_LOGIN/PASSWORD, E2E_S1_BOB_LOGIN/PASSWORD, E2E_S2_CHARLIE_LOGIN/PASSWORD

import { test, expect, waitForChatView, pollInbox, createGroupAndRefresh, addMemberAndWait, leaveGroup, isNoLongerMember, getActorId, injectKeyPackageAdd, signData, getKeyPackageB64, canSendAndReceive, allCanSendAndReceive, getGroupMemberCount } from './helpers';

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

    // Extra retries: cross-server (s2→s1) messages may reach s1 recipients in separate
    // Oban sub-jobs; the second sub-job can lag behind the first under inline scheduling.
    await allCanSendAndReceive([tauriPage, deviceBob!, deviceCharlie!], groupId!, 20);
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

  test('duplicate proposal: second identical Remove proposal is ignored', { tag: '@proposal' }, async ({ tauriPage, deviceBob, deviceCharlie }) => {
    // RFC 9420 §12: duplicate Proposals must be deduplicated — only one Commit should be made.
    // Dedup guard: _handleProposal returns null immediately if _pendingProposalTimers already has an entry.
    //
    // Setup: alice creates group, adds BOB first (leafIndex 1 → 2s timer), then charlie (leafIndex 2).
    // alice leaves → self-remove Proposal goes to bob (s1, same-server = instant) and charlie (s2).
    // Spy on bob's _handleProposal: captures the proposal, sets timer (2s), then inject duplicate.
    // Duplicate must return null (dedup guard fires). timerCount stays 1.
    // Bob's 2s timer fires → bob commits. Charlie deliberately not polled until after bob commits
    // so charlie's inbox has [alice_proposal, bob_commit] in the same poll — epoch advances first,
    // then the stale proposal is rejected by OpenMLS (wrong epoch) → no second commit timer on charlie.
    test.setTimeout(180_000);
    await waitForChatView(tauriPage);
    await waitForChatView(deviceBob!, 20_000);
    await waitForChatView(deviceCharlie!, 20_000);

    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();
    // Add bob FIRST so he gets leafIndex 1 (timer = 1 × 2s = 2s) — enough headroom to inject the duplicate.
    await addMemberAndWait(tauriPage, groupId!, deviceBob!);
    await addMemberAndWait(tauriPage, groupId!, deviceCharlie!, 30);

    // alice leaves — distributes a self-remove Proposal to [bob, charlie].
    // Bob (s1) receives it same-server (fast). Charlie (s2) will receive it later via Oban.
    await leaveGroup(tauriPage, groupId!);
    expect(await isNoLongerMember(tauriPage, groupId!)).toBe(true);

    // Spy on bob's _handleProposal to capture the first call's arguments
    await deviceBob!.evaluate(`(async () => {
      const ctrl = (() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })();
      window._bonfireTestProposalCapture = null;
      window._bonfireTestOrigHandleProposal = ctrl._handleProposal.bind(ctrl);
      ctrl._handleProposal = async (gId, parsed, actor, alreadyDecrypted) => {
        if (!window._bonfireTestProposalCapture) {
          window._bonfireTestProposalCapture = { gId, parsed, actor };
        }
        return window._bonfireTestOrigHandleProposal(gId, parsed, actor, alreadyDecrypted);
      };
    })()`);

    // bob polls — same-server delivery means alice's Proposal arrives in the first few polls
    for (let i = 0; i < 10; i++) {
      await pollInbox(deviceBob!);
      const captured = await deviceBob!.evaluate('!!window._bonfireTestProposalCapture');
      if (captured) break;
      await new Promise(r => setTimeout(r, 1_000));
    }

    // Restore original and inject duplicate (alreadyDecrypted=true skips Rust decrypt).
    // Must run before bob's 2s timer fires — the direct evaluate runs in <100ms.
    const dupResult: { captured: boolean, result: string, timerCount: number } = await deviceBob!.evaluate(`(async () => {
      const ctrl = (() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })();
      if (window._bonfireTestOrigHandleProposal) ctrl._handleProposal = window._bonfireTestOrigHandleProposal;
      const cap = window._bonfireTestProposalCapture;
      if (!cap) return { captured: false, result: 'no-capture', timerCount: ctrl._pendingProposalTimers.size };
      const result = await ctrl._handleProposal(cap.gId, cap.parsed, cap.actor, true);
      return { captured: true, result: result === null ? 'null' : String(result), timerCount: ctrl._pendingProposalTimers.size };
    })()`);

    expect(dupResult.captured).toBe(true);
    expect(dupResult.result).toBe('null');      // duplicate was silently dropped
    expect(dupResult.timerCount).toBe(1);       // still exactly one pending commit timer

    // Poll only bob for 15s — bob's 2s timer fires, commits alice's removal,
    // and distributes the Commit to charlie. Don't poll charlie yet.
    for (let i = 0; i < 15; i++) {
      await new Promise(r => setTimeout(r, 1_000));
      await pollInbox(deviceBob!);
    }

    // Now let charlie catch up. Charlie's inbox has both alice's Proposal and bob's Commit.
    // Newest-first ordering means bob's Commit is processed first → epoch advances (alice removed)
    // → alice's stale Proposal fails OpenMLS decrypt (wrong epoch) → no commit timer on charlie.
    for (let i = 0; i < 30; i++) {
      await new Promise(r => setTimeout(r, 1_500));
      await pollInbox(deviceCharlie!);
      if (await getGroupMemberCount(deviceCharlie!, groupId!) === 2) break;
    }

    // Two members remain (alice removed), bob and charlie can still exchange messages
    expect(await getGroupMemberCount(deviceBob!, groupId!)).toBe(2);
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
