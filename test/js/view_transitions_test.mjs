import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const moduleUrl = new URL("../../assets/js/view_transitions.js", import.meta.url);
const moduleSource = fs.readFileSync(moduleUrl, "utf8");

function load({ reducedMotion = false, throwing = false } = {}) {
  const listeners = new Map();
  const log = [];

  const window = {
    addEventListener(type, fn) {
      if (!listeners.has(type)) listeners.set(type, []);
      listeners.get(type).push(fn);
    },
  };

  const document = {
    visibilityState: "visible",
    startViewTransition(update) {
      if (throwing) throw new Error("nope");
      log.push("transition");
      // like the real API: the update runs later, after the old state is captured
      return { updateCallbackDone: new Promise((resolve) => setTimeout(resolve, 5)).then(update) };
    },
  };

  const context = {
    window,
    document,
    console,
    setTimeout,
    Promise,
    prefersReducedMotion: () => reducedMotion,
  };
  context.globalThis = context;

  // imports are provided as sandbox globals
  const runnable = moduleSource
    .replace(/^import .*$/gm, "")
    .replace(/export function (\w+)/g, "globalThis.$1 = function $1");
  vm.runInNewContext(runnable, context, { filename: moduleUrl.pathname });
  context.setupViewTransitions();

  const dispatch = (type, event = {}) => (listeners.get(type) || []).forEach((fn) => fn(event));
  const patch = (name) => context.onDocumentPatch(() => log.push(name));
  const navigate = (kind = "redirect") => dispatch("phx:page-loading-start", { detail: { kind } });

  return { dispatch, patch, navigate, log };
}

const settle = () => new Promise((resolve) => setTimeout(resolve, 20));

test("ordinary diffs are applied straight away, without a transition", () => {
  const { patch, log } = load();

  patch("diff");

  assert.deepEqual(log, ["diff"]);
});

test("the patch after a live navigation crossfades, only that one", async () => {
  const { patch, navigate, log } = load();

  navigate();
  patch("mount");
  await settle();
  patch("later diff");

  assert.deepEqual(log, ["transition", "mount", "later diff"]);
});

test("diffs arriving while the transition is pending are applied after the mount", async () => {
  const { patch, navigate, log } = load();

  navigate();
  patch("mount");
  patch("async assigns");
  await settle();

  assert.deepEqual(log, ["transition", "mount", "async assigns"]);
});

test("live patches (tabs, filters, search) are not animated", () => {
  const { patch, navigate, log } = load();

  navigate("patch");
  patch("diff");

  assert.deepEqual(log, ["diff"]);
});

test("back/forward is left to the browser, which may already animate a swipe", () => {
  const { patch, navigate, log } = load();

  navigate("initial");
  patch("mount");

  assert.deepEqual(log, ["mount"]);
});

test("reduced motion skips the transition", () => {
  const { patch, navigate, log } = load({ reducedMotion: true });

  navigate();
  patch("mount");

  assert.deepEqual(log, ["mount"]);
});

test("a navigation that ends without a patch doesn't animate the next diff", () => {
  const { dispatch, patch, navigate, log } = load();

  navigate();
  dispatch("phx:page-loading-stop");
  patch("diff");

  assert.deepEqual(log, ["diff"]);
});

test("the page is still patched if the transition can't start", async () => {
  const { patch, navigate, log } = load({ throwing: true });

  navigate();
  patch("mount");
  await settle();

  assert.deepEqual(log, ["mount"]);
});
