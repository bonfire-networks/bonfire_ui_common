import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const moduleUrl = new URL("../../assets/js/pull_to_refresh.js", import.meta.url);
const moduleSource = fs.readFileSync(moduleUrl, "utf8");

// The module is ESM with imports the vm can't resolve — strip them (the
// imported helpers are provided as sandbox globals) and expose the setup fn.
function runnableSource() {
  return moduleSource
    .replace(/^import .*$/gm, "")
    .replace(/^export function setupPullToRefresh/m, "function setupPullToRefresh")
    .concat("\nglobalThis.__setupPullToRefresh = setupPullToRefresh;\n");
}

class FakeElement {}

function makeTarget({ event = "refresh", visible = true, inMain = true } = {}) {
  const el = new FakeElement();
  el.offsetParent = visible ? {} : null;
  el.getAttribute = (name) => (name === "data-ptr-refresh" ? event : null);
  el.closest = (selector) => (selector === "#main-content" && inMain ? {} : null);
  return el;
}

function pageTouchTarget() {
  const el = new FakeElement();
  el.closest = () => null;
  return el;
}

function makeStyledNode() {
  return {
    children: [],
    style: {},
    classList: { add() {} },
    setAttribute() {},
    appendChild(child) {
      this.children.push(child);
    },
  };
}

function loadModule({
  pwa = true,
  flag = false,
  maxTouchPoints = 1,
  targets = [],
  connected = true,
  scrollable = () => false,
} = {}) {
  const listeners = new Map();
  const pushes = [];
  const timers = new Map();
  const created = [];
  let now = 0;
  let nextTimerId = 1;
  let reloads = 0;

  const on = (name, handler) => {
    if (!listeners.has(name)) listeners.set(name, new Set());
    listeners.get(name).add(handler);
  };
  const off = (name, handler) => {
    listeners.get(name)?.delete(handler);
  };
  const fire = (name, event = {}) => {
    for (const handler of Array.from(listeners.get(name) || [])) handler(event);
  };
  const listening = (name) => (listeners.get(name)?.size || 0) > 0;

  const advance = (ms) => {
    const deadline = now + ms;
    for (;;) {
      const due = Array.from(timers.entries())
        .filter(([, timer]) => timer.at <= deadline)
        .sort((a, b) => a[1].at - b[1].at)[0];
      if (!due) break;
      const [id, timer] = due;
      timers.delete(id);
      now = timer.at;
      timer.fn();
    }
    now = deadline;
  };

  const documentElement = { dataset: {} };
  const bodyChildren = [];

  const context = {
    Math,
    Array,
    console,
    prefersReducedMotion: () => false,
    hasScrollableAncestor: (target) => scrollable(target),
    flagEnabled: () => flag,
    Element: FakeElement,
    performance: { now: () => now },
    setTimeout: (fn, delay) => {
      const id = nextTimerId++;
      timers.set(id, { fn, at: now + (delay || 0) });
      return id;
    },
    clearTimeout: (id) => timers.delete(id),
    navigator: { maxTouchPoints },
    document: {
      documentElement,
      scrollingElement: { scrollTop: 0 },
      body: {
        contains: (node) => bodyChildren.includes(node),
        appendChild: (node) => bodyChildren.push(node),
      },
      createElement: () => {
        const node = makeStyledNode();
        created.push(node);
        return node;
      },
      createElementNS: () => makeStyledNode(),
      querySelectorAll: (selector) =>
        selector === "[data-ptr-refresh]" ? targets : [],
    },
    liveSocket: null,
  };
  context.window = {
    matchMedia: () => ({ matches: pwa }),
    navigator: { standalone: false },
    addEventListener: on,
    removeEventListener: off,
    location: {
      reload: () => {
        reloads += 1;
      },
    },
  };
  context.globalThis = context;

  vm.createContext(context);
  vm.runInContext(runnableSource(), context);

  const liveSocket = {
    isConnected: () => connected,
    js: () => ({
      push: (el, event, opts) => pushes.push({ el, event, opts }),
    }),
  };
  context.__setupPullToRefresh(liveSocket);

  const touch = (x, y) => ({ clientX: x, clientY: y });
  const gesture = {
    start(x = 100, y = 100, target = pageTouchTarget()) {
      fire("touchstart", { touches: [touch(x, y)], target });
    },
    move(x, y, { extraTouch = false } = {}) {
      const touches = [touch(x, y)];
      if (extraTouch) touches.push(touch(x + 40, y + 40));
      fire("touchmove", { touches, cancelable: true, preventDefault() {} });
    },
    end() {
      fire("touchend", { type: "touchend", touches: [] });
    },
  };
  // the indicator wrapper is the first element appended to <body>
  const indicator = () => bodyChildren[0];

  return {
    advance,
    documentElement,
    fire,
    gesture,
    indicator,
    listening,
    pushes,
    reloads: () => reloads,
  };
}

const pullPast = (env, target) => {
  env.gesture.start(100, 100, target);
  env.gesture.move(100, 400); // asymptotic distance comfortably past the 72px threshold
  env.gesture.end();
};

test("does not install listeners outside PWA mode without the debug flag", () => {
  const env = loadModule({ pwa: false, flag: false });
  assert.equal(env.listening("touchstart"), false);
});

test("the debug flag enables the gesture outside standalone mode", () => {
  const env = loadModule({ pwa: false, flag: true });
  assert.equal(env.listening("touchstart"), true);
});

test("a pull below the threshold neither pushes nor reloads", () => {
  const env = loadModule({ targets: [makeTarget()] });
  env.gesture.start();
  env.gesture.move(100, 150);
  env.gesture.end();
  assert.equal(env.pushes.length, 0);
  env.advance(10_000);
  assert.equal(env.reloads(), 0);
});

test("a pull past the threshold pushes the target's event with explicit target", () => {
  const target = makeTarget();
  const env = loadModule({ targets: [target] });
  pullPast(env, undefined);
  assert.equal(env.pushes.length, 1);
  assert.equal(env.pushes[0].el, target);
  assert.equal(env.pushes[0].event, "refresh");
  assert.equal(env.pushes[0].opts.target, target);
  assert.equal(env.pushes[0].opts.page_loading, true);
});

test("prefers a visible target over the hidden main-content feed", () => {
  // a post opened in the preview overlay: main feed stays in a display:none
  // subtree while the previewed thread is what the user sees
  const hiddenFeed = makeTarget({ event: "refresh", visible: false, inMain: true });
  const visibleThread = makeTarget({ event: "set", visible: true, inMain: false });
  const env = loadModule({ targets: [hiddenFeed, visibleThread] });
  pullPast(env);
  assert.equal(env.pushes.length, 1);
  assert.equal(env.pushes[0].el, visibleThread);
  assert.equal(env.pushes[0].event, "set");
});

test("falls back to a full reload when no target is visible", () => {
  const env = loadModule({ targets: [makeTarget({ visible: false })] });
  pullPast(env);
  assert.equal(env.pushes.length, 0);
  assert.equal(env.reloads(), 1);
});

test("unrelated page-loading-stop events leave the hard-reload watchdog armed", () => {
  const target = makeTarget();
  const env = loadModule({ targets: [target] });
  pullPast(env);
  env.fire("phx:page-loading-stop", { detail: { kind: "redirect" } });
  env.fire("phx:page-loading-stop", {
    detail: { kind: "element", target: makeTarget() },
  });
  env.advance(8_000);
  assert.equal(env.reloads(), 1);
});

test("an acked refresh settles the spinner without reloading", () => {
  const target = makeTarget();
  const env = loadModule({ targets: [target] });
  pullPast(env);
  env.fire("phx:page-loading-stop", { detail: { kind: "element", target } });
  env.advance(10_000);
  assert.equal(env.reloads(), 0);
  assert.equal(env.indicator().style.display, "none");
});

test("a second finger cancels the pull instead of committing a refresh", () => {
  const env = loadModule({ targets: [makeTarget()] });
  env.gesture.start();
  env.gesture.move(100, 400);
  env.gesture.move(100, 420, { extraTouch: true });
  env.gesture.end();
  assert.equal(env.pushes.length, 0);
});

test("does not arm while the composer is open or scroll is locked", () => {
  for (const flag of ["composerOpen", "scrollLocked"]) {
    const env = loadModule({ targets: [makeTarget()] });
    env.documentElement.dataset[flag] = "true";
    pullPast(env);
    assert.equal(env.pushes.length, 0, `${flag} should block the gesture`);
  }
});

test("a pull starting inside an inner scroller is handed back", () => {
  const owned = pageTouchTarget();
  const env = loadModule({
    targets: [makeTarget()],
    scrollable: (target) => target === owned,
  });
  env.gesture.start(100, 100, owned);
  env.gesture.move(100, 400);
  env.gesture.end();
  assert.equal(env.pushes.length, 0);
});

test("navigation while refreshing disarms the reload watchdog", () => {
  const target = makeTarget();
  const env = loadModule({ targets: [target] });
  pullPast(env);
  env.fire("phx:page-loading-start", { detail: { kind: "redirect" } });
  env.advance(10_000);
  assert.equal(env.reloads(), 0);
});
