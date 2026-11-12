import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = fs.readFileSync(new URL("../../lib/components/smart_input/smart_input_container_live.hooks.js", import.meta.url), "utf8")
  .replace(/import[^;]+;/g, "")
  .replace("export default", "globalThis.hook =");

function setup() {
  const properties = new Map();
  const attributes = new Map();
  const listeners = new Map();
  const handle = {
    setAttribute: (key, value) => attributes.set(key, String(value)),
    closest: () => handle,
    setPointerCapture() {},
  };
  const fullscreenAttrs = new Map();
  const fullscreenButton = {
    dataset: { expandLabel: "Expand composer", restoreLabel: "Restore composer size" },
    setAttribute: (key, value) => fullscreenAttrs.set(key, String(value)),
    closest: selector => selector === "[data-role=composer_fullscreen]" ? fullscreenButton : null,
  };
  const window = {
    innerHeight: 900,
    addEventListener: (event, callback) => listeners.set(event, callback),
    removeEventListener: event => listeners.delete(event),
  };
  const el = {
    querySelector: selector => selector === "[data-role=composer_fullscreen]" ? fullscreenButton : handle,
    contains: target => target === handle || target === fullscreenButton,
    getBoundingClientRect: () => ({ height: 500 }),
    addEventListener: (event, callback) => listeners.set(event, callback),
    removeEventListener: event => listeners.delete(event),
  };
  const document = { documentElement: { dataset: {}, style: {
    setProperty: (key, value) => properties.set(key, value),
    removeProperty: key => properties.delete(key),
  } } };
  const context = { window, document };
  vm.runInNewContext(source, context);
  const hook = { ...context.hook, el, _isMobile: () => false };
  return { hook, window, properties, attributes, listeners, handle, fullscreenButton, fullscreenAttrs, root: document.documentElement };
}

test("resize handle supports keyboard bounds and survives a DOM patch", () => {
  const { hook, properties, attributes, listeners, handle } = setup();
  hook._setupResize();
  const key = value => listeners.get("keydown")({ target: handle, key: value, preventDefault() {} });
  key("ArrowUp");
  assert.equal(properties.get("--composer-desktop-height"), "524px");
  key("End");
  assert.equal(properties.get("--composer-desktop-height"), "868px");
  key("Home");
  assert.equal(properties.get("--composer-desktop-height"), "360px");
  attributes.clear();
  hook.updated();
  assert.equal(attributes.get("aria-valuenow"), "360");
});

test("pointer resizing clamps to the viewport and cleans up listeners", () => {
  const { hook, window, properties, listeners, handle } = setup();
  hook._setupResize();
  listeners.get("pointerdown")({ target: handle, button: 0, clientY: 400, pointerId: 1, preventDefault() {} });
  listeners.get("pointermove")({ clientY: 300, pointerId: 1 });
  assert.equal(properties.get("--composer-desktop-height"), "600px");
  listeners.get("pointerup")({ pointerId: 1 });
  listeners.get("pointermove")({ clientY: 0, pointerId: 1 });
  assert.equal(properties.get("--composer-desktop-height"), "600px");
  window.innerHeight = 400;
  listeners.get("resize")();
  assert.equal(properties.get("--composer-desktop-height"), "368px");
  hook._stopResize();
  assert.equal(listeners.size, 0);
  assert.equal(properties.has("--composer-desktop-height"), false);
});

test("mobile ignores desktop resize gestures", () => {
  const { hook, properties, listeners, handle } = setup();
  hook._isMobile = () => true;
  hook._setupResize();
  listeners.get("keydown")({ target: handle, key: "End", preventDefault() {} });
  listeners.get("pointerdown")({ target: handle, button: 0, clientY: 400, pointerId: 1, preventDefault() {} });
  listeners.get("pointermove")({ clientY: 100, pointerId: 1 });
  assert.equal(properties.size, 0);
});


test("fullscreen restores resized height and survives patches without changing draft state", () => {
  const { hook, listeners, handle, fullscreenButton, fullscreenAttrs, root, properties } = setup();
  hook._setupResize();
  listeners.get("keydown")({ target: handle, key: "ArrowUp", preventDefault() {} });
  listeners.get("click")({ target: fullscreenButton });
  assert.equal(root.dataset.composerFullscreen, "true");
  assert.equal(fullscreenAttrs.get("aria-label"), "Restore composer size");
  fullscreenAttrs.clear();
  hook.updated();
  assert.equal(fullscreenAttrs.get("aria-pressed"), "true");
  listeners.get("keydown")({ target: handle, key: "End", preventDefault() {} });
  listeners.get("click")({ target: fullscreenButton });
  assert.equal(root.dataset.composerFullscreen, undefined);
  assert.equal(properties.get("--composer-desktop-height"), "524px");
  assert.equal(fullscreenAttrs.get("aria-label"), "Expand composer");
  hook._stopResize();
  assert.equal(listeners.size, 0);
});

// Mobile keyboard: the hook reads window.visualViewport and writes the composer's position variables on the container
function setupViewport() {
  const style = new Map();
  let writes = 0;
  const vvListeners = new Map();
  const visualViewport = {
    height: 800,
    width: 390,
    scale: 1,
    offsetTop: 0,
    addEventListener: (event, callback) => vvListeners.set(event, callback),
    removeEventListener: event => vvListeners.delete(event),
  };
  const headerAttrs = new Set(["data-controls-open"]);
  const headerField = {};
  const header = { hasAttribute: name => headerAttrs.has(name), contains: el => el === headerField };
  const summaryAttrs = new Map([["aria-expanded", "true"]]);
  const summary = {};
  const root = { dataset: {}, style: { setProperty() {}, removeProperty() {} } };
  const document = {
    documentElement: root,
    activeElement: null,
    getElementById: id => ({ composer_header: header, composer_summary: summary })[id] || null,
  };
  const window = { visualViewport, addEventListener() {}, removeEventListener() {} };
  const context = { window, document };
  vm.runInNewContext(source, context);
  const el = { style: {
    getPropertyValue: key => style.get(key) || "",
    setProperty: (key, value) => { writes++; style.set(key, value); },
    removeProperty: key => { writes++; style.delete(key); },
  } };
  const js = () => ({
    removeAttribute: (target, name) => target === header && headerAttrs.delete(name),
    setAttribute: (target, name, value) => target === summary && summaryAttrs.set(name, value),
  });
  const hook = { ...context.hook, el, js, _isMobile: () => true };
  const move = (height, offsetTop = 0, { scale = 1, width = 390 } = {}) => {
    Object.assign(visualViewport, { height, offsetTop, scale, width });
    vvListeners.get("resize")();
  };
  return { hook, style, root, document, headerField, headerAttrs, summaryAttrs, move, writes: () => writes };
}

test("a hardware keyboard keeps the composer below the scrolled viewport top", () => {
  const { hook, style, root, move } = setupViewport();
  hook._startViewportSync();
  // only the small accessory bar: no keyboard, but iOS scrolled the visual viewport
  move(764, 36);
  assert.equal(style.get("--composer-top"), "36px");
  assert.equal(style.has("--composer-height"), false);
  assert.equal(style.has("--composer-pb"), false);
  assert.equal(root.dataset.composerKeyboard, undefined);
});

test("the keyboard variables are written once per change, on the container, and cleared on close", () => {
  const { hook, style, root, move, writes } = setupViewport();
  hook._startViewportSync();
  move(450);
  const afterOpen = writes();
  assert.deepEqual(Object.fromEntries(style), { "--composer-height": "800px", "--composer-top": "0px", "--composer-pb": "350px" });
  assert.equal(root.dataset.composerKeyboard, "true");
  move(450);
  move(450);
  assert.equal(writes(), afterOpen);
  move(800);
  assert.equal(style.size, 0);
  assert.equal(root.dataset.composerKeyboard, undefined);
});

test("a style cleared by something else is written again on the next event", () => {
  const { hook, style, move } = setupViewport();
  hook._startViewportSync();
  move(450);
  style.clear();
  move(450);
  assert.equal(style.get("--composer-pb"), "350px");
});

test("pinch zoom and rotation are not taken for a keyboard", () => {
  const { hook, style, root, move } = setupViewport();
  hook._startViewportSync();
  move(400, 120, { scale: 2 }); // 2x zoom: half the CSS height, same screen height
  assert.equal(style.size, 0);
  assert.equal(root.dataset.composerKeyboard, undefined);
  move(390, 0, { width: 800 }); // landscape
  assert.equal(style.size, 0);
  assert.equal(root.dataset.composerKeyboard, undefined);
});

test("the keyboard opening folds an expanded header back to its summary", () => {
  const { hook, move, headerAttrs, summaryAttrs } = setupViewport();
  hook._startViewportSync();
  move(450);
  assert.equal(headerAttrs.has("data-controls-open"), false);
  assert.equal(summaryAttrs.get("aria-expanded"), "false");
});

test("a keyboard opened by a field in the header (audience search) leaves the header open", () => {
  const { hook, move, document, headerField, headerAttrs } = setupViewport();
  hook._startViewportSync();
  document.activeElement = headerField;
  move(450);
  assert.equal(headerAttrs.has("data-controls-open"), true);
});
