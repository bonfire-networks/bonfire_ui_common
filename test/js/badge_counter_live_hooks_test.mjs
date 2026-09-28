import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const hookUrl = new URL(
  "../../lib/components/placeholders/badge_counter_live.hooks.js",
  import.meta.url
);
const hookSource = fs.readFileSync(hookUrl, "utf8");

// a fresh module (and so fresh per-feed state) per test
function loadAppBadge() {
  const reported = [];
  const visibilityListeners = [];
  const context = {
    document: {
      visibilityState: "visible",
      addEventListener: (type, fn) => type === "visibilitychange" && visibilityListeners.push(fn),
    },
    navigator: {
      serviceWorker: {
        ready: Promise.resolve({ active: { postMessage: (msg) => reported.push(msg.count) } }),
      },
    },
    queueMicrotask,
    parseInt,
    Number,
    Map,
  };
  context.globalThis = context;

  const runnableSource = hookSource.replace(/export default \{/, "globalThis.__AppBadge = {");
  vm.runInNewContext(runnableSource, context, { filename: hookUrl.pathname });

  const hook = (dataset) => {
    const instance = Object.create(context.__AppBadge);
    instance.el = { dataset };
    return instance;
  };

  const becomeVisible = () => visibilityListeners.forEach((fn) => fn());

  return { hook, reported, becomeVisible };
}

const settle = () => new Promise((resolve) => setTimeout(resolve, 0));

test("reports the sum of the current user's feeds to the service worker", async () => {
  const { hook, reported } = loadAppBadge();

  hook({ appBadgeFeed: "notifications", appBadgeCount: "3" }).mounted();
  hook({ appBadgeFeed: "inbox", appBadgeCount: "2" }).mounted();
  await settle();

  assert.deepEqual(reported, [5]);
});

test("ignores badges that aren't the current user's or haven't loaded", async () => {
  const { hook, reported } = loadAppBadge();

  hook({ appBadgeCount: "3" }).mounted();
  hook({ appBadgeFeed: "notifications" }).mounted();
  await settle();

  assert.deepEqual(reported, []);
});

test("reports zero once everything is seen", async () => {
  const { hook, reported } = loadAppBadge();
  const badge = hook({ appBadgeFeed: "notifications", appBadgeCount: "4" });

  badge.mounted();
  await settle();
  badge.el.dataset.appBadgeCount = "0";
  badge.updated();
  await settle();

  assert.deepEqual(reported, [4, 0]);
});

test("a stale duplicate re-rendering doesn't undo a newer count for the same feed", async () => {
  const { hook, reported } = loadAppBadge();
  const dock = hook({ appBadgeFeed: "notifications", appBadgeCount: "4" });
  const sidebar = hook({ appBadgeFeed: "notifications", appBadgeCount: "4" });

  dock.mounted();
  sidebar.mounted();
  await settle();

  // marked seen: only the sidebar badge receives the update
  sidebar.el.dataset.appBadgeCount = "0";
  sidebar.updated();
  await settle();

  // the dock re-renders with its unchanged, stale count
  dock.updated();
  await settle();

  assert.equal(reported.at(-1), 0);
});

test("re-reports when the app comes back on screen, to undo pushes counted meanwhile", async () => {
  const { hook, reported, becomeVisible } = loadAppBadge();

  hook({ appBadgeFeed: "notifications", appBadgeCount: "2" }).mounted();
  await settle();
  becomeVisible();
  await settle();

  assert.deepEqual(reported, [2, 2]);
});
