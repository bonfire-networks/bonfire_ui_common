import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const hookUrl = new URL("../../lib/components/modals/preview_content_live.hooks.js", import.meta.url);
const hookSource = fs.readFileSync(hookUrl, "utf8");

function listenerBag() {
  const listeners = new Map();
  return {
    add(type, fn) {
      if (!listeners.has(type)) listeners.set(type, []);
      listeners.get(type).push(fn);
    },
    dispatch(type, event = {}) {
      for (const fn of listeners.get(type) || []) fn(event);
    }
  };
}

function makePreviewElement(display = "none") {
  const attributes = new Map([["data-show", display === "none" ? "false" : "true"]]);
  return {
    style: { display },
    getAttribute(name) {
      return attributes.has(name) ? attributes.get(name) : null;
    },
    setAttribute(name, value) {
      attributes.set(name, String(value));
    },
    hasAttribute(name) {
      return attributes.has(name);
    },
    removeAttribute(name) {
      attributes.delete(name);
    },
    querySelector() {
      return null;
    }
  };
}

function loadPreviewState(
  currentHref = "http://bonfire.test/feed/local",
  { previewElement = null, triggers = () => [], performance: performanceOverride } = {}
) {
  const store = new Map();
  const timers = new Map();
  const mutationObservers = [];
  const windowEvents = listenerBag();
  const documentEvents = listenerBag();
  let nextTimerId = 1;

  const location = {
    href: currentHref,
    origin: new URL(currentHref).origin,
    assign(url) {
      this.href = new URL(url, this.href).href;
    },
    reload() {
      this.reloaded = true;
    }
  };

  const history = {
    state: null,
    backCalls: 0,
    back() {
      this.backCalls++;
    },
    replaceState(state, _title, url) {
      this.state = state;
      location.href = new URL(url, location.href).href;
    },
    pushState(state, _title, url) {
      this.state = state;
      location.href = new URL(url, location.href).href;
    }
  };

  const document = {
    body: {},
    documentElement: { scrollHeight: 0, clientHeight: 0 },
    addEventListener(type, fn) {
      documentEvents.add(type, fn);
    },
    removeEventListener() {},
    querySelector(selector) {
      if (selector === "#preview_content") return previewElement;
      return null;
    },
    querySelectorAll() {
      return triggers();
    },
    getElementById() {
      return null;
    }
  };

  const performance = performanceOverride || {
    getEntriesByType() {
      return [{ name: "http://bonfire.test/feed/local" }];
    }
  };

  class MutationObserver {
    constructor(callback) {
      this.callback = callback;
      this.disconnected = false;
      mutationObservers.push(this);
    }

    observe() {}

    disconnect() {
      this.disconnected = true;
    }
  }

  const sessionStorage = {
    getItem(key) {
      return store.has(key) ? store.get(key) : null;
    },
    setItem(key, value) {
      store.set(key, String(value));
    },
    removeItem(key) {
      store.delete(key);
    }
  };

  const context = {
    console,
    Date,
    document,
    JSON,
    MutationObserver,
    Number,
    performance,
    URL,
    getComputedStyle(el) {
      return { display: el?.style?.display ?? "none" };
    },
    clearTimeout(timerId) {
      timers.delete(timerId);
    },
    history,
    location,
    parseInt,
    sessionStorage,
    setTimeout(callback) {
      const timerId = nextTimerId++;
      timers.set(timerId, callback);
      return timerId;
    },
    window: {
      addEventListener(type, fn) {
        windowEvents.add(type, fn);
      },
      removeEventListener() {},
      getSelection() {
        return { toString: () => "" };
      },
      location,
      scrollTo() {}
    }
  };

  context.globalThis = context;

  const runnableSource = hookSource.replace(
    /export\s+\{[^}]+\};\s*$/,
    "globalThis.__previewState = previewState; globalThis.__previewUtils = utils; globalThis.__PreviewContainer = PreviewContainer;"
  );

  vm.runInNewContext(runnableSource, context, {
    filename: hookUrl.pathname
  });

  return {
    previewState: context.__previewState,
    previewUtils: context.__previewUtils,
    PreviewContainer: context.__PreviewContainer,
    history,
    location,
    mutationObservers,
    sessionStorage,
    store,
    timers,
    window: context.window,
    windowEvents,
    documentEvents
  };
}

function previewContainerHook(PreviewContainer) {
  return {
    ...PreviewContainer,
    pushedEvents: [],
    pushEventTo(target, event, params) {
      this.pushedEvents.push({ target, event, params });
    }
  };
}

function runPendingTimers(timers) {
  const pending = Array.from(timers.entries());
  for (const [id, fn] of pending) {
    timers.delete(id);
    fn();
  }
}

test("stores one same-origin JSON session and builds preview history state", () => {
  const { previewState, sessionStorage, history } = loadPreviewState();

  const session = previewState.save(
    "http://bonfire.test/feed/local",
    "/post/01TEST",
    "42"
  );
  const historyState = previewState.historyState(session);

  assert.deepEqual(JSON.parse(JSON.stringify(session)), {
    entryUrl: "http://bonfire.test/feed/local",
    previewUrl: "http://bonfire.test/post/01TEST",
    previousScroll: 42
  });

  assert.deepEqual(
    JSON.parse(sessionStorage.getItem(previewState.storageKey)),
    JSON.parse(JSON.stringify(session))
  );
  assert.deepEqual(JSON.parse(JSON.stringify(historyState)), {
    bonfirePreview: true,
    entryUrl: "http://bonfire.test/feed/local",
    previewUrl: "http://bonfire.test/post/01TEST",
    previousScroll: 42
  });

  // LiveView bookkeeping is carried through, offset by the half-step that
  // keeps back/forward direction detection exact from both neighbours.
  history.state = { position: 3, type: "redirect", backType: "patch" };
  const carried = previewState.historyState(session);
  assert.equal(carried.position, 3.5);
  assert.equal(carried.type, "redirect");
  assert.equal(carried.backType, "patch");
});

test("uses the shared motion curve and bypasses transitions for keyboard paths", () => {
  const { previewUtils } = loadPreviewState();

  assert.equal(
    previewUtils.opacityTransition(previewUtils.timing.standardTransition),
    "opacity 180ms cubic-bezier(0.19, 1, 0.22, 1)"
  );
  assert.equal(
    previewUtils.opacityTransition(previewUtils.timing.standardTransition, false),
    "none"
  );
});

test("refuses invalid or cross-origin preview session URLs", () => {
  const { previewState, sessionStorage } = loadPreviewState();

  assert.equal(
    previewState.save("https://evil.test/feed", "/post/01TEST", 0),
    null
  );
  assert.equal(
    previewState.save("http://bonfire.test/feed", "https://evil.test/post/01TEST", 0),
    null
  );
  assert.equal(sessionStorage.getItem(previewState.storageKey), null);
});

test("detects current preview sessions and clears them on close", () => {
  const { previewState, sessionStorage, window } = loadPreviewState("http://bonfire.test/feed/local");

  const session = previewState.save(
    "http://bonfire.test/feed/local",
    "/post/01TEST",
    0
  );

  assert.equal(previewState.isCurrent(session), false);
  window.location.href = "http://bonfire.test/post/01TEST";
  assert.equal(previewState.isCurrent(session), true);

  previewState.clear();

  assert.equal(sessionStorage.getItem(previewState.storageKey), null);
});

test("popping off the overlay entry closes it client-side and notifies the server", () => {
  const previewElement = makePreviewElement("block");
  const {
    PreviewContainer,
    history,
    location,
    previewState,
    sessionStorage,
    timers,
    windowEvents
  } = loadPreviewState("http://bonfire.test/post/01TEST", { previewElement });

  const session = previewState.save(
    "http://bonfire.test/feed/local",
    "/post/01TEST",
    42
  );
  history.state = previewState.historyState(session);

  const hook = previewContainerHook(PreviewContainer);
  hook.mounted();
  assert.equal(hook.pushedEvents.length, 0);

  // The browser pops back to the feed entry.
  location.href = session.entryUrl;
  history.state = { type: "redirect", position: 3 };
  windowEvents.dispatch("popstate", { state: history.state });

  assert.equal(previewElement.style.display, "none");
  assert.equal(previewElement.getAttribute("data-show"), "false");
  assert.deepEqual(
    JSON.parse(JSON.stringify(hook.pushedEvents)),
    [{ target: "#preview_content", event: "close", params: {} }]
  );
  assert.equal(location.reloaded, undefined);
  assert.equal(history.backCalls, 0);

  runPendingTimers(timers);
  assert.equal(sessionStorage.getItem(previewState.storageKey), null);
});

test("Escape closes a visible overlay and consumes its history entry", () => {
  const previewElement = makePreviewElement("block");
  const {
    PreviewContainer,
    history,
    previewState,
    documentEvents
  } = loadPreviewState("http://bonfire.test/post/01TEST", { previewElement });

  const session = previewState.save(
    "http://bonfire.test/feed/local",
    "/post/01TEST",
    0
  );
  history.state = previewState.historyState(session);

  const hook = previewContainerHook(PreviewContainer);
  hook.mounted();

  // A prevented Escape (widget inside the preview) must not close it.
  documentEvents.dispatch("keydown", { key: "Escape", defaultPrevented: true });
  assert.equal(previewElement.style.display, "block");

  documentEvents.dispatch("keydown", { key: "Escape", defaultPrevented: false });

  assert.equal(previewElement.style.display, "none");
  assert.equal(history.backCalls, 1);
  assert.deepEqual(
    JSON.parse(JSON.stringify(hook.pushedEvents)),
    [{ target: "#preview_content", event: "close", params: {} }]
  );
});

test("dead same-URL pop onto an orphaned entry consumes it", () => {
  const previewElement = makePreviewElement("none");
  const { history, location, previewState, windowEvents } = loadPreviewState(
    "http://bonfire.test/post/01TEST",
    { previewElement }
  );

  const session = previewState.save(
    "http://bonfire.test/feed/local",
    "/post/01TEST",
    0
  );

  // The pop lands on the marked entry without changing the URL and with no
  // overlay showing: the swipe would otherwise be a dead gesture.
  windowEvents.dispatch("popstate", { state: previewState.historyState(session) });

  assert.equal(history.backCalls, 1);
  assert.equal(location.reloaded, undefined);
});

test("cross-URL pop onto a marked entry strips the marker instead of recovering", () => {
  const previewElement = makePreviewElement("none");
  const {
    history,
    location,
    previewState,
    sessionStorage,
    windowEvents
  } = loadPreviewState("http://bonfire.test/other/page", { previewElement });

  const session = previewState.save(
    "http://bonfire.test/feed/local",
    "/post/01TEST",
    0
  );
  const marked = previewState.historyState(session);

  // Simulate traversal: the URL changes to the marked entry's URL.
  location.href = session.previewUrl;
  history.state = marked;
  windowEvents.dispatch("popstate", { state: marked });

  assert.equal(history.backCalls, 0);
  assert.equal(location.reloaded, undefined);
  assert.equal(history.state.bonfirePreview, undefined);
  assert.equal(sessionStorage.getItem(previewState.storageKey), null);
});

test("reconnect with the trigger present re-opens the preview once", () => {
  const previewElement = makePreviewElement("block");
  const trigger = {
    getAttribute() {
      return "/post/01TEST";
    }
  };
  const {
    PreviewContainer,
    history,
    location,
    previewState
  } = loadPreviewState("http://bonfire.test/post/01TEST", {
    previewElement,
    triggers: () => [trigger]
  });

  const session = previewState.save(
    "http://bonfire.test/feed/local",
    "/post/01TEST",
    42
  );
  history.state = previewState.historyState(session);

  const hook = previewContainerHook(PreviewContainer);
  hook.mounted();
  hook.reconnected();

  assert.equal(hook.pushedEvents.length, 1);
  assert.equal(hook.pushedEvents[0].target, trigger);
  assert.equal(hook.pushedEvents[0].event, "open");
  assert.deepEqual(
    JSON.parse(JSON.stringify(hook.pushedEvents[0].params)),
    {
      previous_url: session.entryUrl,
      previous_scroll: 42
    }
  );
  assert.equal(location.reloaded, undefined);
});

test("reconnect without a trigger settles on the real page without reloading", () => {
  const previewElement = makePreviewElement("block");
  const {
    PreviewContainer,
    history,
    location,
    previewState,
    sessionStorage
  } = loadPreviewState("http://bonfire.test/post/01TEST", { previewElement });

  const session = previewState.save(
    "http://bonfire.test/feed/local",
    "/post/01TEST",
    0
  );
  history.state = previewState.historyState(session);

  const hook = previewContainerHook(PreviewContainer);
  hook.mounted();
  hook.reconnected();

  assert.equal(previewElement.style.display, "none");
  assert.equal(history.state.bonfirePreview, undefined);
  assert.equal(sessionStorage.getItem(previewState.storageKey), null);
  assert.equal(location.reloaded, undefined);
  assert.equal(location.href, session.previewUrl);
});

test("server re-rendering a client-closed overlay gets re-hidden and re-notified", () => {
  const previewElement = makePreviewElement("none");
  const { PreviewContainer } = loadPreviewState(
    "http://bonfire.test/feed/local",
    { previewElement }
  );

  const hook = previewContainerHook(PreviewContainer);
  hook.mounted();
  assert.equal(hook.pushedEvents.length, 0);

  // A stale server render flips the overlay visible after the client closed it.
  previewElement.style.display = "block";
  hook.updated();

  assert.equal(previewElement.style.display, "none");
  assert.deepEqual(
    JSON.parse(JSON.stringify(hook.pushedEvents)),
    [{ target: "#preview_content", event: "close", params: {} }]
  );
});
