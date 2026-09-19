// v4: offline.html gained the overloaded (#overloaded=) hash-mode, installed SWs must re-precache it or the fail-whale redirect lands on the old "you're offline" copy
const OFFLINE_CACHE = 'bonfire-offline-v5';
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

// A push service may rotate an endpoint whenever it likes, and it tells the service worker rather than the page, often with no page open at all. Without this the old endpoint simply goes dead: the row stays, sends start failing, and the user sees nothing until they toggle push off and on.
//
// Re-registering needs the VAPID application server key, which a worker cannot read from the DOM, so the page hands it over (VAPID_KEY below) and it is kept in a cache rather than a variable, since a worker is stopped and restarted freely. The key the existing subscription was made with is tried first, because it is the most reliable copy when the browser gives us the old one.
const VAPID_CACHE = 'bonfire-push-v1';
const VAPID_CACHE_KEY = '/__push/vapid-key';
const SUBSCRIBE_URL = '/api/v1-bonfire/push/subscription';

function rememberVapidKey(key) {
  if (!key) return Promise.resolve();
  return caches.open(VAPID_CACHE).then(cache =>
    cache.put(VAPID_CACHE_KEY, new Response(key, { headers: { 'content-type': 'text/plain' } }))
  );
}

function rememberedVapidKey() {
  return caches.open(VAPID_CACHE)
    .then(cache => cache.match(VAPID_CACHE_KEY))
    .then(response => (response ? response.text() : null))
    .catch(() => null);
}

// base64url, which is what `pushManager.subscribe` takes and what the page has
function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const raw = self.atob(base64);
  return Uint8Array.from([...raw].map(char => char.charCodeAt(0)));
}

self.addEventListener('message', event => {
  if (event.data && event.data.type === 'VAPID_KEY') {
    event.waitUntil(rememberVapidKey(event.data.key));
  }
});

async function resubscribe(event) {
  // the browser supplies the new subscription where it can; Firefox has historically fired this
  // event with both subscriptions null, so re-subscribing ourselves is the normal path, not an edge case
  let subscription = event.newSubscription;

  if (!subscription) {
    const oldKey = event.oldSubscription && event.oldSubscription.options &&
      event.oldSubscription.options.applicationServerKey;

    const key = oldKey || (await rememberedVapidKey().then(k => (k ? urlBase64ToUint8Array(k) : null)));

    if (!key) {
      console.error('push: cannot re-subscribe without a VAPID key');
      return;
    }

    subscription = await self.registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: key
    });
  }

  // the session cookie is what authenticates this, and the path says the payload shape we can read.
  // The dead row is left to the next failed send, which deactivates it: there is no page to tell,
  // and nothing here knows which of this person's devices the old endpoint was
  await fetch(SUBSCRIBE_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    credentials: 'same-origin',
    body: JSON.stringify({ subscription: subscription.toJSON() })
  });
}

self.addEventListener('pushsubscriptionchange', event => {
  event.waitUntil(resubscribe(event).catch(error => {
    console.error('push: re-subscribe after endpoint rotation failed:', error);
  }));
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
