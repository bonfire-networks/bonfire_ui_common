import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = fs.readFileSync(new URL("../../assets/js/tooltip.js", import.meta.url), "utf8")
  .replace(/import[\s\S]*?from "[^"]+";/g, "")
  .replace("export { TooltipHooks };", "globalThis.hooks = TooltipHooks;");

function mountDropdown({ bounded = false, sheet = false, narrow = false } = {}) {
  const boundary = {};
  let middleware;
  let resize;
  let disconnected = false;
  let focused;
  let positions = 0;
  function element(attrs = {}) {
    const listeners = new Map();
    const classes = new Set();
    return {
      style: { setProperty(name, value) { this[name] = value; } },
      classList: {
        add: (...names) => names.forEach(name => classes.add(name)),
        remove: (...names) => names.forEach(name => classes.delete(name)),
        contains: name => classes.has(name),
      },
      getAttribute: name => attrs[name] ?? null,
      setAttribute: (name, value) => { attrs[name] = value; },
      hasAttribute: name => name in attrs,
      removeAttribute: name => { delete attrs[name]; },
      addEventListener: (name, fn) => listeners.set(name, fn),
      removeEventListener: name => listeners.delete(name),
      dispatch: (name, event = {}) => listeners.get(name)?.(event),
      focus() { focused = this; },
      contains(target) { return target === this; },
      closest() { return null; },
      querySelector() { return null; },
    };
  }
  const button = element({ "aria-expanded": "false" });
  const search = element();
  const option = element();
  option.closest = () => option;
  const panel = element();
  panel.contains = target => [panel, search, option].includes(target);
  panel.querySelector = selector => selector === "#search" ? search : null;
  // the top layer, as far as the hook can see it
  let popoverOpen = false;
  panel.showPopover = () => { popoverOpen = true; };
  panel.hidePopover = () => { popoverOpen = false; };
  panel.matches = selector => selector === ":popover-open" && popoverOpen;
  panel.getBoundingClientRect = () => ({ top: 500 });
  const root = element({ "data-trigger": "click", "data-close-on-inside-click": "true", "data-focus-on-open": "#search" });
  if (bounded) root.setAttribute("data-boundary", "#composer_container");
  if (sheet) root.setAttribute("data-sheet-on-mobile", "true");
  root.closest = selector => selector === "#composer_container" ? boundary : null;
  root.querySelector = selector => selector === ".tooltip-button" ? button : panel;
  const document = element();
  const window = {};
  window.parent = window;
  window.matchMedia = () => ({ matches: narrow });
  document.documentElement = { style: {} };
  const context = {
    console, document, window, setTimeout, clearTimeout,
    prefersReducedMotion: () => true,
    flip: options => ({name: "flip", options}), shift: options => ({name: "shift", options}), offset() {},
    size: options => ({name: "size", options}),
    ResizeObserver: class { constructor(callback) { resize = callback; } observe(target) { assert.equal(target, boundary); } disconnect() { disconnected = true; } },
    autoUpdate(_button, _panel, update) { update(); return () => {}; },
    computePosition(_button, _panel, options) { middleware = options.middleware; positions++; return Promise.resolve({ x: 10, y: 20, placement: "bottom-start" }); },
  };
  vm.runInNewContext(source, context);
  const hook = { ...context.hooks.Tooltip, el: root };
  hook.mounted();
  return {
    hook, button, search, option, panel, document, boundary,
    middleware: () => middleware, resize: () => resize(), observed: () => resize !== undefined,
    disconnected: () => disconnected,
    focused: () => focused, positions: () => positions, popoverOpen: () => popoverOpen,
    async open() { button.dispatch("click"); await Promise.resolve(); },
    async patch() {
      hook.beforeUpdate();
      // A server render contains neither the hook's inline styles nor open classes.
      panel.style = {};
      panel.classList.remove("tooltip-animated", "tooltip-visible");
      button.setAttribute("aria-expanded", "false");
      hook.updated();
      await Promise.resolve();
    },
  };
}

test("filter results preserve the open panel, search focus and positioning", async () => {
  const ui = mountDropdown();
  await ui.open();
  assert.equal(ui.focused(), ui.search);
  const positions = ui.positions();
  await ui.patch();
  assert.equal(ui.panel.style.display, "block");
  assert.equal(ui.button.getAttribute("aria-expanded"), "true");
  assert.equal(ui.focused(), ui.search);
  assert.ok(ui.positions() > positions);
  ui.option.focus();
  await ui.patch();
  assert.equal(ui.focused(), ui.option, "a refresh must not steal keyboard focus");
  ui.hook.destroyed();
});

for (const action of ["selection", "escape", "outside"]) {
  test(`${action} closes the panel and a subsequent patch does not reopen it`, async () => {
    const ui = mountDropdown();
    await ui.open();
    if (action === "selection") ui.panel.dispatch("click", { target: ui.option });
    if (action === "escape") ui.document.dispatch("keydown", { key: "Escape", stopPropagation() {} });
    if (action === "outside") ui.document.dispatch("click", { target: {} });
    assert.notEqual(ui.panel.style.display, "block");
    await ui.patch();
    assert.notEqual(ui.panel.style.display, "block");
    assert.equal(ui.button.getAttribute("aria-expanded"), "false");
    ui.hook.destroyed();
  });
}

test("clicking the search input leaves the panel open", async () => {
  const ui = mountDropdown();
  await ui.open();
  ui.panel.dispatch("click", { target: ui.search });
  assert.equal(ui.panel.style.display, "block");
  ui.hook.destroyed();
});

test("menus without a boundary keep their previous positioning", async () => {
  const ui = mountDropdown();
  await ui.open();
  // copied out of the vm sandbox, whose arrays and objects have their own prototypes
  const middleware = [...ui.middleware().filter(Boolean)];
  assert.deepEqual(middleware.map(item => item.name), ["flip", "shift"]);
  for (const item of middleware) assert.deepEqual({ ...item.options }, { padding: 5 });
  assert.equal(ui.observed(), false, "only bounded menus observe a container");
  assert.equal(ui.panel.style.maxHeight, undefined);
  ui.hook.destroyed();
});

test("bounded menus size to available space and update when their container resizes", async () => {
  const ui = mountDropdown({ bounded: true });
  await ui.open();
  const sizing = ui.middleware().find(item => item?.name === "size");
  assert.ok(sizing, "bounded menus need available-space sizing");
  for (const item of ui.middleware().filter(item => item?.options)) {
    assert.equal(item.options.boundary, ui.boundary);
  }
  sizing.options.apply({ availableHeight: 180, availableWidth: 250, elements: { floating: ui.panel } });
  assert.equal(ui.panel.style.maxHeight, "180px");
  assert.equal(ui.panel.style.maxWidth, "250px");
  assert.equal(ui.panel.style["--dropdown-available-height"], "180px");
  const positions = ui.positions();
  ui.resize();
  assert.ok(ui.positions() > positions);
  ui.hook.destroyed();
  assert.equal(ui.disconnected(), true);
});

test("a sheet-on-mobile menu opens as a bottom sheet on a narrow screen, without positioning", async () => {
  const ui = mountDropdown({ sheet: true, narrow: true });
  await ui.open();
  assert.equal(ui.popoverOpen(), true);
  assert.equal(ui.panel.classList.contains("dropdown-sheet"), true);
  assert.equal(ui.panel.style.display, "block");
  assert.equal(ui.button.getAttribute("aria-expanded"), "true");
  assert.equal(ui.positions(), 0, "a sheet is placed by CSS, not Floating UI");
  ui.hook.destroyed();
});

test("a sheet-on-mobile menu keeps the floating panel on a wide screen", async () => {
  const ui = mountDropdown({ sheet: true, narrow: false });
  await ui.open();
  assert.equal(ui.popoverOpen(), false);
  assert.equal(ui.panel.classList.contains("dropdown-sheet"), false);
  assert.ok(ui.positions() > 0);
  ui.hook.destroyed();
});

test("a tap on the sheet's backdrop closes it; a tap inside does not", async () => {
  const ui = mountDropdown({ sheet: true, narrow: true });
  await ui.open();
  // both target the panel: a ::backdrop tap reports the popover itself
  ui.document.dispatch("click", { target: ui.panel, clientY: 600 });
  assert.equal(ui.popoverOpen(), true);
  ui.document.dispatch("click", { target: ui.panel, clientY: 100 });
  assert.equal(ui.popoverOpen(), false);
  assert.equal(ui.panel.hasAttribute("popover"), false);
  assert.equal(ui.panel.classList.contains("dropdown-sheet"), false);
  assert.notEqual(ui.panel.style.display, "block");
  ui.hook.destroyed();
});
