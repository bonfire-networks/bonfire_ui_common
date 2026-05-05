// Shared helpers for Tauri e2e tests.
// Import from each spec file: import { ... } from './helpers';

import { test as _test, expect } from '../support/fixtures.cjs';
import type { TestType } from '@playwright/test';
import type { TauriFixtures } from '@srsholmes/tauri-playwright';

export type TauriPage = TauriFixtures['tauriPage'];
export type Fixtures = TauriFixtures & {
  deviceAlice2: TauriPage | null;
  deviceCharlie: TauriPage | null;
  deviceBob: TauriPage | null;
};
export const test = _test as unknown as TestType<Fixtures, object>;
export { expect };

// JS snippets that run inside evaluate() — return view/controller from the shadow DOM.
// The view stores controller as this.controller (no underscore).
const GET_VIEW = `window.shadowQ('e2ee-chat-view')`;
const GET_CTRL = `(() => { const v = ${GET_VIEW}; return v?._controller || v?.controller; })()`;

export async function waitForChatView(tauriPage: any, timeout = 20_000) {
  await tauriPage.waitForFunction(
    'window.shadowQ("e2ee-chat-view") != null',
    timeout
  );
}

export async function shadowClick(tauriPage: any, selector: string, timeout = 15_000) {
  // Atomic find+click: poll until the element exists AND was successfully clicked in the same
  // JS microtask, so a ChatController re-init between separate waitForFunction/evaluate calls
  // can't clear the element before we click it.
  const deadline = Date.now() + timeout;
  while (true) {
    const clicked = await tauriPage.evaluate(
      `(function(sel) { const el = window.shadowQ(sel); if (el) { el.click(); return true; } return false; })(${JSON.stringify(selector)})`
    );
    if (clicked) return;
    if (Date.now() >= deadline) throw new Error(`shadowClick timeout: ${selector} not found within ${timeout}ms`);
    await new Promise(r => setTimeout(r, 300));
  }
}

export async function shadowExists(tauriPage: any, selector: string): Promise<boolean> {
  return tauriPage.evaluate(`!!window.shadowQ(${JSON.stringify(selector)})`);
}

export async function createGroupAndRefresh(tauriPage: any): Promise<string | null> {
  return tauriPage.evaluate(`(async () => {
    const view = ${GET_VIEW};
    const ctrl = ${GET_CTRL};
    if (!ctrl) return null;
    try {
      const id = await ctrl.createGroup();
      if (ctrl.currentActorId) await ctrl.persistMembers(id, [ctrl.currentActorId]);
      if (typeof view.loadGroups === 'function') await view.loadGroups();
      return id;
    } catch (e) {
      console.error('[test] createGroupAndRefresh failed:', e);
      return null;
    }
  })()`);
}

export async function getActorId(page: any): Promise<string> {
  return page.evaluate(`(async () => {
    return ${GET_CTRL}?.currentActorId;
  })()`);
}

// Calls view.pollInbox() so results are processed through the view's full handler chain
// (coDeviceLeaving → dialog, newDeviceRequest → dialog, etc.)
export async function pollInbox(page: any): Promise<void> {
  await page.evaluate(`(async () => {
    const view = ${GET_VIEW};
    if (typeof view?.pollInbox === 'function') await view.pollInbox();
    else await ${GET_CTRL}?.pollInbox();
  })()`);
}

export async function addMemberAndWait(creatorPage: any, groupId: string, memberPage: any): Promise<void> {
  const memberId = await getActorId(memberPage);
  await creatorPage.evaluate(`(async () => {
    await ${GET_CTRL}.addMemberToGroup(${JSON.stringify(groupId)}, ${JSON.stringify(memberId)});
  })()`);
  await pollInbox(memberPage);
  await memberPage.waitForFunction(
    `(async () => {
      const ctrl = ${GET_CTRL};
      const groups = await ctrl?.storage?.listGroupsWithLastMessage?.() ?? [];
      return groups.some(g => g.groupId === ${JSON.stringify(groupId)});
    })()`,
    15_000
  );
}

export async function leaveGroup(page: any, groupId: string): Promise<void> {
  await page.evaluate(`(async () => {
    await ${GET_VIEW}._handleLeaveGroup(${JSON.stringify(groupId)});
  })()`);
}

export async function isNoLongerMember(page: any, groupId: string): Promise<boolean> {
  return page.evaluate(`(async () => {
    return !!(await ${GET_CTRL}?.storage?.getGroupField(${JSON.stringify(groupId)}, 'noLongerMember', false));
  })()`);
}

export async function getGroupMemberCount(page: any, groupId: string): Promise<number> {
  return page.evaluate(`(async () => {
    const members = await ${GET_CTRL}?.getGroupMembers(${JSON.stringify(groupId)}) ?? [];
    return members.length;
  })()`);
}

/**
 * Inject a synthetic Add { KeyPackage } activity into the controller's handler.
 * Returns true if the KP was stored (accepted), false if it was rejected.
 */
export async function injectKeyPackageAdd(
  page: any,
  actorUri: string,
  kpB64: string,
  mlsSignature?: { signerKey: string; signature: string }
): Promise<boolean> {
  return page.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    const before = (await ctrl.storage.loadUserState(${JSON.stringify(actorUri)}))?.keyPackage;
    const activity = {
      type: 'Add',
      actor: ${JSON.stringify(actorUri)},
      object: {
        type: 'KeyPackage',
        attributedTo: ${JSON.stringify(actorUri)},
        mediaType: 'message/mls',
        encoding: 'base64',
        content: ${JSON.stringify(kpB64)}
      },
      target: ${JSON.stringify(actorUri)} + '/key-packages',
      ${mlsSignature ? `mlsSignature: ${JSON.stringify(mlsSignature)}` : ''}
    };
    await ctrl._handleKeyPackageAdd(activity);
    const after = (await ctrl.storage.loadUserState(${JSON.stringify(actorUri)}))?.keyPackage;
    return after === ${JSON.stringify(kpB64)} && after !== before;
  })()`);
}

// JS snippet reused across evaluate() calls: converts a hex KP string to base64.
export const HEX_TO_B64 = `(hex => { const b = new Uint8Array(hex.match(/.{2}/g).map(h => parseInt(h, 16))); return btoa(String.fromCharCode(...Array.from(b))); })`;

/** Return the current device's MLS signature key (base64). */
export async function getOwnSignatureKey(page: any): Promise<string> {
  return page.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    return await ctrl.mlsService.getOwnSignatureKey(ctrl.currentActorId);
  })()`);
}

/**
 * Return the current actor's stored KeyPackage as a base64 string (suitable for AP activity content).
 * getKeyPackageHex() returns hex — this converts it inside the webview using HEX_TO_B64.
 */
export async function getKeyPackageB64(page: any, actorId: string): Promise<string> {
  return page.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    const hex = await ctrl.mlsService.getKeyPackageHex(${JSON.stringify(actorId)});
    if (!hex) return null;
    return ${HEX_TO_B64}(hex);
  })()`);
}

/** Sign base64-encoded data with the current device's MLS key. Returns { signerKey, signature }. */
export async function signData(page: any, dataB64: string): Promise<{ signerKey: string; signature: string }> {
  return page.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    return await ctrl.mlsService.signData(ctrl.currentActorId, ${JSON.stringify(dataB64)});
  })()`);
}

/**
 * Get the current actor's KP as base64 and sign it with their own key — all inside the webview
 * to avoid cross-boundary base64 encoding issues.
 * Returns { kpB64, sig: { signerKey, signature } }.
 */
export async function getAndSignOwnKeyPackage(page: any, actorId: string): Promise<{ kpB64: string; sig: { signerKey: string; signature: string } }> {
  return page.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    const hex = await ctrl.mlsService.getKeyPackageHex(${JSON.stringify(actorId)});
    if (!hex) return null;
    const kpB64 = ${HEX_TO_B64}(hex);
    const sig = await ctrl._signKeyPackage(${JSON.stringify(actorId)}, kpB64);
    return { kpB64, sig };
  })()`);
}

/**
 * Send a message in a group and return the AP message ID.
 * Throws if the group's MLS state is lost (EncryptionLostError).
 */
export async function sendMessage(page: any, groupId: string, content: string): Promise<string | null> {
  return page.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    const { messageApId } = await ctrl.sendMessage(${JSON.stringify(groupId)}, { content: ${JSON.stringify(content)} });
    return messageApId ?? null;
  })()`);
}

/**
 * Verify that a message with the given AP ID (or content substring) is stored on the receiving page.
 * Polls storage directly — no inbox poll needed if the message was already processed.
 */
export async function hasReceivedMessage(page: any, groupId: string, contentSubstring: string): Promise<boolean> {
  return page.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    const msgs = await ctrl?.storage?.listMessages?.(${JSON.stringify(groupId)}) ?? [];
    return msgs.some(m => {
      const text = typeof m.content === 'string' ? m.content : m.content?.content ?? '';
      return text.includes(${JSON.stringify(contentSubstring)});
    });
  })()`);
}

/**
 * End-to-end round-trip check: senderPage sends a unique message in groupId,
 * receiverPage polls (with retries for federation delay) and must receive+decrypt it.
 * Throws on unexpected errors so test output shows the real cause.
 */
export async function canSendAndReceive(senderPage: any, receiverPage: any, groupId: string, retries = 5, retryDelayMs = 1500): Promise<true> {
  const marker = `e2e-check-${Date.now()}`;
  const errors: string[] = [];
  await sendMessage(senderPage, groupId, marker);
  for (let i = 0; i < retries; i++) {
    try { await pollInbox(receiverPage); } catch (e) { errors.push(`poll ${i + 1}: ${e}`); }
    if (await hasReceivedMessage(receiverPage, groupId, marker)) return true;
    if (i < retries - 1) await new Promise(r => setTimeout(r, retryDelayMs));
  }
  throw new Error(`canSendAndReceive: '${marker}' not received after ${retries} polls${errors.length ? ` — ${errors.join('; ')}` : ''}`);
}

/**
 * Poll a page's inbox until the group has at least `minCount` MLS members (Rust state only,
 * no JS storage fallback). Retries with a delay so join_group can complete between polls.
 */
export async function waitForMlsMembers(page: any, groupId: string, minCount: number, retries = 40, retryDelayMs = 1500): Promise<void> {
  for (let i = 0; i < retries; i++) {
    await pollInbox(page);
    const count: number = await page.evaluate(`(async () => {
      const ctrl = (() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })();
      try {
        const ids = await ctrl?.mlsService?.getGroupMemberIdentities(${JSON.stringify(groupId)});
        return ids?.length ?? 0;
      } catch { return 0; }
    })()`);
    if (count >= minCount) return;
    if (i < retries - 1) await new Promise(r => setTimeout(r, retryDelayMs));
  }
  throw new Error(`waitForMlsMembers: group ${JSON.stringify(groupId)} did not reach ${minCount} MLS members after ${retries} polls`);
}

/**
 * Check that the stored KP's signature_key matches the device's own signing key —
 * verifies replenishment preserved identity. Done in-webview to avoid encoding issues.
 */
export async function ownKpIsSelfSigned(page: any): Promise<boolean> {
  return page.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    const hex = await ctrl.mlsService.getKeyPackageHex(ctrl.currentActorId);
    if (!hex) return false;
    const kpB64 = ${HEX_TO_B64}(hex);
    const fp = await ctrl.mlsService.getKeyPackageFingerprint(kpB64);
    const { signerKey } = await ctrl._signKeyPackage(ctrl.currentActorId, kpB64);
    return signerKey === fp?.signatureKey;
  })()`);
}
