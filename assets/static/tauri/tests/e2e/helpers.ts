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
    const view = window.shadowQ('e2ee-chat-view');
    const controller = view?._controller || view?.controller;
    if (!controller) return null;
    try {
      const id = await controller.createGroup();
      if (controller.currentActorId) {
        await controller.persistMembers(id, [controller.currentActorId]);
      }
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
    const ctrl = window.shadowQ('e2ee-chat-view')?._controller;
    return ctrl?.currentActorId;
  })()`);
}

export async function pollInbox(page: any): Promise<void> {
  await page.evaluate(`(async () => {
    const ctrl = window.shadowQ('e2ee-chat-view')?._controller;
    await ctrl?.pollInbox();
  })()`);
}

export async function addMemberAndWait(creatorPage: any, groupId: string, memberPage: any): Promise<void> {
  const memberId = await getActorId(memberPage);
  await creatorPage.evaluate(`(async () => {
    const ctrl = window.shadowQ('e2ee-chat-view')?._controller;
    await ctrl.addMemberToGroup(${JSON.stringify(groupId)}, ${JSON.stringify(memberId)});
  })()`);
  await pollInbox(memberPage);
  await memberPage.waitForFunction(
    `(async () => {
      const ctrl = window.shadowQ('e2ee-chat-view')?._controller;
      const groups = await ctrl?.storage?.listGroupsWithLastMessage?.() ?? [];
      return groups.some(g => g.groupId === ${JSON.stringify(groupId)});
    })()`,
    15_000
  );
}

export async function leaveGroup(page: any, groupId: string): Promise<void> {
  await page.evaluate(`(async () => {
    const view = window.shadowQ('e2ee-chat-view');
    await view._handleLeaveGroup(${JSON.stringify(groupId)});
  })()`);
}

export async function isNoLongerMember(page: any, groupId: string): Promise<boolean> {
  return page.evaluate(`(async () => {
    const view = window.shadowQ('e2ee-chat-view');
    const ctrl = view?._controller || view?.controller;
    return !!(await ctrl?.storage?.getGroupField(${JSON.stringify(groupId)}, 'noLongerMember', false));
  })()`);
}

export async function getGroupMemberCount(page: any, groupId: string): Promise<number> {
  return page.evaluate(`(async () => {
    const view = window.shadowQ('e2ee-chat-view');
    const ctrl = view?._controller || view?.controller;
    const members = await ctrl?.getGroupMembers(${JSON.stringify(groupId)}) ?? [];
    return members.length;
  })()`);
}
