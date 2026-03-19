const CACHE_NAME = 'v1-bonfire';
const OFFLINE_URL = '/pwa/offline.html';

// Install: Cache the offline page
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.add(OFFLINE_URL))
      // Force activation of new SW
      .then(() => self.skipWaiting())
  );
});

// Activate: Clean up old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames
          .filter(cacheName => cacheName !== CACHE_NAME)
          .map(cacheName => caches.delete(cacheName))
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch: Only handle navigation failures with offline page
self.addEventListener('fetch', event => {
  // Only intercept navigation requests (page loads)
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(() => {
        return caches.match(OFFLINE_URL);
      })
    );
  }
  // Let all other requests (API, assets, etc) pass through normally
});

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

self.addEventListener('notificationclick', event => {
  event.notification.close();

  const notifUrl = (event.notification.data && event.notification.data.url) ||
                   (event.notification.data && event.notification.data.defaultUrl) ||
                   '/';
  const url = new URL(notifUrl, self.location.origin).href;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(windowClients => {
      // Prefer a tab already on the target URL
      for (const client of windowClients) {
        if (client.url === url && 'focus' in client) {
          return client.focus();
        }
      }
      // Otherwise navigate the first available tab
      for (const client of windowClients) {
        if ('focus' in client) {
          return client.focus().then(c => c.navigate(url));
        }
      }
      return clients.openWindow(url);
    })
  );
});
