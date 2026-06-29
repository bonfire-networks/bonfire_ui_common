// KP endorsement signing e2e tests — single-device.
// Verifies that KPs are published with mlsSignature+mlsSignerKeyId, the cache is
// populated correctly, and _handleKeyPackageAdd accepts/rejects based on cache lookup.
// Run with: just test-tauri-e2e-single

import { test, expect, waitForChatView, getActorId, injectKeyPackageAdd, fetchPublishedSignedKP } from './helpers';

const GET_CTRL = `(() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })()`;

// Shared across tests — captured in the first test after replenishment.
// Avoids repeated server fetches that can time out under load.
let sharedKpInfo: { kpB64: string; mlsSignature: string | null; mlsSignerKeyId: string | null } | null = null;
let sharedActorId: string | null = null;

test.describe('KP endorsement signing', { tag: ['@single-device', '@proposal'] }, () => {
  // https://github.com/swicg/activitypub-e2ee/issues/43
  // https://github.com/swicg/activitypub-e2ee/issues/48

  test('published KP has mlsSignature and mlsSignerKeyId', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);
    sharedActorId = await getActorId(tauriPage);
    // Replenish to guarantee a freshly signed KP is on the server (replaces any unsigned legacy KP)
    await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      await ctrl.mlsService.clearKeyPackage(ctrl.currentActorId);
      const actor = { id: ctrl.currentActorId, ...(JSON.parse(localStorage.getItem('actor') || '{}')) };
      await ctrl._replenishKeyPackage(actor);
    })()`);
    sharedKpInfo = await fetchPublishedSignedKP(tauriPage, sharedActorId!);
    expect(sharedKpInfo).not.toBeNull();
    expect(typeof sharedKpInfo!.mlsSignature).toBe('string');
    expect(typeof sharedKpInfo!.mlsSignerKeyId).toBe('string');
    expect(sharedKpInfo!.mlsSignature!.length).toBeGreaterThan(0);
    expect(sharedKpInfo!.mlsSignerKeyId!.length).toBeGreaterThan(0);
    // Reload so the controller re-initializes cleanly before subsequent tests.
    // Replenishment calls localStorage.removeItem('actor') which can leave the controller
    // in a partially-reset state; a clean reload ensures single-device tests (which run
    // next, alphabetically) start from a known-good state. IndexedDB (mlsKnownKeys cache)
    // persists across reloads so tests 2–6 still find the cached signing key.
    await tauriPage.reload();
    await waitForChatView(tauriPage);
  });

  test('mlsSignerKeyId is in mlsKnownKeys cache after publish', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);
    expect(sharedKpInfo).not.toBeNull();
    const cached = await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      return await ctrl.storage.getMlsKnownKey(${JSON.stringify(sharedKpInfo!.mlsSignerKeyId)});
    })()`);
    expect(cached).toBeTruthy();
  });

const KP_OBJECT_SHAPES = [
  {
    label: 'standard (content/encoding)',
    buildObject: (actorUri: string, kpB64: string) => ({
      type: 'KeyPackage', attributedTo: actorUri, mediaType: 'message/mls', encoding: 'base64', content: kpB64,
    }),
  },
  {
    label: 'mls:-prefixed fields (mls:content / mls:KeyPackage type)',
    buildObject: (actorUri: string, kpB64: string) => ({
      type: 'mls:KeyPackage', attributedTo: actorUri, 'mls:encoding': 'base64', 'mls:content': kpB64,
    }),
  },
  {
    label: 'array type ["Object","mls:KeyPackage"]',
    buildObject: (actorUri: string, kpB64: string) => ({
      type: ['Object', 'mls:KeyPackage'], attributedTo: actorUri, 'mls:encoding': 'base64', 'mls:content': kpB64,
    }),
  },
];

for (const shape of KP_OBJECT_SHAPES) {
  test(`Add KP with ${shape.label}: accepted`, async ({ tauriPage }) => {
    await waitForChatView(tauriPage);
    expect(sharedKpInfo).not.toBeNull();
    const { kpB64, mlsSignature, mlsSignerKeyId } = sharedKpInfo!;
    // Clear stored KP before each shape iteration so injectKeyPackageAdd's `after !== before` check passes
    await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      await ctrl.storage.saveUserField(${JSON.stringify(sharedActorId)}, 'keyPackage', null);
    })()`);
    const stored = await injectKeyPackageAdd(
      tauriPage, sharedActorId!, kpB64, mlsSignature!,
      shape.buildObject(sharedActorId!, kpB64),
      mlsSignerKeyId!,
    );
    expect(stored).toBe(true);
  });
}

  test('Add with mlsSignerKeyId NOT in cache: rejected', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);
    expect(sharedKpInfo).not.toBeNull();
    const { kpB64, mlsSignature } = sharedKpInfo!;
    const stored = await injectKeyPackageAdd(tauriPage, sharedActorId!, kpB64, mlsSignature!, undefined, 'ZmFrZUtleUlk');
    expect(stored).toBe(false);
  });

  test('Add with valid signerKeyId but wrong signature: rejected', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);
    expect(sharedKpInfo).not.toBeNull();
    const { kpB64, mlsSignerKeyId } = sharedKpInfo!;
    const stored = await injectKeyPackageAdd(tauriPage, sharedActorId!, kpB64, 'ZmFrZXNpZw==', undefined, mlsSignerKeyId!);
    expect(stored).toBe(false);
  });

  test('_verifyKpEndorsement returns false when no signature provided', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);
    const result = await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      return await ctrl._verifyKpEndorsement('ZmFrZQ==', { mlsSignature: null, mlsSignerKeyId: null });
    })()`);
    expect(result).toBe(false);
  });

});
