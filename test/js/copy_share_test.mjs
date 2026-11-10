import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = fs.readFileSync(new URL("../../assets/js/copy.js", import.meta.url), "utf8")
  .replace("export { CopyHooks };", "globalThis.hooks = CopyHooks;");

// loads copy.js and mounts the Copy hook on a fake element; `share` is what navigator.share does, or undefined when the browser has none
function mount({ dataset, share }) {
  const calls = { shared: [], copied: [] };
  const rootClasses = new Set();
  let click;
  const el = {
    dataset,
    getAttribute: () => null,
    querySelector: () => null,
    setAttribute() {},
    removeAttribute() {},
    classList: { add() {}, remove() {} },
    addEventListener: (name, fn) => { if (name === "click") click = fn; },
  };
  const navigator = {
    clipboard: { writeText: (text) => { calls.copied.push(text); return Promise.resolve(); } },
  };
  if (share) navigator.share = (data) => { calls.shared.push({ ...data }); return share(); };

  const document = {
    getElementById: () => null,
    documentElement: { classList: { add: (name) => rootClasses.add(name) } },
  };
  const context = { navigator, document, console: { log() {} }, setTimeout };
  vm.runInNewContext(source, context);
  const hook = Object.create(context.hooks.Copy);
  hook.el = el;
  hook.flash = () => {};
  hook.mounted();
  return { rootClasses, calls, click: () => click({ preventDefault() {} }) };
}

const settle = () => new Promise((r) => setTimeout(r, 0));
const row = { share: "", clipboardText: "https://example.com/post/1" };

test("with a share sheet, <html> gets can-share (CSS shows the Share label) and tapping shares the link", () => {
  const { rootClasses, calls, click } = mount({ dataset: row, share: () => Promise.resolve() });

  assert.ok(rootClasses.has("can-share"));
  click();
  assert.deepEqual(calls.shared, [{ url: "https://example.com/post/1" }]);
  assert.deepEqual(calls.copied, []);
});

test("without a share sheet, no can-share and tapping copies", () => {
  const { rootClasses, calls, click } = mount({ dataset: row });

  assert.ok(!rootClasses.has("can-share"));
  click();
  assert.deepEqual(calls.copied, ["https://example.com/post/1"]);
});

test("without data-share, it copies even where the browser can share", () => {
  const { calls, click } = mount({
    dataset: { clipboardText: "https://example.com/feed.rss" },
    share: () => Promise.resolve(),
  });

  click();
  assert.deepEqual(calls.shared, []);
  assert.deepEqual(calls.copied, ["https://example.com/feed.rss"]);
});

test("dismissing the share sheet doesn't copy", async () => {
  const abort = Object.assign(new Error("dismissed"), { name: "AbortError" });
  const { calls, click } = mount({ dataset: row, share: () => Promise.reject(abort) });

  click();
  await settle();
  assert.deepEqual(calls.copied, []);
});

test("a share that fails for another reason copies the link instead", async () => {
  const refused = Object.assign(new Error("refused"), { name: "NotAllowedError" });
  const { calls, click } = mount({ dataset: row, share: () => Promise.reject(refused) });

  click();
  await settle();
  assert.deepEqual(calls.copied, ["https://example.com/post/1"]);
});
