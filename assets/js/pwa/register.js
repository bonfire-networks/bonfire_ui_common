export function registerServiceWorker() {
  if (window.__TAURI__ || window.__TAURI_INTERNALS__) {
    return;
  }

  // Only proceed if service worker is supported
  if (!('serviceWorker' in navigator)) {
    return;
  }

  // Only register on HTTPS or localhost
  if (window.location.protocol !== 'https:' && window.location.hostname !== 'localhost') {
    return;
  }

  // Register the offline-fallback + push service worker app-wide (called once per
  // page load from bonfire_common.js). Registration is idempotent — bonfire_notify
  // registers the same script+scope when enabling push, and the browser dedupes —
  // so this is safe to call alongside it. The SW only serves an offline page on
  // navigation *failure*; it never caches permission-scoped HTML.
  const register = () => {
    navigator.serviceWorker
      .register('/pwabuilder-sw.js', { scope: '/' })
      .catch((error) => {
        console.error('SW registration failed:', error);
      });
  };

  // Defer to the load event to avoid competing with initial page load, but if the
  // page is already loaded (script ran late), register immediately.
  if (document.readyState === 'complete') {
    register();
  } else {
    window.addEventListener('load', register, { once: true });
  }
}