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
  await tauriPage.waitForFunction(`window.shadowQ(${JSON.stringify(selector)}) != null`, timeout);
  await tauriPage.evaluate(`window.shadowQ(${JSON.stringify(selector)}).click()`);
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

/** Return the current device's MLS signature key (base64). */
export async function getOwnSignatureKey(page: any): Promise<string> {
  return page.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    return await ctrl.mlsService.getOwnSignatureKey(ctrl.currentActorId);
  })()`);
}

/** Sign kpB64 with the current device's MLS key. Returns { signerKey, signature }. */
export async function signData(page: any, data: string): Promise<{ signerKey: string; signature: string }> {
  return page.evaluate(`(async () => {
    const ctrl = ${GET_CTRL};
    return await ctrl.mlsService.signData(ctrl.currentActorId, ${JSON.stringify(data)});
  })()`);
}
