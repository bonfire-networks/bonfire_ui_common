// v4: offline.html gained the overloaded (#overloaded=) hash-mode, installed SWs must re-precache it or the fail-whale redirect lands on the old "you're offline" copy
const OFFLINE_CACHE = 'bonfire-offline-v5';
// App-shell cache: only ever holds content-hashed (immutable) static assets,
// so entries never go stale — a new deploy produces new URLs.
const ASSETS_CACHE = 'bonfire-assets-v1';
// VAPID key and badge count: must survive worker updates, hence in CURRENT_CACHES
const PUSH_CACHE = 'bonfire-push-v1';
const CURRENT_CACHES = [OFFLINE_CACHE, ASSETS_CACHE, PUSH_CACHE];
const ASSETS_CACHE_MAX_ENTRIES = 200;
const OFFLINE_URL = '/pwa/offline.html';

// Last resort for a push that names neither a tag nor an activity, which our own server no longer sends: bucket the clock so everything arriving in the same second shares a tag. That replaces rather than stacks, so a burst of unidentifiable pushes costs one banner per second instead of one each. It is collapse, not throttling, so the newest wins and the ones it replaced are not shown.
const UNTAGGED_COLLAPSE_SECONDS = 1;

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

// Small values kept in PUSH_CACHE, since a worker is stopped and restarted freely
function remember(key, value) {
  return caches.open(PUSH_CACHE).then(cache =>
    cache.put(key, new Response(String(value), { headers: { 'content-type': 'text/plain' } }))
  );
}

function recall(key) {
  return caches.open(PUSH_CACHE)
    .then(cache => cache.match(key))
    .then(response => (response ? response.text() : null))
    .catch(() => null);
}

// The app badge shows the unseen count. An open page reports it (badge_counter_live.hooks.js); with no page on screen, each push adds one. Dismissing a notification doesn't lower it, since the activity is still unseen.
const BADGE_COUNT_KEY = '/__push/badge-count';

function setAppBadge(count) {
  if (!navigator.setAppBadge) return Promise.resolve();
  return (count > 0 ? navigator.setAppBadge(count) : navigator.clearAppBadge()).catch(() => {});
}

function rememberedBadgeCount() {
  return recall(BADGE_COUNT_KEY).then(text => {
    const count = parseInt(text, 10);
    return Number.isFinite(count) ? count : null;
  });
}

// Until a page has reported a count, fall back to the notifications on screen
function fallbackAppBadge() {
  return rememberedBadgeCount().then(count => {
    if (count !== null) return;
    return self.registration.getNotifications().then(notifications => setAppBadge(notifications.length));
  });
}

// A visible page already counts this activity over its socket, so adding one here would overcount.
function appOnScreen() {
  return self.clients.matchAll({ type: 'window', includeUncontrolled: true })
    .then(windows => windows.some(w => w.visibilityState === 'visible'));
}

function bumpAppBadge() {
  return Promise.all([appOnScreen(), rememberedBadgeCount()]).then(([onScreen, count]) => {
    if (onScreen) return;
    if (count === null) return fallbackAppBadge();
    return remember(BADGE_COUNT_KEY, count + 1).then(() => setAppBadge(count + 1));
  });
}

self.addEventListener('push', event => {
  if (!event.data) return;

  try {
    const data = event.data.json();

    const options = {
      // a missing body would otherwise be shown as the word "null"
      body: data.body || '',
      icon: data.icon || '/images/bonfire-icon.png',
      badge: data.badge || '/images/bonfire-icon.png',
      data: { ...data.data, defaultUrl: '/' },
      // What this popup replaces. A server-sent tag wins (a thread's burst collapses into one banner), otherwise the activity itself, which is also what an open page keys on, so the two never show the same activity twice. Ids come from one space in Bonfire, so an activity id cannot collide with anything else used here. The clock bucket is the last resort: as a bare `Date.now()` it made every notification unique, so nothing ever collapsed.
      tag: data.tag || (data.data && data.data.activity_id) ||
        ('notif-' + Math.floor(Date.now() / (UNTAGGED_COLLAPSE_SECONDS * 1000))),
      requireInteraction: data.requireInteraction || false,
      actions: data.actions || [],
      silent: false,
      renotify: data.renotify !== undefined ? data.renotify : true,
      timestamp: Date.now()
    };

    event.waitUntil(
      self.registration.showNotification(data.title, options)
        .then(() => bumpAppBadge())
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
// Re-registering needs the VAPID application server key, which a worker cannot read from the DOM, so the page hands it over (VAPID_KEY below) and it is kept in PUSH_CACHE. The key the existing subscription was made with is tried first, because it is the most reliable copy when the browser gives us the old one.
const VAPID_CACHE_KEY = '/__push/vapid-key';
const SUBSCRIBE_URL = '/api/v1-bonfire/push/subscription';

// base64url, which is what `pushManager.subscribe` takes and what the page has
function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const raw = self.atob(base64);
  return Uint8Array.from([...raw].map(char => char.charCodeAt(0)));
}

self.addEventListener('message', event => {
  const { type, key, count } = event.data || {};
  if (type === 'VAPID_KEY' && key) {
    event.waitUntil(remember(VAPID_CACHE_KEY, key));
  }
  if (type === 'APP_BADGE' && Number.isFinite(count)) {
    event.waitUntil(remember(BADGE_COUNT_KEY, count).then(() => setAppBadge(count)));
  }
});

async function resubscribe(event) {
  // the browser supplies the new subscription where it can; Firefox has historically fired this
  // event with both subscriptions null, so re-subscribing ourselves is the normal path, not an edge case
  let subscription = event.newSubscription;

  if (!subscription) {
    const oldKey = event.oldSubscription && event.oldSubscription.options &&
      event.oldSubscription.options.applicationServerKey;

    const key = oldKey || (await recall(VAPID_CACHE_KEY).then(k => (k ? urlBase64ToUint8Array(k) : null)));

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
  event.waitUntil(fallbackAppBadge());
});

// How long an open window gets to ack a tapped notification's URL before the full-reload fallback
const NAVIGATE_ACK_TIMEOUT_MS = 1000;

// bonfire_live.js navigates over the LiveView socket, keeping the app's state. Resolves false without an ack.
function askClientToNavigate(client, url) {
  return new Promise(resolve => {
    const channel = new MessageChannel();
    const timer = setTimeout(() => resolve(false), NAVIGATE_ACK_TIMEOUT_MS);
    channel.port1.onmessage = () => {
      clearTimeout(timer);
      resolve(true);
    };
    client.postMessage({ type: 'NAVIGATE', url }, [channel.port2]);
  });
}

self.addEventListener('notificationclick', event => {
  event.notification.close();

  const notifUrl = (event.notification.data && event.notification.data.url) ||
                   (event.notification.data && event.notification.data.defaultUrl) ||
                   '/';
  const url = new URL(notifUrl, self.location.origin).href;

  event.waitUntil(
    fallbackAppBadge().then(() => {
      return clients.matchAll({ type: 'window', includeUncontrolled: true });
    }).then(windowClients => {
      for (const client of windowClients) {
        if (client.url === url && 'focus' in client) {
          return client.focus();
        }
      }
      const client = windowClients.find(c => 'focus' in c);
      if (!client) return clients.openWindow(url);

      // navigate() is a full reload; it also rejects for windows this worker doesn't control
      return client.focus()
        .then(focused => askClientToNavigate(focused || client, url))
        .then(handled => handled || client.navigate(url))
        .catch(() => clients.openWindow(url));
    })
  );
});
