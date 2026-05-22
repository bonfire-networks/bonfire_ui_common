import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const hookUrl = new URL("../../lib/components/modals/preview_content_live.hooks.js", import.meta.url);
const hookSource = fs.readFileSync(hookUrl, "utf8");

function loadPreviewState(currentHref = "http://bonfire.test/feed/local") {
  const store = new Map();
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
    JSON,
    Number,
    URL,
    clearTimeout,
    history: { state: null },
    location,
    parseInt,
    sessionStorage,
    setTimeout,
    window: {
      addEventListener() {},
      getSelection() {
        return { toString: () => "" };
      },
      location
    }
  };

  context.globalThis = context;

  const runnableSource = hookSource.replace(
    /export\s+\{[^}]+\};\s*$/,
    "globalThis.__previewState = previewState;"
  );

  vm.runInNewContext(runnableSource, context, {
    filename: hookUrl.pathname
  });

  return {
    previewState: context.__previewState,
    sessionStorage,
    store,
    window: context.window
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
