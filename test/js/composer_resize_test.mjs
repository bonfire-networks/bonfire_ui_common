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
