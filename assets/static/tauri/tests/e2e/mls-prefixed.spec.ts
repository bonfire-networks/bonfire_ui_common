// Third-party server interop e2e tests — optional, requires a real remote actor.
// Run with: just test-tauri-e2e-single grep="@mls-prefixed"
// Requires: E2E_THIRD_PARTY_SERVER_ACTOR_URI — AP actor URI of a third-party server user (e.g. Emissary)
//           E2E_S1_ALICE_LOGIN/PASSWORD — local Bonfire actor (primary device)
//
// Skipped automatically when E2E_THIRD_PARTY_SERVER_ACTOR_URI is unset.

import { test, expect, waitForChatView, createGroupAndRefresh, getActorId } from './helpers';

const THIRD_PARTY_ACTOR_URI = process.env.E2E_THIRD_PARTY_SERVER_ACTOR_URI ?? null;

test.describe('mls-prefixed third-party interop', { tag: '@mls-prefixed' }, () => {

  test.beforeEach(async () => {
    test.skip(!THIRD_PARTY_ACTOR_URI, 'E2E_THIRD_PARTY_SERVER_ACTOR_URI not set — skipping third-party interop tests');
  });

  test('fetches remote actor keyPackages collection', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);

    const kpContent = await tauriPage.evaluate(`(async () => {
      const { fetchActorKeyPackage } = await import('./activitypub/client.js');
      const result = await fetchActorKeyPackage(${JSON.stringify(THIRD_PARTY_ACTOR_URI)});
      return result?.content ?? null;
    })()`);

    expect(kpContent).toBeTruthy();
  });

  test('resolves all keyPackages regardless of mls: prefix or collection shape', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);

    const { itemCount, allHaveContent } = await tauriPage.evaluate(`(async () => {
      const { fetchAllActorKeyPackages } = await import('./activitypub/client.js');
      const kps = await fetchAllActorKeyPackages(${JSON.stringify(THIRD_PARTY_ACTOR_URI)});
      return { itemCount: kps.length, allHaveContent: kps.every(k => !!k.content) };
    })()`);

    expect(itemCount).toBeGreaterThan(0);
    expect(allHaveContent).toBe(true);
  });

  test('can create group and add remote actor as member', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);

    const groupId = await createGroupAndRefresh(tauriPage);
    expect(groupId).toBeTruthy();

    const GET_CTRL = `(() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })()`;

    await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      await ctrl.addMemberToGroup(${JSON.stringify(groupId)}, ${JSON.stringify(THIRD_PARTY_ACTOR_URI)});
    })()`);

    const memberCount = await tauriPage.evaluate(`(async () => {
      const ctrl = ${GET_CTRL};
      const members = await ctrl.getGroupMembers(${JSON.stringify(groupId)}) ?? [];
      return members.length;
    })()`);

    expect(memberCount).toBeGreaterThanOrEqual(2);
  });

  test('Add with mls:-prefixed object fields is accepted', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);

    const GET_CTRL = `(() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })()`;

    const stored = await tauriPage.evaluate(`(async () => {
      const { fetchAllActorKeyPackages } = await import('./activitypub/client.js');
      const kps = await fetchAllActorKeyPackages(${JSON.stringify(THIRD_PARTY_ACTOR_URI)});
      if (!kps.length) return null;
      const ctrl = ${GET_CTRL};
      const before = (await ctrl.storage.loadUserState(${JSON.stringify(THIRD_PARTY_ACTOR_URI)}))?.keyPackage;
      await ctrl.handleActivity({
        '@context': ['https://www.w3.org/ns/activitystreams', 'https://purl.archive.org/socialweb/mls'],
        type: 'Add',
        actor: ${JSON.stringify(THIRD_PARTY_ACTOR_URI)},
        object: {
          type: 'mls:KeyPackage',
          attributedTo: ${JSON.stringify(THIRD_PARTY_ACTOR_URI)},
          'mls:encoding': 'base64',
          'mls:content': kps[0].content,
        },
      });
      const after = (await ctrl.storage.loadUserState(${JSON.stringify(THIRD_PARTY_ACTOR_URI)}))?.keyPackage;
      return after !== null && after !== before;
    })()`);

    expect(stored).toBe(true);
  });

  test('Add with array type ["Object", "mls:KeyPackage"] is accepted', async ({ tauriPage }) => {
    await waitForChatView(tauriPage);

    const GET_CTRL = `(() => { const v = window.shadowQ('e2ee-chat-view'); return v?._controller || v?.controller; })()`;

    const stored = await tauriPage.evaluate(`(async () => {
      const { fetchAllActorKeyPackages } = await import('./activitypub/client.js');
      const kps = await fetchAllActorKeyPackages(${JSON.stringify(THIRD_PARTY_ACTOR_URI)});
      if (!kps.length) return null;
      const ctrl = ${GET_CTRL};
      const before = (await ctrl.storage.loadUserState(${JSON.stringify(THIRD_PARTY_ACTOR_URI)}))?.keyPackage;
      await ctrl.handleActivity({
        '@context': ['https://www.w3.org/ns/activitystreams', 'https://purl.archive.org/socialweb/mls'],
        type: 'Add',
        actor: ${JSON.stringify(THIRD_PARTY_ACTOR_URI)},
        object: {
          type: ['Object', 'mls:KeyPackage'],
          attributedTo: ${JSON.stringify(THIRD_PARTY_ACTOR_URI)},
          'mls:encoding': 'base64',
          'mls:content': kps[0].content,
        },
      });
      const after = (await ctrl.storage.loadUserState(${JSON.stringify(THIRD_PARTY_ACTOR_URI)}))?.keyPackage;
      return after !== null && after !== before;
    })()`);

    expect(stored).toBe(true);
  });

});
