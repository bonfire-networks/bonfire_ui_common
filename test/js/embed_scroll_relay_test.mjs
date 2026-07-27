import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const uiCommon = new URL("../../", import.meta.url);
const pinsLoaderUrl = new URL("assets/static/js/pins_embed.js", uiCommon);
const commentsLoaderUrl = new URL("assets/static/js/comments_embed.js", uiCommon);

function loadEmbedLoader(loaderUrl, options = {}) {
  const messageListeners = [];
  const animationFrameCalls = [];
  const scrollCalls = [];
  const iframeWindow = {};
  const parent = {
    insertBefore(node) {
      node.parentElement = parent;
      this.iframe = node;
    },
    clientHeight: 100,
    parentElement: null,
    scrollHeight: 100
  };
  const attributes = {
    "data-variant": options.variant,
    "data-media-uri": "http://ghost.test/article/"
  };
  const script = {
    src: "http://bonfire.test/js/" + loaderUrl.pathname.split("/").pop(),
    getAttribute(name) {
      return attributes[name] || null;
    },
    parentNode: parent
  };
  const document = {
    body: {},
    currentScript: script,
    documentElement: {},
    createElement() {
      return {
        contentWindow: iframeWindow,
        setAttribute() {},
        style: {}
      };
    }
  };
  const window = {
    addEventListener(type, listener) {
      if (type === "message") messageListeners.push(listener);
    },
    getComputedStyle() {
      return { overflowY: "visible" };
    },
    localStorage: {
      getItem() {
        return null;
      },
      removeItem() {},
      setItem() {}
    },
    location: {
      hash: "",
      href: "http://ghost.test/article/?preview=secret#comments",
      origin: "http://ghost.test",
      pathname: "/article/",
      search: ""
    },
    requestAnimationFrame(callback) {
      animationFrameCalls.push(true);
      callback();
    },
    scrollBy(x, y) {
      scrollCalls.push([x, y]);
    }
  };
  const context = {
    Date,
    JSON,
    Number,
    URL,
    URLSearchParams,
    document,
    history: { replaceState() {} },
    parseInt,
    window
  };

  vm.runInNewContext(fs.readFileSync(loaderUrl, "utf8"), context, {
    filename: loaderUrl.pathname
  });

  return {
    animationFrameCalls,
    iframe: parent.iframe,
    iframeWindow,
    messageListeners,
    scrollCalls
  };
}

test("pins_embed.js authenticates and immediately relays carousel scrolling", () => {
  const loaded = loadEmbedLoader(pinsLoaderUrl, { variant: "carousel" });
  const iframeUrl = new URL(loaded.iframe.src);

  assert.equal(iframeUrl.searchParams.get("scroll_relay"), "1");
  assert.equal(iframeUrl.searchParams.get("embed_parent"), "http://ghost.test");

  loaded.messageListeners[0]({
    data: { type: "bonfire:iframe-scroll", deltaY: 24 },
    origin: "http://evil.test",
    source: loaded.iframeWindow
  });
  loaded.messageListeners[0]({
    data: { type: "bonfire:iframe-scroll", deltaY: 24 },
    origin: "http://bonfire.test",
    source: {}
  });
  assert.deepEqual(loaded.scrollCalls, []);

  loaded.messageListeners[0]({
    data: { type: "bonfire:iframe-scroll", deltaY: 24 },
    origin: "http://bonfire.test",
    source: loaded.iframeWindow
  });
  loaded.messageListeners[0]({
    data: { type: "bonfire:iframe-scroll", deltaY: 999 },
    origin: "http://bonfire.test",
    source: loaded.iframeWindow
  });
  assert.deepEqual(loaded.scrollCalls, [[0, 24], [0, 120]]);
  assert.equal(loaded.animationFrameCalls.length, 0);
});

test("pins_embed.js leaves the non-carousel variant out of the scroll relay", () => {
  const loaded = loadEmbedLoader(pinsLoaderUrl);
  const iframeUrl = new URL(loaded.iframe.src);

  assert.equal(iframeUrl.searchParams.has("scroll_relay"), false);
  assert.equal(iframeUrl.searchParams.has("embed_parent"), false);

  loaded.messageListeners[0]({
    data: { type: "bonfire:iframe-scroll", deltaY: 24 },
    origin: "http://bonfire.test",
    source: loaded.iframeWindow
  });
  assert.deepEqual(loaded.scrollCalls, []);
});

test("comments_embed.js enables and authenticates relayed scrolling", () => {
  const loaded = loadEmbedLoader(commentsLoaderUrl);
  const iframeUrl = new URL(loaded.iframe.src);

  assert.equal(iframeUrl.searchParams.get("scroll_relay"), "1");
  assert.equal(
    iframeUrl.searchParams.get("embed_parent"),
    "http://ghost.test/article/?preview=secret#comments"
  );

  loaded.messageListeners[0]({
    data: { type: "bonfire:iframe-scroll", deltaY: 24 },
    origin: "http://evil.test",
    source: loaded.iframeWindow
  });
  loaded.messageListeners[0]({
    data: { type: "bonfire:iframe-scroll", deltaY: 24 },
    origin: "http://bonfire.test",
    source: {}
  });
  assert.deepEqual(loaded.scrollCalls, []);

  loaded.messageListeners[0]({
    data: { type: "bonfire:iframe-scroll", deltaY: 24 },
    origin: "http://bonfire.test",
    source: loaded.iframeWindow
  });
  assert.deepEqual(loaded.scrollCalls, [[0, 24]]);
  assert.equal(loaded.animationFrameCalls.length, 1);
});

function loadChildRelay(options = {}) {
  const layoutUrl = new URL("lib/layout/iframe.html.heex", uiCommon);
  const layout = fs.readFileSync(layoutUrl, "utf8");
  const match = layout.match(/<script data-scroll-relay>([\s\S]*?)<\/script>/);
  assert.ok(match, "iframe layout includes the embed scroll relay");

  const listeners = new Map();
  const messages = [];
  const document = {
    body: {},
    documentElement: {},
    addEventListener(type, listener) {
      listeners.set(type, listener);
    }
  };
  const window = {
    __bonfireEmbedParentOrigin:
      options.parentOrigin === undefined ? "http://ghost.test" : options.parentOrigin,
    getComputedStyle() {
      return { overflowY: "visible" };
    },
    location: { search: options.search === undefined ? "?scroll_relay=1" : options.search },
    parent: {
      postMessage(message, origin) {
        messages.push({ message, origin });
      }
    }
  };

  vm.runInNewContext(match[1], {
    Math,
    URLSearchParams,
    document,
    window
  });

  return { listeners, messages };
}

test("child relay requires both loader opt-in and a verified parent origin", () => {
  assert.equal(loadChildRelay({ search: "" }).listeners.size, 0);
  assert.equal(loadChildRelay({ parentOrigin: null }).listeners.size, 0);
});

test("child relay locks vertical movement but leaves horizontal movement alone", () => {
  const { listeners, messages } = loadChildRelay();
  const target = { nodeType: 1, parentElement: null };
  const touchEvent = (clientX, clientY, screenX = clientX, screenY = clientY) => ({
    cancelable: true,
    preventDefault() {
      this.defaultPrevented = true;
    },
    target,
    touches: [{ clientX, clientY, screenX, screenY }]
  });

  listeners.get("touchstart")(touchEvent(50, 50));
  // Safari may report screen coordinates differently from the client-space
  // coordinates used by the carousel. Client movement must own intent locking.
  const horizontalMove = touchEvent(70, 48, 50, 30);
  listeners.get("touchmove")(horizontalMove);
  assert.equal(horizontalMove.defaultPrevented, undefined);
  assert.deepEqual(messages, []);

  listeners.get("touchend")();
  listeners.get("touchstart")(touchEvent(50, 50));
  const verticalMove = touchEvent(52, 30, 52, 30);
  listeners.get("touchmove")(verticalMove);

  // Parent scrolling moves the iframe viewport, so clientY can remain unchanged
  // even though the finger moved on the physical screen.
  const continuedVerticalMove = touchEvent(52, 30, 52, 20);
  listeners.get("touchmove")(continuedVerticalMove);

  assert.equal(verticalMove.defaultPrevented, true);
  assert.equal(continuedVerticalMove.defaultPrevented, true);
  assert.deepEqual(JSON.parse(JSON.stringify(messages)), [
    {
      message: { type: "bonfire:iframe-scroll", deltaY: 20 },
      origin: "http://ghost.test"
    },
    {
      message: { type: "bonfire:iframe-scroll", deltaY: 10 },
      origin: "http://ghost.test"
    }
  ]);
});
