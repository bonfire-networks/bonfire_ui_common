import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const moduleUrl = new URL("../../assets/js/leaving_page.js", import.meta.url);
const moduleSource = fs.readFileSync(moduleUrl, "utf8");

function fakeElement() {
  const attrs = new Map();
  return {
    setAttribute: (k, v) => attrs.set(k, v),
    removeAttribute: (k) => attrs.delete(k),
    hasAttribute: (k) => attrs.has(k),
  };
}

function load({ historyState = null, connected = true, mainId = "phx-feed" } = {}) {
  const listeners = new Map();
  const column = fakeElement();
  const timers = [];

  const main = {
    id: mainId,
    isConnected: () => connected,
    el: { querySelector: (sel) => (sel === '[data-id="main_section"]' ? column : null) },
  };

  const context = {
    window: {
      addEventListener(type, fn) {
        if (!listeners.has(type)) listeners.set(type, []);
        listeners.get(type).push(fn);
      },
    },
    document: {
      querySelectorAll: (sel) => (sel === "[data-leaving]" && column.hasAttribute("data-leaving") ? [column] : []),
    },
    history: { state: historyState },
    setTimeout: (fn) => timers.push(fn),
  };
  context.globalThis = context;

  const runnable = moduleSource.replace(/export function (\w+)/g, "globalThis.$1 = function $1");
  vm.runInNewContext(runnable, context, { filename: moduleUrl.pathname });
  context.setupHideLeavingPage({ main });

  const dispatch = (type, detail) => (listeners.get(type) || []).forEach((fn) => fn({ detail }));
  const hidden = () => column.hasAttribute("data-leaving");
  const runTimers = () => timers.splice(0).forEach((fn) => fn());

  return { dispatch, hidden, runTimers };
}

test("going back to another page hides the page being left", () => {
  const { dispatch, hidden } = load({ historyState: { type: "redirect", id: "phx-profile" } });

  dispatch("phx:navigate", { pop: true, patch: false });

  assert.ok(hidden());
});

test("a pop that only patches the current view keeps it visible", () => {
  const { dispatch, hidden } = load({ historyState: { type: "patch", id: "phx-feed" } });

  dispatch("phx:navigate", { pop: true, patch: true });

  assert.ok(!hidden());
});

test("a patch-type pop onto another view still replaces it, so hides", () => {
  const { dispatch, hidden } = load({ historyState: { type: "patch", id: "phx-other" } });

  dispatch("phx:navigate", { pop: true, patch: true });

  assert.ok(hidden());
});

test("forward navigations (link clicks) are left alone", () => {
  const { dispatch, hidden } = load();

  dispatch("phx:navigate", { pop: false, patch: false });

  assert.ok(!hidden());
});

test("a navigation that ends without replacing the page shows it again", () => {
  const { dispatch, hidden } = load();

  dispatch("phx:navigate", { pop: true, patch: false });
  dispatch("phx:page-loading-stop", { kind: "element" });
  assert.ok(hidden(), "a click finishing on the old page must not reveal it");

  dispatch("phx:page-loading-stop", { kind: "initial" });
  assert.ok(!hidden());
});

test("never stays hidden if the new page doesn't arrive", () => {
  const { dispatch, hidden, runTimers } = load();

  dispatch("phx:navigate", { pop: true, patch: false });
  runTimers();

  assert.ok(!hidden());
});
