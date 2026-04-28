// Federated co-device e2e tests — 2 servers, 3 Tauri clients.
// Devices: tauriPage = s1_alice_d1, deviceAlice2 = s1_alice_d2, deviceCharlie = s2_charlie_d1
// Run with: just test-tauri-e2e-federated-co-device
// Requires: E2E_S1_ALICE_LOGIN/PASSWORD, E2E_S2_CHARLIE_LOGIN/PASSWORD

import { test, expect, waitForChatView, shadowClick, pollInbox, createGroupAndRefresh, addMemberAndWait, leaveGroup, isNoLongerMember } from './helpers';

async function createThreeWayGroup(tauriPage: any, deviceAlice2: any, deviceCharlie: any): Promise<{ groupId: string }> {
  const groupId = await createGroupAndRefresh(tauriPage);
  if (!groupId) throw new Error('Failed to create group');
  await addMemberAndWait(tauriPage, groupId, deviceCharlie);
  await addMemberAndWait(tauriPage, groupId, deviceAlice2);
  return { groupId };
}

test.describe('federated-co-device', { tag: '@federated-co-device' }, () => {

  test('s1_alice_d2 leaves → co-device s1_alice_d1 confirms → s2_charlie_d1 updated', async ({ tauriPage, deviceAlice2, deviceCharlie }) => {
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 20_000);
    await waitForChatView(deviceCharlie!, 20_000);

    const { groupId } = await createThreeWayGroup(tauriPage, deviceAlice2!, deviceCharlie!);

    await leaveGroup(deviceAlice2!, groupId);

    // d1 and charlie both poll:
    // d1 gets co-device dialog (leafIndex×30s), charlie gets 10min+leafIndex×2s fallback
    await Promise.all([pollInbox(tauriPage), pollInbox(deviceCharlie!)]);

    // d1 confirms — charlie's 10-min timer is still pending
    await tauriPage.waitForFunction('window.shadowQ("e2ee-chat-view >>> #nd-approve") != null', 40_000);
    await shadowClick(tauriPage, 'e2ee-chat-view >>> #nd-approve');
    await tauriPage.waitForFunction('window.shadowQ("e2ee-chat-view >>> #nd-approve") == null', 10_000);

    // charlie polls to receive d1's Commit — its pending timer cancels
    await pollInbox(deviceCharlie!);

    // charlie: d2 removed (2 remaining: alice as d1, charlie)
    await deviceCharlie!.waitForFunction(
      `(async () => {
        const ctrl = window.shadowQ('e2ee-chat-view')?._controller;
        const members = await ctrl?.getGroupMembers(${JSON.stringify(groupId)}) ?? [];
        return members.length === 2;
      })()`,
      10_000
    );

    expect(await isNoLongerMember(deviceAlice2!, groupId)).toBe(true);
  });

  test('s1_alice_d2 leaves → co-device s1_alice_d1 unresponsive → s2_charlie_d1 fallback commits after 10min', async ({ tauriPage, deviceAlice2, deviceCharlie }) => {
    await waitForChatView(tauriPage);
    await waitForChatView(deviceAlice2!, 20_000);
    await waitForChatView(deviceCharlie!, 20_000);

    const { groupId } = await createThreeWayGroup(tauriPage, deviceAlice2!, deviceCharlie!);

    await leaveGroup(deviceAlice2!, groupId);

    // Only charlie polls — d1 is unresponsive (never confirms)
    await pollInbox(deviceCharlie!);

    // charlie's fallback fires after 10min + leafIndex×2s
    // NOTE: intentionally slow — verifies the safety fallback property, not speed
    await deviceCharlie!.waitForFunction(
      `(async () => {
        const ctrl = window.shadowQ('e2ee-chat-view')?._controller;
        const members = await ctrl?.getGroupMembers(${JSON.stringify(groupId)}) ?? [];
        return members.length === 2;
      })()`,
      11 * 60_000
    );

    expect(await isNoLongerMember(deviceAlice2!, groupId)).toBe(true);
  });

});
