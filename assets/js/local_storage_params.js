// Utility for syncing allowlisted localStorage entries to the server via connect_params.
// This deliberately ignores unrelated `bonfire:*` keys such as client debug flags.
// Values are stored as { value: <any>, expires: <epoch_ms> }.

// Every namespace allowed to reach the server, with what it may hold and how it travels. One entry each, because adding a namespace used to mean editing three places: the allowlist, the value check, and the shaping in `collectBonfireParams`.
const SYNC_PARAM_NAMESPACES = {
  // How far somebody had read in a feed, per feed name.
  reading_pos: {
    valid: (value) => typeof value === "string",
    // The server keeps the furthest position, so it needs to know when this one was written.
    shape: (stored) => ({ value: stored.value, last_touched: lastTouched(stored) }),
  },
  // Whether push notifications work on this device, so the first connect already knows whether this socket needs the in-page fallback. Written by the notification hook, read by `PersistentLive`.
  // Absent means "not known yet", which the server reads as no push, since a missed notification costs more than a message nobody needed.
  push: {
    valid: (value) => typeof value === "boolean",
  },
};

function namespaceSpec(namespace) {
  return Object.hasOwn(SYNC_PARAM_NAMESPACES, namespace) ? SYNC_PARAM_NAMESPACES[namespace] : null;
}

function syncParamKey(key) {
  if (!key || !key.startsWith("bonfire:")) return null;

  const rest = key.slice("bonfire:".length);
  const sepIdx = rest.indexOf(":");
  if (sepIdx === -1) return null;

  const namespace = rest.slice(0, sepIdx);
  if (!namespaceSpec(namespace)) return null;

  return { namespace, subkey: rest.slice(sepIdx + 1) };
}

function validStoredValue(val, namespace, now) {
  if (!val || typeof val !== "object") return false;
  if (!Number.isFinite(val.expires)) return false;
  if (now > val.expires) return false;
  if (val.value == null || val.value === "undefined" || val.value === "null") return false;

  const valid = namespaceSpec(namespace)?.valid;
  if (valid && !valid(val.value)) return false;

  return true;
}

function lastTouched(val) {
  if (Number.isFinite(val.last_touched)) return val.last_touched;
  if (typeof val.last_touched === "string") {
    const parsed = Number.parseInt(val.last_touched, 10);
    if (Number.isFinite(parsed)) return parsed;
  }
  return 0;
}

/**
 * Write a bonfire param to localStorage with a per-key TTL.
 * @param {string} namespace - e.g. "reading_pos"
 * @param {string} key - e.g. "my" or "explore"
 * @param {*} value - the data to store (sent to server as-is)
 * @param {number} ttlMs - time-to-live in milliseconds (default 2 days)
 */
export function setBonfireParam(namespace, key, value, ttlMs = 172800000) {
  try {
    const now = Date.now();
    window.localStorage.setItem(
      `bonfire:${namespace}:${key}`,
      JSON.stringify({ value, expires: now + ttlMs, last_touched: now }),
    );
  } catch (_e) {
    // Best effort only: storage may be blocked or full, but LiveView events should still continue through the websocket.
  }
}

/**
 * Read a non-expired bonfire param value from localStorage, or null.
 * Expired/invalid entries are evicted on read.
 */
export function getBonfireParam(namespace, key) {
  try {
    const storageKey = `bonfire:${namespace}:${key}`;
    const raw = window.localStorage.getItem(storageKey);
    if (!raw) return null;
    const val = JSON.parse(raw);
    if (validStoredValue(val, namespace, Date.now())) return val.value;
    window.localStorage.removeItem(storageKey);
    return null;
  } catch (_e) {
    return null;
  }
}

/**
 * Evict expired/invalid entries for a namespace. Reads every matching key, so call sparingly (e.g. once per page load in idle time). Needed for namespaces like drafts whose keys may never be read again (eviction normally happens on read), and which would otherwise outlive their TTL forever.
 */
export function evictExpiredBonfireParams(namespace) {
  try {
    const prefix = `bonfire:${namespace}:`;
    for (let i = window.localStorage.length - 1; i >= 0; i--) {
      const key = window.localStorage.key(i);
      if (key && key.startsWith(prefix)) getBonfireParam(namespace, key.slice(prefix.length));
    }
  } catch (_e) {
    // Best effort only.
  }
}

/**
 * Remove a bonfire param from localStorage.
 */
export function removeBonfireParam(namespace, key) {
  try {
    window.localStorage.removeItem(`bonfire:${namespace}:${key}`);
  } catch (_e) {
    // Best effort only.
  }
}

/**
 * Collect non-expired, allowlisted bonfire:* keys into a nested params object.
 * bonfire:<namespace>:<key> → { [namespace]: { [key]: value } }
 * Expired entries are evicted automatically.
 */
export function collectBonfireParams() {
  const params = {};
  const now = Date.now();
  let storage;
  let length;
  try {
    storage = window.localStorage;
    length = storage.length;
  } catch (_e) {
    return params;
  }
  for (let i = length - 1; i >= 0; i--) {
    let key;
    let syncKey;
    try {
      key = storage.key(i);
      syncKey = syncParamKey(key);
      if (!syncKey) continue;
      const val = JSON.parse(storage.getItem(key));
      const { namespace, subkey } = syncKey;
      if (!validStoredValue(val, namespace, now)) {
        storage.removeItem(key);
        continue;
      }
      params[namespace] ||= {};
      const shape = namespaceSpec(namespace)?.shape;
      params[namespace][subkey] = shape ? shape(val) : val.value;
    } catch {
      if (!syncKey) continue;
      try {
        storage.removeItem(key);
      } catch (_e) {
        // Best effort only.
      }
    }
  }
  return params;
}
