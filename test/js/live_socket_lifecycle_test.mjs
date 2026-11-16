import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const moduleUrl = new URL("../../assets/js/live_socket_lifecycle.js", import.meta.url);
const moduleSource = fs.readFileSync(moduleUrl, "utf8");

// desktop and visible: only the "phoenix is reconnecting" rule can suppress a reload
function load({ socketConnected = false, closeWasClean = false, pendingLink = false } = {}) {
  const reloads = [];

  const socket = {
    closeWasClean,
    isConnected: () => socketConnected,
    onOpen() {},
    onClose() {},
  };

  const liveSocket = {
    reloadWithJitterTimer: null,
    reloadWithJitter: (view) => reloads.push(view),
    bindTopLevelEvents() {},
    isUnloaded: () => false,
    isConnected: () => socketConnected,
    hasPendingLink: () => pendingLink,
    getSocket: () => socket,
  };

  const context = {
    window: { addEventListener() {}, setTimeout: () => 0 },
    document: { visibilityState: "visible", wasDiscarded: false },
    navigator: { userAgent: "Mozilla/5.0 (X11; Linux x86_64)", maxTouchPoints: 0, onLine: true },
    console: { debug() {}, warn() {} },
    clearTimeout() {},
  };
  context.globalThis = context;

  const runnable = moduleSource.replace(/export function (\w+)/g, "globalThis.$1 = function $1");
  vm.runInNewContext(runnable, context, { filename: moduleUrl.pathname });
  const state = context.setupLiveSocketLifecycle(liveSocket);

  const events = () => state.events.map((entry) => entry.event);
  return { liveSocket, reloads, events };
}

test("a close phoenix is already reconnecting from does not reload the page", () => {
  const { liveSocket, reloads, events } = load({ socketConnected: false, closeWasClean: false });

  liveSocket.reloadWithJitter("main");

  assert.deepEqual(reloads, []);
  assert.ok(events().includes("reload_with_jitter_suppressed"));
});

test("a close after our own disconnect still reloads", () => {
  const { liveSocket, reloads, events } = load({ socketConnected: false, closeWasClean: true });

  liveSocket.reloadWithJitter("main");

  assert.deepEqual(reloads, ["main"]);
  assert.ok(events().includes("reload_with_jitter_allowed"));
});

test("a failed join on a connected socket still reloads", () => {
  const { liveSocket, reloads } = load({ socketConnected: true, closeWasClean: false });

  liveSocket.reloadWithJitter("main");

  assert.deepEqual(reloads, ["main"]);
});

test("a close during a pending navigation still reloads", () => {
  const { liveSocket, reloads } = load({
    socketConnected: false,
    closeWasClean: false,
    pendingLink: true,
  });

  liveSocket.reloadWithJitter("main");

  assert.deepEqual(reloads, ["main"]);
});
