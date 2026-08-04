import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const hookUrl = new URL("../../lib/components/modals/preview_content_live.hooks.js", import.meta.url);
const hookSource = fs.readFileSync(hookUrl, "utf8");

function loadPreviewState(
  currentHref = "http://bonfire.test/feed/local",
  { document: documentOverride, performance: performanceOverride } = {}
) {
  const store = new Map();
  const timers = new Map();
  const mutationObservers = [];
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
    }
  };
  const document = documentOverride || {
    body: {},
    documentElement: {},
    querySelector() {
      return null;
    },
    querySelectorAll() {
      return [];
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
      addEventListener() {},
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
    window: context.window
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

test("stores one same-origin JSON session and builds preview history state", () => {
  const { previewState, sessionStorage } = loadPreviewState();

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

test("reconnect waits for a late preview trigger instead of reloading", () => {
  let trigger = null;
  const previewAttributes = new Map([["data-show", "false"]]);
  const previewElement = {
    getAttribute(name) {
      return previewAttributes.get(name) || null;
    },
    setAttribute(name, value) {
      previewAttributes.set(name, String(value));
    },
    hasAttribute(name) {
      return previewAttributes.has(name);
    },
    removeAttribute(name) {
      previewAttributes.delete(name);
    },
    querySelector() {
      return null;
    },
    style: { display: "none" }
  };
  const document = {
    body: {},
    documentElement: {},
    querySelector(selector) {
      if (selector === "#preview_content") return previewElement;
      return null;
    },
    querySelectorAll() {
      return trigger ? [trigger] : [];
    },
    getElementById() {
      return null;
    }
  };
  const {
    PreviewContainer,
    history,
    location,
    mutationObservers,
    previewState
  } = loadPreviewState("http://bonfire.test/post/01TEST", { document });
  const session = previewState.save(
    "http://bonfire.test/feed/local",
    "/post/01TEST",
    42
  );
  history.state = previewState.historyState(session);
  const hook = previewContainerHook(PreviewContainer);

  hook.mounted();

  assert.equal(mutationObservers.length, 1);
  assert.equal(location.reloaded, undefined);
  assert.equal(location.href, session.previewUrl);

  trigger = {
    getAttribute() {
      return "/post/01TEST";
    }
  };
  mutationObservers[0].callback();

  assert.equal(mutationObservers[0].disconnected, true);
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

test("back navigation wins while reconnect recovery is waiting", () => {
  const document = {
    body: {},
    documentElement: {},
    querySelector() {
      return null;
    },
    querySelectorAll() {
      return [];
    },
    getElementById() {
      return null;
    }
  };
  const {
    PreviewContainer,
    history,
    location,
    mutationObservers,
    previewState
  } = loadPreviewState("http://bonfire.test/post/01TEST", { document });
  const session = previewState.save(
    "http://bonfire.test/feed/local",
    "/post/01TEST",
    0
  );
  history.state = previewState.historyState(session);
  const hook = previewContainerHook(PreviewContainer);

  hook.mounted();
  location.href = session.entryUrl;
  history.state = { type: "patch" };
  mutationObservers[0].callback();

  assert.equal(mutationObservers[0].disconnected, true);
  assert.equal(hook.pushedEvents.length, 0);
  assert.equal(history.backCalls, 0);
  assert.equal(location.reloaded, undefined);
});

test("unrecoverable preview consumes its history entry without reloading", () => {
  const document = {
    body: {},
    documentElement: {
      scrollHeight: 0,
      clientHeight: 0
    },
    querySelector() {
      return null;
    },
    querySelectorAll() {
      return [];
    },
    getElementById() {
      return null;
    }
  };
  const {
    PreviewContainer,
    history,
    location,
    previewState,
    sessionStorage,
    timers
  } = loadPreviewState("http://bonfire.test/post/01TEST", { document });
  const session = previewState.save(
    "http://bonfire.test/feed/local",
    "/post/01TEST",
    0
  );
  history.state = previewState.historyState(session);
  const hook = previewContainerHook(PreviewContainer);

  hook.mounted();
  const recoveryTimer = Array.from(timers.values())[0];
  recoveryTimer();

  assert.equal(history.backCalls, 1);
  assert.equal(location.reloaded, undefined);
  assert.equal(location.href, session.previewUrl);
  assert.equal(sessionStorage.getItem(previewState.storageKey), null);
  assert.deepEqual(
    JSON.parse(JSON.stringify(hook.pushedEvents)),
    [{ target: "#preview_content", event: "close", params: {} }]
  );
});
