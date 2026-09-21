import assert from "node:assert/strict";
import test from "node:test";

// The module reads `window.localStorage` inside its functions, so a fake store in place before the
// first call is enough, and it can be imported as it stands.
class FakeStorage {
  constructor() {
    this.map = new Map();
  }
  get length() {
    return this.map.size;
  }
  key(i) {
    return [...this.map.keys()][i] ?? null;
  }
  getItem(key) {
    return this.map.has(key) ? this.map.get(key) : null;
  }
  setItem(key, value) {
    this.map.set(key, String(value));
  }
  removeItem(key) {
    this.map.delete(key);
  }
}

let storage;
globalThis.window = {
  get localStorage() {
    return storage;
  },
};

const { setBonfireParam, getBonfireParam, collectBonfireParams } = await import(
  "../../assets/js/local_storage_params.js"
);

// what a stored entry looks like, so a test can write one the writer never would
function writeRaw(key, value, { expires = Date.now() + 60000, last_touched } = {}) {
  storage.setItem(key, JSON.stringify({ value, expires, last_touched }));
}

test.beforeEach(() => {
  storage = new FakeStorage();
});

test("a reading position travels with when it was written, since the server keeps the furthest", () => {
  setBonfireParam("reading_pos", "my", "01ABC");

  const params = collectBonfireParams();

  assert.equal(params.reading_pos.my.value, "01ABC");
  assert.ok(Number.isFinite(params.reading_pos.my.last_touched));
});

test("a push state travels as the bare boolean it is", () => {
  setBonfireParam("push", "active", true);
  assert.deepEqual(collectBonfireParams().push, { active: true });

  setBonfireParam("push", "active", false);
  assert.deepEqual(collectBonfireParams().push, { active: false });
});

test("a push state of the wrong type is dropped rather than sent", () => {
  writeRaw("bonfire:push:active", "true");

  assert.deepEqual(collectBonfireParams(), {});
  assert.equal(storage.getItem("bonfire:push:active"), null, "and the bad entry is evicted");
  assert.equal(getBonfireParam("push", "active"), null);
});

test("a reading position of the wrong type is dropped too, by the same rule", () => {
  writeRaw("bonfire:reading_pos:my", 42);

  assert.deepEqual(collectBonfireParams(), {});
});

test("a namespace nobody allowlisted stays on the client", () => {
  writeRaw("bonfire:debug:push", true);
  storage.setItem("bonfire:notjson", "{");

  assert.deepEqual(collectBonfireParams(), {});
  assert.equal(
    storage.getItem("bonfire:debug:push"),
    JSON.stringify({ value: true, expires: JSON.parse(storage.getItem("bonfire:debug:push")).expires }),
    "an unlisted key is ignored rather than evicted: it is not ours to clear",
  );
});

test("an expired entry is evicted instead of sent", () => {
  writeRaw("bonfire:push:active", true, { expires: Date.now() - 1 });

  assert.deepEqual(collectBonfireParams(), {});
  assert.equal(storage.getItem("bonfire:push:active"), null);
});
