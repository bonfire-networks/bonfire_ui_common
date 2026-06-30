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

/**
 * Mark all current inbox items as processed WITHOUT handling them.
 * Call at the start of a test to drain stale activities accumulated by prior tests,
 * so subsequent pollInbox calls only see activities generated during THIS test.
 */
export async function markInboxProcessed(page: any): Promise<void> {
  await page.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    if (!ctrl) return;
    const { fetchInboxItems } = await import('/assets/ap_c2s_client/js/activitypub/client.js');
    const actor = await (ctrl.mlsService?.getActor?.() ?? Promise.resolve({ id: ctrl.currentActorId }));
    if (!actor?.id) return;
    const actorFull = { ...actor, ...(JSON.parse(localStorage.getItem('actor') || '{}')) };
    const items = await fetchInboxItems(actorFull).catch(() => []);
    for (const item of items) {
      const id = item.id || item.object?.id;
      if (id) await ctrl.storage.markProcessed(actor.id, id);
    }
  })()`);
}

export async function addMemberAndWait(creatorPage: any, groupId: string, memberPage: any, maxPolls = 10, { usePrefix = false } = {}): Promise<void> {
  const memberId = await getActorId(memberPage);
  // Republish a fresh KP so the creator gets a KP whose private key the member holds in WASM.
  // Without this, a KP consumed by a previous test causes NoMatchingKeyPackage and the Welcome
  // is silently skipped. Do NOT pre-clear via clearKeyPackage: _replenishKeyPackage captures
  // oldKpHex internally and deletes the old KP from the AP server — pre-clearing nulls oldKpHex
  // and causes old KPs to accumulate on the server, which slows _fetchKeyPackageForAdd O(N).
  await memberPage.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    if (!ctrl) return;
    const actorId = ctrl.currentActorId;
    if (!actorId) return;
    const actor = { id: actorId, ...(JSON.parse(localStorage.getItem('actor') || '{}')) };
    await ctrl._replenishKeyPackage(actor);
  })()`);
  // Force-refresh the creator's cached copy of member's KP after republish.
  await creatorPage.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    const kps = await ctrl.fetchActorKeyPackages(${JSON.stringify(memberId)});
    if (kps?.[0]?.kpB64) {
      await ctrl.storage.saveUserField(${JSON.stringify(memberId)}, 'keyPackage', kps[0].kpB64);
    }
  })()`);
  console.log(`[addMemberAndWait] adding ${memberId} to group ${groupId}`);
  await creatorPage.evaluate(`(async () => {
    await ${GET_CTRL}.addMemberToGroup(${JSON.stringify(groupId)}, ${JSON.stringify(memberId)}, { usePrefix: ${usePrefix} });
  })()`);
  console.log(`[addMemberAndWait] addMemberToGroup done, polling member inbox`);
  // Poll until the member has both JS storage record and MLS Rust state for the group.
  // Federated joins need more polls (pass maxPolls=30) because Welcome travels s1→s2 via Oban.
  // join_group may also need a retry if the first Welcome decryption fails (stale KP race).
  for (let i = 0; i < maxPolls; i++) {
    await pollInbox(memberPage);
    const joined: boolean = await memberPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const groups = await ctrl?.storage?.listGroupsWithLastMessage?.() ?? [];
      if (!groups.some(g => g.groupId === ${JSON.stringify(groupId)})) return false;
      // Verify MLS Rust state exists (not just JS storage entry)
      try {
        const fps = await ctrl?.mlsService?.getGroupFingerprints(ctrl.currentActorId, ${JSON.stringify(groupId)});
        return (fps?.length ?? 0) > 0;
      } catch { return false; }
    })()`);
    if (joined) { console.log(`[addMemberAndWait] member joined group after ${i + 1} polls`); return; }
    if (i < maxPolls - 1) await new Promise(r => setTimeout(r, 1500));
  }
  throw new Error(`addMemberAndWait: member did not join group ${groupId} after ${maxPolls} polls`);
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
 * Inject a synthetic Add { KeyPackage } activity via the real handleActivity dispatcher.
 * Returns true if the KP was stored (accepted), false if it was rejected.
 * Pass mlsSignature + mlsSignerKeyId to exercise the cache-keyed verification path.
 * Pass a custom `object` to test variant shapes (mls:-prefixed fields, array type, etc).
 */
export async function injectKeyPackageAdd(
  page: any,
  actorUri: string,
  kpB64: string,
  mlsSignature?: string,
  object?: any,
  mlsSignerKeyId?: string,
): Promise<boolean> {
  const defaultObject = { type: 'KeyPackage', attributedTo: actorUri, mediaType: 'message/mls', encoding: 'base64', content: kpB64 };
  return page.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    const before = (await ctrl.storage.loadUserState(${JSON.stringify(actorUri)}))?.keyPackage;
    const activity = {
      type: 'Add',
      actor: ${JSON.stringify(actorUri)},
      object: ${JSON.stringify(object ?? defaultObject)},
      ${mlsSignature ? `mlsSignature: ${JSON.stringify(mlsSignature)},` : ''}
      ${mlsSignerKeyId ? `mlsSignerKeyId: ${JSON.stringify(mlsSignerKeyId)},` : ''}
    };
    await ctrl.handleActivity(activity);
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
 * Fetch the actor's published KeyPackage from the AP server.
 * Returns { kpB64, mlsSignature, mlsSignerKeyId } — populated by the real publish flow.
 */
export async function fetchPublishedSignedKP(
  page: any,
  actorId: string,
): Promise<{ kpB64: string; mlsSignature: string | null; mlsSignerKeyId: string | null } | null> {
  return page.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    const kps = await ctrl.fetchActorKeyPackages(${JSON.stringify(actorId)});
    return kps?.[0] ?? null;
  })()`);
}

/**
 * Send a message in a group and return the AP message ID.
 * Throws if the group's MLS state is lost (EncryptionLostError).
 */
export async function sendMessage(page: any, groupId: string, content: string, { usePrefix = false, overrides = {} } = {}): Promise<string | null> {
  return page.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    const { messageApId } = await ctrl.sendMessage(${JSON.stringify(groupId)}, { content: ${JSON.stringify(content)}, usePrefix: ${usePrefix}, overrides: ${JSON.stringify(overrides)} });
    return messageApId ?? null;
  })()`);
}

/**
 * Send a message via the chat UI: fills the textarea, clicks Send, waits for the new
 * message row to appear in the shadow DOM, and returns its data-msg-id.
 * Use this when the test needs to interact with the rendered message afterwards (edit, delete, react).
 * Use sendMessage() when you only need the AP message ID for setup.
 */
export async function sendMessageUsingUI(page: any, content: string): Promise<string | null> {
  // Snapshot current msg-ids via shadowRoot.querySelectorAll (shadowQ only returns one element)
  const before: string[] = await page.evaluate(
    `Array.from(window.shadowQ('e2ee-chat-view')?.shadowRoot?.querySelectorAll('[data-msg-id]') ?? []).map(el => el.getAttribute('data-msg-id'))`
  );

  // Wait for main message textarea (LitElement renders async after group selection)
  await page.evaluate(`(async () => {
    const deadline = Date.now() + 5_000;
    let ta;
    while (Date.now() < deadline) {
      ta = window.shadowQ('e2ee-chat-view >>> textarea.textarea-bordered:not([id^="edit-input"])');
      if (ta) break;
      await new Promise(r => setTimeout(r, 100));
    }
    if (!ta) throw new Error('message textarea not found — is a group selected?');
    Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set.call(ta, ${JSON.stringify(content)});
    ta.dispatchEvent(new Event('input', { bubbles: true }));
  })()`);

  // Click Send
  await shadowClick(page, 'e2ee-chat-view >>> button[type="submit"].btn-primary');

  // Wait for the new [data-msg-id] to appear
  const deadline = Date.now() + 10_000;
  while (Date.now() < deadline) {
    const after: string[] = await page.evaluate(
      `Array.from(window.shadowQ('e2ee-chat-view')?.shadowRoot?.querySelectorAll('[data-msg-id]') ?? []).map(el => el.getAttribute('data-msg-id'))`
    );
    const newId = after.find(id => !before.includes(id));
    if (newId) return newId;
    await new Promise(r => setTimeout(r, 200));
  }
  return null;
}

/**
 * Click the "edit" link on a rendered message, type new content, click Save.
 * Assumes the message is already visible in the chat view (own message only).
 */
export async function clickEditAndSave(page: any, msgId: string, newContent: string, groupId?: string): Promise<void> {
  // Try clicking the "edit" link in the rendered message row.
  // Falls back to ctrl.editMessage() when the row or edit link is not found.
  const usedUI: boolean = await page.evaluate(`(async () => {
    const root = window.shadowQ('e2ee-chat-view')?.shadowRoot;
    const row = root?.querySelector('[data-msg-id=${JSON.stringify(msgId)}]');
    if (!row) return false;
    const editLink = Array.from(row.querySelectorAll('a.link')).find(a => a.textContent.trim() === 'edit');
    if (!editLink) return false;
    editLink.click();
    return true;
  })()`);

  if (usedUI) {
    // Wait for the edit textarea to appear, then fill it and click Save
    await page.evaluate(`(async () => {
      const deadline = Date.now() + 5_000;
      let ta;
      while (Date.now() < deadline) {
        ta = window.shadowQ('e2ee-chat-view')?.shadowRoot?.querySelector('[id="edit-input-' + ${JSON.stringify(msgId)} + '"]');
        if (ta) break;
        await new Promise(r => setTimeout(r, 100));
      }
      if (!ta) throw new Error('edit textarea did not appear for msg ' + ${JSON.stringify(msgId)});
      Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set.call(ta, ${JSON.stringify(newContent)});
      ta.dispatchEvent(new Event('input', { bubbles: true }));
    })()`);
    await shadowClick(page, 'e2ee-chat-view >>> button.btn-primary.btn-xs');
  } else {
    await page.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const gId = ${JSON.stringify(groupId ?? null)} ?? ${GET_VIEW}?.selectedGroupId;
      await ctrl.editMessage(gId, ${JSON.stringify(msgId)}, ${JSON.stringify(newContent)});
    })()`);
  }
}

/**
 * Click the "delete" link on a rendered message row (own message only).
 * Falls back to ctrl.deleteMessage() when the row or delete link is not in the DOM
 * (e.g. groupEncryptionLost=true → isOwnMsg=false → delete link absent).
 */
export async function clickDelete(page: any, msgId: string, groupId?: string): Promise<void> {
  await page.evaluate(`(async () => {
    const root = window.shadowQ('e2ee-chat-view')?.shadowRoot;
    const row = root?.querySelector('[data-msg-id=${JSON.stringify(msgId)}]');
    const deleteLink = Array.from(row?.querySelectorAll('a.link') ?? []).find(a => a.textContent.trim() === 'delete');
    if (deleteLink) {
      deleteLink.click();
    } else {
      const ctrl = ${GET_CTRL};
      const gId = ${JSON.stringify(groupId ?? null)} ?? ${GET_VIEW}?.selectedGroupId;
      await ctrl.deleteMessage(gId, ${JSON.stringify(msgId)});
    }
  })()`);
}

/**
 * Verify that a message with the given AP ID (or content substring) is stored on the receiving page.
 * Polls storage directly — no inbox poll needed if the message was already processed.
 */
export async function hasReceivedMessage(page: any, groupId: string, contentSubstring: string): Promise<boolean> {
  // Fire the storage query as a background promise so the evaluate returns immediately —
  // avoids the 120s Tauri IPC timeout that triggers when listMessages is called while
  // the view's own loadMessages is still awaiting updateComplete (LitElement render).
  const key = `__hrm_${groupId.slice(-8)}_${contentSubstring.slice(0, 8).replace(/\W/g, '_')}`;
  await page.evaluate(`(() => {
    window[${JSON.stringify(key)}] = undefined;
    (window.__chatStorage?.listMessages?.(${JSON.stringify(groupId)}) ?? Promise.resolve([])).then(msgs => {
      window[${JSON.stringify(key)}] = msgs.some(m => {
        const t = typeof m.content === 'string' ? m.content : m.content?.content ?? '';
        return t.includes(${JSON.stringify(contentSubstring)});
      });
    }).catch(() => { window[${JSON.stringify(key)}] = false; });
  })()`);
  await page.waitForFunction(`window[${JSON.stringify(key)}] != null`, 30_000);
  const result = await page.evaluate(`window[${JSON.stringify(key)}]`);
  await page.evaluate(`delete window[${JSON.stringify(key)}]`);
  return result;
}

/**
 * End-to-end round-trip check: senderPage sends a unique message in groupId,
 * receiverPage polls (with retries for federation delay) and must receive+decrypt it.
 * Throws on unexpected errors so test output shows the real cause.
 */
export async function canSendAndReceive(senderPage: any, receiverPage: any, groupId: string, retries = 5, retryDelayMs = 1500, { usePrefix = false, overrides = {} } = {}): Promise<true> {
  const marker = `e2e-check-${Date.now()}`;
  const errors: string[] = [];
  await sendMessage(senderPage, groupId, marker, { usePrefix, overrides });
  for (let i = 0; i < retries; i++) {
    try { await pollInbox(receiverPage); } catch (e) { errors.push(`poll ${i + 1}: ${e}`); }
    if (await hasReceivedMessage(receiverPage, groupId, marker)) return true;
    if (i < retries - 1) await new Promise(r => setTimeout(r, retryDelayMs));
  }
  throw new Error(`canSendAndReceive: '${marker}' not received after ${retries} polls${errors.length ? ` — ${errors.join('; ')}` : ''}`);
}

/**
 * Full mesh delivery check: every page sends one message and every other page must receive it.
 * Polls all non-sender pages concurrently after each send. Throws if any delivery fails.
 */
export async function allCanSendAndReceive(pages: any[], groupId: string, retries = 8, retryDelayMs = 1500): Promise<void> {
  for (let senderIdx = 0; senderIdx < pages.length; senderIdx++) {
    const sender = pages[senderIdx];
    const receivers = pages.filter((_, i) => i !== senderIdx);
    const marker = `e2e-mesh-${senderIdx}-${Date.now()}`;
    await sendMessage(sender, groupId, marker);
    for (let i = 0; i < retries; i++) {
      await Promise.all(receivers.map(r => pollInbox(r).catch(() => {})));
      const received = await Promise.all(receivers.map(r => hasReceivedMessage(r, groupId, marker)));
      if (received.every(Boolean)) break;
      if (i < retries - 1) await new Promise(r => setTimeout(r, retryDelayMs));
      else throw new Error(`allCanSendAndReceive: sender[${senderIdx}] marker '${marker}' not received by all after ${retries} polls`);
    }
  }
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
        // getGroupFingerprints returns one entry per leaf node (not deduplicated by identity),
        // so co-devices of the same actor each count separately — unlike getGroupMemberIdentities.
        const fps = await ctrl?.mlsService?.getGroupFingerprints(ctrl.currentActorId, ${JSON.stringify(groupId)});
        return fps?.length ?? 0;
      } catch { return 0; }
    })()`);
    console.log(`[waitForMlsMembers] poll ${i + 1}/${retries}: ${count}/${minCount} members in ${groupId}`);
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
    const { signerKey } = await ctrl.mlsService.signData(ctrl.currentActorId, kpB64);
    return signerKey === fp?.signatureKey;
  })()`);
}
