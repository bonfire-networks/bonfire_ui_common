// Generic utility for syncing localStorage entries to the server via connect_params.
// Any feature can store `bonfire:<namespace>:<key>` and it gets sent automatically.
// Values are stored as { value: <any>, expires: <epoch_ms> }.

/**
 * Write a bonfire param to localStorage with a per-key TTL.
 * @param {string} namespace - e.g. "reading_pos"
 * @param {string} key - e.g. "my" or "explore"
 * @param {*} value - the data to store (sent to server as-is)
 * @param {number} ttlMs - time-to-live in milliseconds (default 2 days)
 */
export function setBonfireParam(namespace, key, value, ttlMs = 172800000) {
  localStorage.setItem(
    `bonfire:${namespace}:${key}`,
    JSON.stringify({ value, expires: Date.now() + ttlMs }),
  );
}

/**
 * Remove a bonfire param from localStorage.
 */
export function removeBonfireParam(namespace, key) {
  localStorage.removeItem(`bonfire:${namespace}:${key}`);
}

/**
 * Collect all non-expired bonfire:* keys into a nested params object.
 * bonfire:<namespace>:<key> → { [namespace]: { [key]: value } }
 * Expired entries are evicted automatically.
 */
export function collectBonfireParams() {
  const params = {};
  const now = Date.now();
  for (let i = localStorage.length - 1; i >= 0; i--) {
    const key = localStorage.key(i);
    if (!key.startsWith("bonfire:")) continue;
    try {
      const val = JSON.parse(localStorage.getItem(key));
      if (!val || now > val.expires) {
        localStorage.removeItem(key);
        continue;
      }
      const rest = key.slice("bonfire:".length);
      const sepIdx = rest.indexOf(":");
      if (sepIdx === -1) {
        params[rest] = val.value;
      } else {
        const ns = rest.slice(0, sepIdx);
        const subkey = rest.slice(sepIdx + 1);
        params[ns] ||= {};
        params[ns][subkey] = val.value;
      }
    } catch {
      localStorage.removeItem(key);
    }
  }
  return params;
}
