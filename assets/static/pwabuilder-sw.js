const OFFLINE_CACHE = 'bonfire-offline-v3';
// App-shell cache: only ever holds content-hashed (immutable) static assets,
// so entries never go stale — a new deploy produces new URLs.
const ASSETS_CACHE = 'bonfire-assets-v1';
const CURRENT_CACHES = [OFFLINE_CACHE, ASSETS_CACHE];
const ASSETS_CACHE_MAX_ENTRIES = 200;
const OFFLINE_URL = '/pwa/offline.html';

// Matches mix phx.digest fingerprinted filenames, e.g.
// /assets/bonfire_basic-e9e9e60c06b55d4d6a2ba7cc02a8af41.css
const DIGESTED_PATH = /-[a-f0-9]{32}\.[a-z0-9]+(\.[a-z0-9]+)*$/;
// Only cache the app shell. Notably NOT /data/uploads/: uploads are
// permission-scoped and can carry hash-like names, so they must never
// be served from a shared SW cache.
const STATIC_PREFIXES = ['/assets/', '/fonts/', '/images/', '/css/', '/js/', '/pwa/'];

function cacheableAsset(request) {
  if (request.method !== 'GET') return false;
  const url = new URL(request.url);
  return (
    url.origin === self.location.origin &&
    STATIC_PREFIXES.some(prefix => url.pathname.startsWith(prefix)) &&
    DIGESTED_PATH.test(url.pathname)
  );
}

// Cap cache growth across deploys (old digests are never requested again but
// would otherwise accumulate forever).
function trimAssetsCache() {
  return caches.open(ASSETS_CACHE).then(cache =>
    cache.keys().then(keys => {
      if (keys.length <= ASSETS_CACHE_MAX_ENTRIES) return;
      return Promise.all(
        keys.slice(0, keys.length - ASSETS_CACHE_MAX_ENTRIES).map(key => cache.delete(key))
      );
    })
  );
}

// Install: Cache the offline page
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(OFFLINE_CACHE)
      .then(cache => cache.add(OFFLINE_URL))
      .then(() => self.skipWaiting())
  );
});

// Activate: Clean up old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames
          .filter(cacheName => !CURRENT_CACHES.includes(cacheName))
          .map(cacheName => caches.delete(cacheName))
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch:
// - digest-fingerprinted static assets: cache-first (immutable by construction),
//   so repeat startups skip the network for the whole app shell
// - navigations: network, falling back to the offline page
// - everything else (HTML, API, uploads): untouched — never cached
self.addEventListener('fetch', event => {
  if (cacheableAsset(event.request)) {
    event.respondWith(
      caches.open(ASSETS_CACHE).then(cache =>
        cache.match(event.request).then(cached => {
          if (cached) return cached;
          return fetch(event.request).then(response => {
            if (response.ok && (response.type === 'basic' || response.type === 'default')) {
              // fire-and-forget: trimming is best-effort housekeeping
              cache.put(event.request, response.clone()).then(trimAssetsCache);
            }
            return response;
          });
        })
      )
    );
  } else if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(() => {
        return caches.match(OFFLINE_URL);
      })
    );
  }
});

function updateAppBadge() {
  return self.registration.getNotifications().then(notifications => {
    if (!navigator.setAppBadge) return;
    notifications.length === 0 ? navigator.clearAppBadge() : navigator.setAppBadge(notifications.length);
  });
}

self.addEventListener('push', event => {
  if (!event.data) return;

  try {
    const data = event.data.json();

    const options = {
      body: data.body,
      icon: data.icon || '/images/bonfire-icon.png',
      badge: data.badge || '/images/bonfire-icon.png',
      data: { ...data.data, defaultUrl: '/' },
      tag: data.tag || ('notif-' + Date.now()),
      requireInteraction: data.requireInteraction || false,
      actions: data.actions || [],
      silent: false,
      renotify: data.renotify !== undefined ? data.renotify : true,
      timestamp: Date.now()
    };

    event.waitUntil(
      self.registration.showNotification(data.title, options)
        .then(() => updateAppBadge())
        .then(() => self.clients.matchAll())
        .then(clients => {
          clients.forEach(client => {
            client.postMessage({
              type: 'NOTIFICATION_CREATED',
              title: data.title,
              body: data.body,
              timestamp: Date.now()
            });
          });
        })
        .catch(error => {
          console.error('showNotification failed:', error);
        })
    );

  } catch (error) {
    console.error('Error processing push:', error);
  }
});

self.addEventListener('notificationclose', event => {
  event.waitUntil(updateAppBadge());
});

self.addEventListener('notificationclick', event => {
  event.notification.close();

  const notifUrl = (event.notification.data && event.notification.data.url) ||
                   (event.notification.data && event.notification.data.defaultUrl) ||
                   '/';
  const url = new URL(notifUrl, self.location.origin).href;

  event.waitUntil(
    updateAppBadge().then(() => {
      return clients.matchAll({ type: 'window', includeUncontrolled: true });
    }).then(windowClients => {
      for (const client of windowClients) {
        if (client.url === url && 'focus' in client) {
          return client.focus();
        }
      }
      for (const client of windowClients) {
        if ('focus' in client) {
          return client.focus().then(c => c.navigate(url));
        }
      }
      return clients.openWindow(url);
    })
  );
});
