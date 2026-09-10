import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

function checkContract(t, css) {
  const root = mkdtempSync(join(tmpdir(), "theme-contract-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const assets = join(root, "extensions/bonfire_ui_common/assets");
  mkdirSync(join(assets, "tests"), { recursive: true });
  mkdirSync(join(assets, "css"));
  mkdirSync(join(root, "priv/static/assets"), { recursive: true });
  copyFileSync(new URL("../../assets/tests/theme-build-contract.mjs", import.meta.url), join(assets, "tests/contract.mjs"));
  writeFileSync(join(assets, "css/app.css"), '@plugin "daisyui" { themes: false; }\n@plugin "daisyui/theme" { name: "dark"; }');
  writeFileSync(join(assets, "css/current_flavour_theme.css"), '@plugin "daisyui/theme" { name: "example"; }');
  writeFileSync(join(root, "priv/static/assets/bonfire_basic.css"), css);
  return spawnSync(process.execPath, [join(assets, "tests/contract.mjs")], { encoding: "utf8" });
}

for (const quote of ["", '"', "'"]) {
  test(`accepts selectors with ${quote || "no"} quotes`, (t) => {
    const result = checkContract(t, `[data-theme=${quote}dark${quote}]{} [data-theme=${quote}example${quote}]{}`);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /Theme contract verified: dark, example/);
  });
}

test("rejects a missing active-flavour theme", (t) => {
  const result = checkContract(t, '[data-theme="dark"]{}');
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Missing: example/);
});

test("rejects a leaked theme from another flavour", (t) => {
  const result = checkContract(t, '[data-theme="dark"]{} [data-theme=example]{} [data-theme=other]{}');
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Unexpected: other/);
});
