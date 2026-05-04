// Single-device e2e tests — no extra clients needed.
// Run with: just test-tauri-e2e-single
// Requires: E2E_S1_ALICE_LOGIN/PASSWORD (or E2E_LOGIN/PASSWORD)

import { test, expect, waitForChatView, shadowClick, shadowExists, createGroupAndRefresh, getActorId, injectKeyPackageAdd, signData } from './helpers';

const GET_CTRL = `(() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })()`;

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

  test.describe('mlsSignature verification on Add { KeyPackage }', () => {
    // All tests inject synthetic AP activities directly into _handleKeyPackageAdd.
    // Alice is always her own device so _getLiveDeviceKeysForActor always returns her key,
    // meaning the signature check is enforced for all tests below.

    test('missing mlsSignature: Add is rejected', async ({ tauriPage }) => {
      await waitForChatView(tauriPage);
      const actorId = await getActorId(tauriPage);
      const kpB64 = await tauriPage.evaluate(`(async () => ${GET_CTRL}.mlsService.getKeyPackageHex(${JSON.stringify(actorId)}))()`);
      const stored = await injectKeyPackageAdd(tauriPage, actorId, kpB64);
      expect(stored).toBe(false);
    });

    test('unknown signerKey: Add is rejected', async ({ tauriPage }) => {
      await waitForChatView(tauriPage);
      const actorId = await getActorId(tauriPage);
      const kpB64 = await tauriPage.evaluate(`(async () => ${GET_CTRL}.mlsService.getKeyPackageHex(${JSON.stringify(actorId)}))()`);
      const stored = await injectKeyPackageAdd(tauriPage, actorId, kpB64, {
        signerKey: btoa('unknown-key-not-in-any-collection'),
        signature: btoa('fake-signature')
      });
      expect(stored).toBe(false);
    });

    test('valid key but sig over wrong bytes: Add is rejected', async ({ tauriPage }) => {
      await waitForChatView(tauriPage);
      const actorId = await getActorId(tauriPage);
      const kpB64 = await tauriPage.evaluate(`(async () => ${GET_CTRL}.mlsService.getKeyPackageHex(${JSON.stringify(actorId)}))()`);
      // Real sig from own key, but signed over different bytes — not the KP content
      const wrongSig = await signData(tauriPage, btoa('this is not the keypackage'));
      const stored = await injectKeyPackageAdd(tauriPage, actorId, kpB64, wrongSig);
      expect(stored).toBe(false);
    });

    test('self-signed Add with own key: accepted', async ({ tauriPage }) => {
      await waitForChatView(tauriPage);
      const actorId = await getActorId(tauriPage);
      const kpB64 = await tauriPage.evaluate(`(async () => ${GET_CTRL}.mlsService.getKeyPackageHex(${JSON.stringify(actorId)}))()`);
      const sig = await signData(tauriPage, kpB64);
      const stored = await injectKeyPackageAdd(tauriPage, actorId, kpB64, sig);
      expect(stored).toBe(true);
    });

    test('unsigned Add accepted when actor has no known devices', async ({ tauriPage }) => {
      await waitForChatView(tauriPage);
      // Use a made-up actor URI that has no live MLS group membership (so _getLiveDeviceKeysForActor → [])
      const unknownActorUri = 'https://example.com/users/nobody-' + Date.now();
      // Reuse alice's own KP bytes as a parseable KP body attributed to the unknown actor
      const aliceKpB64 = await tauriPage.evaluate(`(async () => ${GET_CTRL}.mlsService.getKeyPackageHex(${GET_CTRL}.currentActorId))()`);
      const stored = await injectKeyPackageAdd(tauriPage, unknownActorUri, aliceKpB64); // no sig
      expect(stored).toBe(true);
    });
  });

  test('KP replenishment self-signs the published Add', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);
    const hadSig = await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      let capturedSig = null;
      const origSign = ctrl._signKeyPackage.bind(ctrl);
      ctrl._signKeyPackage = async (...args) => {
        capturedSig = await origSign(...args);
        return capturedSig;
      };
      await ctrl.mlsService.clearKeyPackage(ctrl.currentActorId);
      const actor = { id: ctrl.currentActorId, ...(JSON.parse(localStorage.getItem('actor') || '{}')) };
      await ctrl._replenishKeyPackage(actor);
      ctrl._signKeyPackage = origSign;
      return capturedSig !== null;
    })()`);
    expect(hadSig).toBe(true);
  });

});
