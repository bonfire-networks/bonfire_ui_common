import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const hookUrl = new URL(
  "../../lib/components/settings/custom_theme_colour_live.hooks.js",
  import.meta.url
);
const hookSource = fs.readFileSync(hookUrl, "utf8");

class FakeElement {
  constructor() {
    this.listeners = new Map();
  }

  addEventListener(type, listener) {
    if (!this.listeners.has(type)) this.listeners.set(type, new Set());
    this.listeners.get(type).add(listener);
  }

  removeEventListener(type, listener) {
    this.listeners.get(type)?.delete(listener);
  }

  dispatch(type, event = {}) {
    for (const listener of this.listeners.get(type) || []) {
      listener({ currentTarget: this, target: this, ...event });
    }
  }
}

function loadColourPicker() {
  const context = {
    CSS: { supports: (_property, value) => /^#[0-9a-f]{6}$/i.test(value) },
    document: {
      createElement() {
        return {
          getContext() {
            return {
              clearRect() {},
              fillRect() {},
              fillStyle: "#000000",
              getImageData() {
                return { data: [18, 52, 86, 255] };
              }
            };
          }
        };
      }
    },
    getComputedStyle() {
      return { getPropertyValue: () => "#123456" };
    }
  };
  context.globalThis = context;

  const runnableSource = hookSource
    .replace(/^import .*$/gm, "")
    .replace(
      /export\s+\{[^}]+\};\s*$/,
      "globalThis.__ColourPicker = ColourPicker;"
    );

  vm.runInNewContext(runnableSource, context, { filename: hookUrl.pathname });
  return context.__ColourPicker;
}

test("Apply pushes the selected custom colour through the LiveView hook", () => {
  const root = new FakeElement();
  const controls = pickerControls(root);
  const pushes = [];

  root.dataset = {
    colorKey: "color-primary",
    savedColor: "#123456",
    scope: "user"
  };
  root.querySelector = (selector) => controls[selector] || null;

  const hook = {
    ...loadColourPicker(),
    el: root,
    pushEvent(name, payload) {
      pushes.push({ name, payload });
    }
  };

  hook.mounted();
  controls["hex-input"].color = "#abcdef";
  controls["[data-role='apply_custom_color']"].dispatch("click");

  assert.equal(pushes.length, 1);
  assert.equal(pushes[0].name, "Bonfire.Common.Settings:put_custom_theme_token");
  assert.equal(pushes[0].payload.token, "color-primary");
  assert.equal(pushes[0].payload.value, "#abcdef");
  assert.equal(pushes[0].payload.scope, "user");
  assert.equal(pushes[0].payload.close_modal, true);
});

for (const savedColor of ["123456", "1193046", ""]) {
  test(`picker uses the normalized CSS colour for saved value ${JSON.stringify(savedColor)}`, () => {
    const root = new FakeElement();
    const controls = pickerControls(root);
    root.dataset = { colorKey: "color-primary", savedColor };
    root.querySelector = (selector) => controls[selector] || null;
    const hook = { ...loadColourPicker(), el: root };

    hook.mounted();

    assert.equal(controls["hex-input"].color, "#123456");
    assert.equal(controls["hex-color-picker"].color, "#123456");
    assert.equal(controls[".colour_preview"].style.backgroundColor, "#123456");
    hook.destroyed();
  });
}

test("updated rebinds listeners to replaced picker controls and destroyed removes them", () => {
  const root = new FakeElement();
  const pushes = [];
  const first = pickerControls(root);
  let controls = first;

  root.dataset = {
    colorKey: "color-primary",
    savedColor: "#123456",
    scope: "user"
  };
  root.querySelector = (selector) => controls[selector] || null;

  const hook = {
    ...loadColourPicker(),
    el: root,
    pushEvent(name, payload) {
      pushes.push({ name, payload });
    }
  };

  hook.mounted();

  const replacement = pickerControls(root);
  controls = replacement;
  hook.updated();

  replacement["hex-input"].color = "#abcdef";
  replacement["[data-role='apply_custom_color']"].dispatch("click");
  assert.equal(pushes.length, 1);

  first["[data-role='apply_custom_color']"].dispatch("click");
  assert.equal(pushes.length, 1);

  replacement["hex-color-picker"].dispatch("color-changed", {
    detail: { value: "#fedcba" }
  });
  assert.equal(replacement["hex-input"].color, "#fedcba");
  assert.equal(replacement[".colour_preview"].style.backgroundColor, "#fedcba");

  hook.destroyed();
  replacement["[data-role='apply_custom_color']"].dispatch("click");
  assert.equal(pushes.length, 1);
});

function pickerControls(root) {
  const applyButton = new FakeElement();
  applyButton.closest = (selector) =>
    selector === "[data-color-key]" ? root : null;

  return {
    "hex-color-picker": new FakeElement(),
    "hex-input": new FakeElement(),
    ".colour_preview": { style: {} },
    "[data-role='apply_custom_color']": applyButton
  };
}
