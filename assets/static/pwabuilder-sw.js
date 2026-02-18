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
  console.log('Push event received:', event);

  if (!event.data) {
    console.log('Push event but no data');
    return;
  }

  try {
    const data = event.data.json();

    const options = {
      body: data.body,
      icon: data.icon || '/images/bonfire-icon.png',
      badge: data.badge || '/images/bonfire-icon.png',
      image: data.image || '/images/bonfire-icon.png',
      data: { ...data.data, defaultUrl: '/' },
      tag: data.tag || 'default',
      requireInteraction: true,
      actions: data.actions || [],
      silent: false,
      renotify: true,
      timestamp: Date.now()
    };

    event.waitUntil(
      self.registration.showNotification(data.title, options)
        .then(() => {
          return self.clients.matchAll();
        })
        .then(clients => {
          clients.forEach(client => {
            client.postMessage({
              type: 'NOTIFICATION_CREATED',
              title: data.title,
              body: data.body,
              timestamp: Date.now()
            });
          });

          return self.registration.getNotifications();
        })
        .then(activeNotifications => {
          return self.clients.matchAll().then(clients => {
            clients.forEach(client => {
              client.postMessage({
                type: 'NOTIFICATION_STATUS',
                count: activeNotifications.length,
                message: 'Notification created!'
              });
            });
          });
        })
        .catch(error => {
          return self.clients.matchAll().then(clients => {
            clients.forEach(client => {
              client.postMessage({
                type: 'NOTIFICATION_ERROR',
                error: error.message
              });
            });
          });
        })
    );

  } catch (error) {
    console.error('Error processing push:', error);
  }
});

self.addEventListener('notificationclick', event => {
  event.notification.close();

  event.waitUntil(
    clients.openWindow(`/`)
  );
});