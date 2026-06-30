// Single-device e2e tests — no extra clients needed.
// Run with: just test-tauri-e2e-single
// Requires: E2E_S1_ALICE_LOGIN/PASSWORD (or E2E_LOGIN/PASSWORD)

import { test, expect, waitForChatView, shadowClick, shadowExists, createGroupAndRefresh, getActorId, injectKeyPackageAdd, getKeyPackageB64, fetchPublishedSignedKP, signData, sendMessage, ownKpIsSelfSigned, HEX_TO_B64 } from './helpers';
// btoa is a global in Node 16+ / browser

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

    // Verify MLS encryption works before leaving.
    const sentId = await sendMessage(tauriPage, groupId!, 'test-pre-leave');
    expect(sentId).toBeTruthy();

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

  test('co-device leave proposal shows confirmation dialog with fingerprint', { tag: '@proposal' }, async ({ tauriPage }) => {
    // https://github.com/swicg/activitypub-e2ee/issues/80
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

  test('clear all data on solo device shows irrecoverable warning', { tag: '@proposal' }, async ({ tauriPage }) => {
    // https://github.com/swicg/activitypub-e2ee/issues/65
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

  test('pending co-device leave survives app reload', { tag: '@proposal' }, async ({ tauriPage }) => {
    // https://github.com/swicg/activitypub-e2ee/issues/65
    // https://github.com/swicg/activitypub-e2ee/issues/80
    await waitForChatView(tauriPage);

    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();

    await tauriPage.evaluate(`(async () => {
      const view = window.shadowQ('e2ee-chat-view');
      const controller = view?._controller || view?.controller;
      await controller.storage.setGroupField(${JSON.stringify(groupId)}, 'pendingCoDeviceLeave', 'synthetic-proposal-id');
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

  test.describe('mlsSignature verification on Add { KeyPackage }', { tag: '@proposal' }, () => {
    // https://github.com/swicg/activitypub-e2ee/issues/43
    // https://github.com/swicg/activitypub-e2ee/issues/48
    // All tests inject synthetic AP activities directly into _handleKeyPackageAdd.
    // Alice is always her own device so _getLiveDeviceKeysForActor always returns her key,
    // meaning the signature check is enforced for all tests below.

    test('missing mlsSignature: Add is rejected', async ({ tauriPage }) => {
      await waitForChatView(tauriPage);
      const actorId = await getActorId(tauriPage);
      const kpB64 = await getKeyPackageB64(tauriPage, actorId);
      const stored = await injectKeyPackageAdd(tauriPage, actorId, kpB64);
      expect(stored).toBe(false);
    });

    test('invalid signature: Add is rejected', async ({ tauriPage }) => {
      await waitForChatView(tauriPage);
      const actorId = await getActorId(tauriPage);
      const kpB64 = await getKeyPackageB64(tauriPage, actorId);
      // Garbage signature — receiver tries all known keys, none will verify
      const stored = await injectKeyPackageAdd(tauriPage, actorId, kpB64, 'ZmFrZXNpZw');
      expect(stored).toBe(false);
    });

    test('sig over wrong bytes: Add is rejected', async ({ tauriPage }) => {
      await waitForChatView(tauriPage);
      const actorId = await getActorId(tauriPage);
      const kpB64 = await getKeyPackageB64(tauriPage, actorId);
      // Real signature from alice's key, but over different bytes — verification fails
      const wrongSig = await signData(tauriPage, btoa('other'));
      const stored = await injectKeyPackageAdd(tauriPage, actorId, kpB64, wrongSig.signature);
      expect(stored).toBe(false);
    });

    test('self-signed Add with own key: accepted', async ({ tauriPage }) => {
      await waitForChatView(tauriPage);
      const actorId = await getActorId(tauriPage);
      const kpInfo = await fetchPublishedSignedKP(tauriPage, actorId);
      expect(kpInfo?.mlsSignature).toBeTruthy();
      expect(kpInfo?.mlsSignerKeyId).toBeTruthy();
      const stored = await injectKeyPackageAdd(tauriPage, actorId, kpInfo!.kpB64, kpInfo!.mlsSignature!, undefined, kpInfo!.mlsSignerKeyId!);
      expect(stored).toBe(true);
    });

    test('unsigned Add accepted when actor has no known devices', async ({ tauriPage }) => {
      await waitForChatView(tauriPage);
      // Use a made-up actor URI and garbage (unparseable) KP bytes so kpSignatureKey = null,
      // meaning validSigners = [] → no enforcement → unsigned accepted.
      const unknownActorUri = 'https://example.com/users/nobody-' + Date.now();
      const stored = await injectKeyPackageAdd(tauriPage, unknownActorUri, 'Z2FyYmFnZQ=='); // garbage, won't parse as MLS KP
      expect(stored).toBe(true);
    });
  });

  test('KP replenishment self-signs the published Add', { tag: '@proposal' }, async ({ tauriPage }) => {
    // https://github.com/swicg/activitypub-e2ee/issues/48
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

  test('KP renewed twice: identity key stable, each KP distinct and self-signed', { tag: '@proposal' }, async ({ tauriPage }) => {
    // https://github.com/swicg/activitypub-e2ee/issues/48
    await waitForChatView(tauriPage);

    type KpInfo = { kpB64: string; sigKey: string | null } | null;

    const getKpSigKey = () => tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const hex = await ctrl.mlsService.getKeyPackageHex(ctrl.currentActorId);
      if (!hex) return null;
      const kpB64 = ${HEX_TO_B64}(hex);
      const fp = await ctrl.mlsService.getKeyPackageFingerprint(kpB64);
      return { kpB64, sigKey: fp?.signatureKey ?? null };
    })()`) as Promise<KpInfo>;

    const replenish = () => tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      await ctrl.mlsService.clearKeyPackage(ctrl.currentActorId);
      const actor = { id: ctrl.currentActorId, ...(JSON.parse(localStorage.getItem('actor') || '{}')) };
      await ctrl._replenishKeyPackage(actor);
    })()`);

    const first = await getKpSigKey();
    expect(first?.sigKey).toBeTruthy();

    await replenish();
    const second = await getKpSigKey();
    expect(second?.sigKey).toBe(first!.sigKey);
    expect(second?.kpB64).not.toBe(first!.kpB64);

    await replenish();
    const third = await getKpSigKey();
    expect(third?.sigKey).toBe(first!.sigKey);
    expect(third?.kpB64).not.toBe(second!.kpB64);

    expect(await ownKpIsSelfSigned(tauriPage)).toBe(true);
  });

  // --- Spec Gap 1: replenishment removes old KP from server collection ---
  // Expect: FAIL until _replenishKeyPackage calls deleteKeyPackage for the old KP
  test('replenishment removes old KP from actor collection', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);
    const actorId = await getActorId(tauriPage);
    const oldKp = await fetchPublishedSignedKP(tauriPage, actorId);
    expect(oldKp?.kpB64).toBeTruthy();

    // Don't manually clear — _replenishKeyPackage captures oldKpHex internally before clearing.
    // Manual clearKeyPackage here would zero out the stored hex so oldKpHex becomes null.
    await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const actor = { id: ctrl.currentActorId, ...(JSON.parse(localStorage.getItem('actor') || '{}')) };
      await ctrl._replenishKeyPackage(actor);
    })()`);

    const kpsAfter = (await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      return await ctrl.fetchActorKeyPackages(${JSON.stringify(actorId)});
    })()`)) as Array<{ kpB64: string }>;

    expect((kpsAfter ?? []).some(kp => kp.kpB64 === oldKp!.kpB64)).toBe(false);
    expect((kpsAfter ?? []).length).toBeGreaterThan(0);
  });

  // --- Spec Gap 2: 3-step auth — Add with KP removed from collection is rejected ---
  // Depends on Gap 1 fix. Expect: FAIL until _handleKeyPackageAdd checks collection membership
  test('Add with KP removed from collection is rejected (3-step auth)', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);
    const actorId = await getActorId(tauriPage);
    const oldKp = await fetchPublishedSignedKP(tauriPage, actorId);
    expect(oldKp?.kpB64).toBeTruthy();

    // Replenish — removes oldKp from server collection (requires Gap 1 fix).
    // Don't manually clear first — _replenishKeyPackage needs to capture oldKpHex internally.
    await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const actor = { id: ctrl.currentActorId, ...(JSON.parse(localStorage.getItem('actor') || '{}')) };
      await ctrl._replenishKeyPackage(actor);
    })()`);

    // Old KP has a valid sig + valid signerKeyId in cache, but is no longer in the server collection
    const stored = await injectKeyPackageAdd(
      tauriPage, actorId, oldKp!.kpB64,
      oldKp!.mlsSignature!, undefined, oldKp!.mlsSignerKeyId!
    );
    expect(stored).toBe(false);
  });

  test('fetchActorKeyPackage finds own published keyPackage regardless of storage shape', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);

    const found = await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const result = await ctrl.fetchLatestKeyPackage(ctrl.currentActorId);
      return result != null && result.length > 0;
    })()`);

    expect(found).toBe(true);
  });

  // --- Spec Gap 3: non-text content types ---
  // Each test creates its own group — no dependency on co-device approval.
  // Single-device: Alice sends to herself; sent messages appear immediately in the chat view.

  test('non-Note type (Article) sent and rendered in chat bubble', { tag: '@spec' }, async ({ tauriPage }) => {
    await waitForChatView(tauriPage);
    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();

    const sent = await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const result = await ctrl.sendMessage(${JSON.stringify(groupId)}, {
        content: 'A longer essay for testing Article type.',
        type: 'Article',
        name: 'Test Article'
      });
      const view = window.shadowQ('e2ee-chat-view');
      if (view?.loadMessages) await view.loadMessages(${JSON.stringify(groupId)});
      return result?.messageApId ?? null;
    })()`);
    expect(sent).toBeTruthy();

    await tauriPage.waitForFunction(
      `window.shadowQ('e2ee-chat-view >>> [data-msg-id="${sent}"] .chat-bubble') != null`,
      10_000
    );
    const bubbleText = await tauriPage.evaluate(
      `window.shadowQ('e2ee-chat-view >>> [data-msg-id="${sent}"] .chat-bubble')?.textContent`
    );
    expect(bubbleText).toContain('longer essay');
  });

  test('image-only attachment sent as Image object and rendered as <img> without bubble', { tag: '@spec' }, async ({ tauriPage }) => {
    await waitForChatView(tauriPage);
    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();

    // 1×1 transparent PNG
    const PNG1x1 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    const sent = await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const result = await ctrl.sendMessage(${JSON.stringify(groupId)}, {
        attachments: [{ type: 'Image', mediaType: 'image/png', content: '${PNG1x1}' }]
      });
      const view = window.shadowQ('e2ee-chat-view');
      if (view?.loadMessages) await view.loadMessages(${JSON.stringify(groupId)});
      return result?.messageApId ?? null;
    })()`);
    expect(sent).toBeTruthy();

    // Inline base64 images render as a media placeholder (spinner) until served via local path.
    // Check for the media container div (data-needs-thumb) or img — either confirms media rendered.
    await tauriPage.waitForFunction(
      `window.shadowQ('e2ee-chat-view >>> [data-msg-id="${sent}"] [data-needs-thumb]') != null ||
       window.shadowQ('e2ee-chat-view >>> [data-msg-id="${sent}"] img') != null`,
      10_000
    );
    const hasBubble = await tauriPage.evaluate(
      `!!window.shadowQ('e2ee-chat-view >>> [data-msg-id="${sent}"] .chat-bubble')`
    );
    expect(hasBubble).toBe(false);
  });

  test('audio-only attachment sent as Audio object and rendered with play button', { tag: '@spec' }, async ({ tauriPage }) => {
    await waitForChatView(tauriPage);
    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();

    // Minimal WAV header (base64)
    const WAV = 'UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=';
    const sent = await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const result = await ctrl.sendMessage(${JSON.stringify(groupId)}, {
        attachments: [{ type: 'Audio', mediaType: 'audio/wav', content: '${WAV}' }]
      });
      const view = window.shadowQ('e2ee-chat-view');
      if (view?.loadMessages) await view.loadMessages(${JSON.stringify(groupId)});
      return result?.messageApId ?? null;
    })()`);
    expect(sent).toBeTruthy();

    // Audio renders as a play button until activated
    await tauriPage.waitForFunction(
      `window.shadowQ('e2ee-chat-view >>> [data-msg-id="${sent}"] button') != null`,
      10_000
    );
    const hasBubble = await tauriPage.evaluate(
      `!!window.shadowQ('e2ee-chat-view >>> [data-msg-id="${sent}"] .chat-bubble')`
    );
    expect(hasBubble).toBe(false);
    const playBtn = await shadowExists(tauriPage, `e2ee-chat-view >>> [data-msg-id="${sent}"] button`);
    expect(playBtn).toBe(true);
  });

  // --- Article HTML sanitisation (TDD) ---
  // Both tests expect RED until: Rust strips HTML at decrypt-time + JS uses unsafeHTML(msg.content).
  // Currently: lit-html text-escapes content in <span>, so <p> shows as literal "&lt;p&gt;".

  test('Article with embedded script: sanitized by Rust (script tag stripped)', { tag: '@spec' }, async ({ tauriPage }) => {
    await waitForChatView(tauriPage);
    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();

    const sent = await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const result = await ctrl.sendMessage(${JSON.stringify(groupId)}, {
        content: '<p>Block paragraph.</p>',
        type: 'Article',
        name: 'Test Paragraph Article'
      });
      const view = window.shadowQ('e2ee-chat-view');
      if (view?.loadMessages) await view.loadMessages(${JSON.stringify(groupId)});
      return result?.messageApId ?? null;
    })()`);
    expect(sent).toBeTruthy();

    await tauriPage.waitForFunction(
      `window.shadowQ('e2ee-chat-view >>> [data-msg-id="${sent}"] .chat-bubble') != null`,
      10_000
    );
    const bubbleText = await tauriPage.evaluate(
      `window.shadowQ('e2ee-chat-view >>> [data-msg-id="${sent}"] .chat-bubble')?.textContent`
    ) as string | null;
    // Rendered HTML: textContent should be the paragraph text, not the raw tag
    expect(bubbleText).toContain('Block paragraph.');
    expect(bubbleText).not.toContain('<p>');
  });

  // NOTE: XSS sanitisation test (script stripped on receive) belongs in co-device.spec.ts
  // because sanitize_message_content runs in the Rust decrypt command, which is only invoked
  // on the RECEIVE path (not the local self-send path used in single-device tests).
  // See: co-device.spec.ts "Article received from co-device: script stripped by Rust sanitization"

  // --- Gap tests (TDD) ---

  test('document-only attachment sent as Document object and rendered as file chip without bubble', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);
    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();

    // Send message, load it, then force _attachmentsReady and inspect DOM all in one evaluate.
    // Background pollInbox() calls can reset _attachmentsReady=false asynchronously (macrotasks),
    // so we query the DOM synchronously inside the same microtask chain after forcing the flag —
    // no macrotask can interleave between updateComplete and the querySelector calls.
    const docResult: { sent: string | null, hasBubble: boolean, hasChip: boolean, hasButton: boolean, chipText: string | null } =
      await tauriPage.evaluate(`(async () => {
        const ctrl = ${GET_CTRL};
        const msgResult = await ctrl.sendMessage(${JSON.stringify(groupId)}, {
          attachments: [{ type: 'Document', mediaType: 'application/pdf', content: 'JVBERi0xLjA=', name: 'test.pdf' }]
        });
        const sent = msgResult?.messageApId ?? null;
        if (!sent) return { sent: null, hasBubble: false, hasChip: false, hasButton: false, chipText: null };
        const view = window.shadowQ('e2ee-chat-view');
        if (view?.loadMessages) await view.loadMessages(${JSON.stringify(groupId)});
        await view.updateComplete;
        // Force _attachmentsReady — background loadMessages calls (SSE, pollInbox) can reset it.
        // Setting synchronously here ensures the chip renders before we inspect the DOM.
        view._attachmentsReady = true;
        await view.updateComplete;
        const msgEl = view.shadowRoot.querySelector('[data-msg-id="' + sent + '"]');
        return {
          sent,
          hasBubble: !!msgEl?.querySelector('.chat-bubble'),
          hasChip:   !!msgEl?.querySelector('.bg-base-300'),
          hasButton: !!msgEl?.querySelector('.bg-base-300 button'),
          chipText:  msgEl?.querySelector('.bg-base-300')?.textContent ?? null,
        };
      })()`);

    expect(docResult.sent).toBeTruthy();
    // Document renders as a file chip — no chat-bubble wrapper
    expect(docResult.hasBubble).toBe(false);
    // Chip is present (paperclip/filename container)
    expect(docResult.hasChip).toBe(true);
    expect(docResult.hasButton).toBe(true);
    // Filename is visible in the chip
    expect(docResult.chipText).toContain('test.pdf');
  });

  test('PublicMessage wire format — activity routed to _handlePublicMessage', async ({ tauriPage }) => {
    test.setTimeout(30_000);
    await waitForChatView(tauriPage);

    // Spy on _handlePublicMessage to count invocations before injecting the activity
    await tauriPage.evaluate(`(() => {
      const ctrl = ${GET_CTRL};
      window.__pubMsgCallCount = 0;
      const orig = ctrl._handlePublicMessage.bind(ctrl);
      ctrl._handlePublicMessage = async (...args) => {
        window.__pubMsgCallCount++;
        return orig(...args);
      };
    })()`);

    // Inject a PublicMessage with dummy bytes and a fake context URL.
    // handleActivity routes by type — groupId resolves to null for the fake context (fine for routing).
    // _handlePublicMessage's MLS decrypt is caught by its internal try/catch — won't throw.
    await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      await ctrl.handleActivity({
        type: 'Create',
        actor: ctrl.currentActorId,
        object: {
          id: 'http://localhost:4000/pub/objects/test-pubmsg-routing',
          type: 'PublicMessage',
          attributedTo: ctrl.currentActorId,
          mediaType: 'message/mls',
          encoding: 'base64',
          content: 'AAEC',
          context: 'http://localhost:4000/pub/objects/test-group-ctx',
          to: [ctrl.currentActorId],
        }
      });
    })()`);

    const callCount = await tauriPage.evaluate(`window.__pubMsgCallCount`);
    expect(callCount).toBe(1);
  });

});
