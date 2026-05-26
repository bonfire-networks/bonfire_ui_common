// Utility for syncing allowlisted localStorage entries to the server via connect_params.
// This deliberately ignores unrelated `bonfire:*` keys such as client debug flags.
// Values are stored as { value: <any>, expires: <epoch_ms> }.

const READING_POS_NAMESPACE = "reading_pos";
const SYNC_PARAM_NAMESPACES = new Set([READING_POS_NAMESPACE]);

function syncParamKey(key) {
  if (!key || !key.startsWith("bonfire:")) return null;

  const rest = key.slice("bonfire:".length);
  const sepIdx = rest.indexOf(":");
  if (sepIdx === -1) return null;

  const namespace = rest.slice(0, sepIdx);
  if (!SYNC_PARAM_NAMESPACES.has(namespace)) return null;

  return { namespace, subkey: rest.slice(sepIdx + 1) };
}

function validStoredValue(val, namespace, now) {
  if (!val || typeof val !== "object") return false;
  if (!Number.isFinite(val.expires)) return false;
  if (now > val.expires) return false;
  if (val.value == null || val.value === "undefined" || val.value === "null") return false;
  if (namespace === READING_POS_NAMESPACE && typeof val.value !== "string") return false;
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
    // Best effort only: storage may be blocked or full, but LiveView events
    // should still continue through the websocket.
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
      params[namespace][subkey] =
        namespace === READING_POS_NAMESPACE
          ? { value: val.value, last_touched: lastTouched(val) }
          : val.value;
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
