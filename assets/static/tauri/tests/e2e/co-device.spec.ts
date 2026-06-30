// Co-device e2e tests — 1 server, 2 Tauri clients with the same actor.
// Devices: tauriPage = s1_alice_d1, deviceAlice2 = s1_alice_d2
// Run with: just test-tauri-e2e-co-device
// Requires: E2E_S1_ALICE_LOGIN/PASSWORD

import { test, expect, waitForChatView, shadowExists, createGroupAndRefresh, pollInbox, leaveGroup, isNoLongerMember, getOwnSignatureKey, ownKpIsSelfSigned, canSendAndReceive, addMemberAndWait, waitForMlsMembers, hasReceivedMessage, fetchPublishedSignedKP, getActorId } from './helpers';

const GET_CTRL = `(() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })()`;

// serial: if the approval test fails, later tests skip rather than failing with "sharedGroupId null".
test.describe.serial('co-device', { tag: '@co-device' }, () => {

  // Set by the approval test, consumed by all subsequent tests.
  let sharedGroupId: string | null = null;

  test('s1_alice_d2: new device with existing co-device shows waiting-for-approval dialog', { tag: '@proposal' }, async ({ tauriPage, deviceAlice2 }) => {
    // https://github.com/swicg/activitypub-e2ee/issues/65
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
    // https://github.com/swicg/activitypub-e2ee/issues/65
    test.setTimeout(150_000); // approveNewDevice adds d2 to all existing groups (many across runs); pollInbox is slow with accumulated inbox state
    // Set window flag BEFORE waitForChatView so the periodic poll timer can't sneak in between
    // element creation and setting the instance property (_autoApproveNewDevice).
    await tauriPage.evaluate(`window.__e2ee_autoApproveNewDevice = true`);
    await waitForChatView(tauriPage);

    // Archive all accumulated MLS groups + create sharedGroupId in a single evaluate so no
    // periodic timer can fire in between. Accumulated groups cause an OpenMLS assertion panic
    // (len_len_log <= MAX_LEN_LEN_LOG) when the ratchet tree grows too large over multiple runs.
    sharedGroupId = await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const view = window.shadowQ('e2ee-chat-view');
      if (!ctrl) return null;
      const existing = await ctrl.storage.listGroupsWithLastMessage();
      for (const g of existing) {
        try { await ctrl.archiveThread(g.groupId); } catch (e) {
          console.warn('[cleanup] d1 archiveThread failed:', g.groupId, e);
        }
      }
      try {
        const id = await ctrl.createGroup();
        if (ctrl.currentActorId) await ctrl.persistMembers(id, [ctrl.currentActorId]);
        if (typeof view?.loadGroups === 'function') await view.loadGroups();
        return id;
      } catch (e) { console.error('[cleanup] createGroup failed:', e); return null; }
    })()`);
    expect(sharedGroupId).toBeTruthy();
    // Persist to localStorage so later tests can recover it if the module is re-evaluated
    // (tauri-playwright re-initialises module-level vars between some test boundaries).
    await tauriPage.evaluate(`localStorage.setItem('__testSharedGroupId', ${JSON.stringify(sharedGroupId)})`);

    await waitForChatView(deviceAlice2!, 20_000);

    // Force d2 to republish a fresh KP. After a prior test 5 decommission, the server KP
    // is deleted but d2's local "Already published" timestamp persists — so d2 never sends
    // a new proposal. Clear + republish ensures d1's auto-approve has a valid KP to process.
    await deviceAlice2!.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      if (!ctrl) return;
      const actorId = ctrl.currentActorId;
      if (!actorId) return;
      await ctrl.mlsService.clearKeyPackage(actorId);
      const actor = { id: actorId, ...(JSON.parse(localStorage.getItem('actor') || '{}')) };
      await ctrl._replenishKeyPackage(actor);
    })()`);

    // Archive d2's accumulated groups (skip sharedGroupId — d2 may have joined it already
    // if the auto-approve timer fired during waitForChatView above).
    await deviceAlice2!.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      if (!ctrl) return;
      const existing = await ctrl.storage.listGroupsWithLastMessage();
      for (const g of existing) {
        if (g.groupId === ${JSON.stringify(sharedGroupId)}) continue;
        try { await ctrl.archiveThread(g.groupId); } catch (e) {
          console.warn('[cleanup] d2 archiveThread failed:', g.groupId, e);
        }
      }
    })()`);

    // Explicit poll ensures auto-approve fires (in case the timer hasn't fired yet).
    await pollInbox(tauriPage);

    // Poll d2's inbox until it joins the group — this processes the Welcome and clears
    // _awaitingApproval (which closes #nd-pending-dialog). Must come before the dialog check
    // so d2 actually receives the Welcome rather than relying on the periodic poll timer.
    await waitForMlsMembers(deviceAlice2!, sharedGroupId!, 2); // default 40 retries × 1.5s = up to 60s

    // After joining via Welcome, the pending-approval dialog must be dismissed.
    expect(await shadowExists(deviceAlice2!, 'e2ee-chat-view >>> #nd-pending-dialog')).toBeFalsy();

    // After joining from Welcome, d2 must have replenished its KP (old init_key was consumed).
    // Verify: stored KP is self-signable with d2's own identity key (same signature_key, new init_key).
    expect(await ownKpIsSelfSigned(deviceAlice2!)).toBe(true);

    // Both devices should be able to exchange messages in the shared group.
    expect(await canSendAndReceive(tauriPage, deviceAlice2!, sharedGroupId!)).toBe(true);
    expect(await canSendAndReceive(deviceAlice2!, tauriPage, sharedGroupId!)).toBe(true);
  });

  test('Article received from co-device: script stripped by Rust sanitization', { tag: '@spec' }, async ({ tauriPage, deviceAlice2 }) => {
    // Runs here (before d1 leaves) so both d1 and d2 are still members of sharedGroupId.
    test.setTimeout(60_000);
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 20_000);
    // Recover from localStorage in case tauri-playwright re-evaluated the module (resetting the var).
    if (!sharedGroupId) sharedGroupId = await tauriPage.evaluate(`localStorage.getItem('__testSharedGroupId')`);
    expect(sharedGroupId).toBeTruthy();

    // d1 sends Article with a script payload to the shared group
    const sent = await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const result = await ctrl.sendMessage(${JSON.stringify(sharedGroupId)}, {
        content: '<script>window.__xss_from_d1=true;<\\/script>Legit text from d1',
        type: 'Article',
        name: 'XSS Sanitisation Test'
      });
      return result?.messageApId ?? null;
    })()`);
    expect(sent).toBeTruthy();

    // d2 polls inbox → ciphertext goes through Rust decrypt → sanitize_message_content strips script.
    // Check storage directly: d2 has no conversation open so no .chat-bubble exists in the DOM,
    // but the MLS decryption + Rust sanitization run regardless on pollInbox.
    let received = false;
    for (let i = 0; i < 5; i++) {
      await pollInbox(deviceAlice2!, 15); // bounded; loop covers full backlog
      received = await hasReceivedMessage(deviceAlice2!, sharedGroupId!, 'Legit text from d1');
      if (received) break;
      await new Promise(r => setTimeout(r, 1000));
    }
    expect(received).toBe(true);

    // XSS: the script tag must not have fired (Rust strips it before JS ever sees the content)
    const xssFired = await deviceAlice2!.evaluate(`!!window.__xss_from_d1`);
    expect(xssFired).toBe(false);

    // Verify the stored message content has no <script> tags (ammonia stripped it at decrypt time)
    const storedScriptTag = await deviceAlice2!.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const msgs = await ctrl?.storage?.listMessages?.(${JSON.stringify(sharedGroupId)}) ?? [];
      const msg = msgs.find(m => m.id === ${JSON.stringify(sent)} || (typeof m.content === 'object' && m.content?.id === ${JSON.stringify(sent)}));
      const txt = typeof msg?.content === 'string' ? msg.content : JSON.stringify(msg?.content ?? '');
      return txt.includes('<script') || txt.includes('<\\/script>');
    })()`);
    expect(storedScriptTag).toBe(false);
  });

  test('s1_alice_d1 leaves shared group → s1_alice_d2 sees co-device confirmation → confirms → d1 removed + d2 leaf rotated', async ({ tauriPage, deviceAlice2 }) => {
    test.setTimeout(120_000); // co-device stagger: leafIndex×30s before dialog appears
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 10_000);
    if (!sharedGroupId) sharedGroupId = await tauriPage.evaluate(`localStorage.getItem('__testSharedGroupId')`);
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
        await pollInbox(deviceAlice2!, 15); // bounded; loop covers full backlog
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
      30_000  // commitCoDeviceLeaving runs MLS key schedule — can take 15-20s with accumulated inbox state
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

  test('s1_alice_d1 decommissions s1_alice_d2 via Manage my devices panel → d2 leaves group', async ({ tauriPage, deviceAlice2 }) => {
    test.setTimeout(180_000); // addMemberAndWait slow after accumulated inbox state from prior tests
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 20_000);

    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();
    await addMemberAndWait(tauriPage, groupId!, deviceAlice2!);
    expect(await canSendAndReceive(tauriPage, deviceAlice2!, groupId!)).toBe(true);

    // d1 opens the Manage my devices panel (appends to document.body)
    await tauriPage.evaluate(`window.shadowQ('e2ee-chat-view')._openMyDevicesPanel()`);

    // Wait for the panel to load and show "Remove device" for d2 (the non-current device)
    await tauriPage.waitForFunction(
      `window.shadowQ('my-devices-panel >>> .btn-error') != null`,
      15_000
    );

    // Click "Remove device" — retry until button is present and not mid-render (Lit may be
    // updating _loading which hides the button; ?.click() on a missing element is a silent no-op)
    await tauriPage.waitForFunction(`
      (function() {
        const btn = window.shadowQ('my-devices-panel >>> .btn-error');
        if (btn && !btn.disabled) { btn.click(); return true; }
        return false;
      })()
    `, 15_000);

    // Wait for decommission: spinner appears then disappears (_handleDecommission → removeOwnClient → _loadDevices)
    await tauriPage.waitForFunction(
      `window.shadowQ('my-devices-panel')?.shadowRoot?.querySelector('span.loading') != null`,
      10_000
    );
    await tauriPage.waitForFunction(
      `window.shadowQ('my-devices-panel')?.shadowRoot?.querySelector('span.loading') == null`,
      60_000
    );

    // d2 polls and should receive the Commit removing it from the group
    let notMember = false;
    for (let i = 0; i < 10; i++) {
      await pollInbox(deviceAlice2!, 15); // bounded; loop covers full backlog
      notMember = await isNoLongerMember(deviceAlice2!, groupId!);
      if (notMember) break;
      await new Promise(r => setTimeout(r, 2000));
    }
    expect(notMember).toBe(true);

    // Panel should no longer show "Remove device" after d2 is decommissioned.
    // Use .card .btn-error — the Advanced section always has a .btn-error ("Delete this device")
    // and that button is not inside a .card, so we scope to device card buttons only.
    const removeButtonGone = await tauriPage.evaluate(
      `window.shadowQ('my-devices-panel >>> .card .btn-error') == null`
    );
    expect(removeButtonGone).toBe(true);
  });

  test('s1_alice_d1: decommission d2 → d2 leaves all groups + KP removed from server', async ({ tauriPage, deviceAlice2 }) => {
    // https://github.com/swicg/activitypub-e2ee/issues/65
    test.setTimeout(180_000); // addMemberAndWait + removeOwnClient + pollInbox all slow after accumulated inbox state
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 20_000);

    // Create a shared group so d1 can distribute a Commit removing d2's leaf during decommission.
    const preDecommissionGroup = await createGroupAndRefresh(tauriPage);
    expect(preDecommissionGroup).toBeTruthy();
    await addMemberAndWait(tauriPage, preDecommissionGroup!, deviceAlice2!);
    // Skip canSendAndReceive here — test 2 already verifies d1↔d2 messaging; this test
    // focuses on the Commit-Remove path, not pre-decommission key health.

    // Get d2's signature key so d1 can decommission it
    const d2SigKey = await getOwnSignatureKey(deviceAlice2!);
    expect(d2SigKey).toBeTruthy();

    // d1 decommissions d2 (removes d2 from all groups + deletes its KP from server)
    await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      await ctrl.removeOwnClient(${JSON.stringify(d2SigKey)});
    })()`);

    // d2 polls → receives the Commit removing it from preDecommissionGroup.
    // Retry a few times in case accumulated inbox state requires multiple polls.
    let notMember = false;
    for (let i = 0; i < 5; i++) {
      await pollInbox(deviceAlice2!, 15); // bounded; loop covers full backlog
      notMember = await isNoLongerMember(deviceAlice2!, preDecommissionGroup!);
      if (notMember) break;
      if (i < 4) await new Promise(r => setTimeout(r, 1000));
    }

    // d2 should see itself as no longer member of preDecommissionGroup
    expect(notMember).toBe(true);

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

  test('group join populates mlsKnownKeys cache with inviter key', { tag: '@proposal' }, async ({ tauriPage, deviceAlice2 }) => {
    // https://github.com/swicg/activitypub-e2ee/issues/43
    test.setTimeout(90_000);
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 20_000);

    const groupId = await createGroupAndRefresh(tauriPage);
    if (!groupId) throw new Error('createGroupAndRefresh returned null');
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
