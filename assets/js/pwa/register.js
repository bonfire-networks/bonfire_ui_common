export function registerServiceWorker() {
  // Only proceed if service worker is supported
  if (!('serviceWorker' in navigator)) {
    return;
  }

  // Only register on HTTPS or localhost
  if (window.location.protocol !== 'https:' && window.location.hostname !== 'localhost') {
    return;
  }

  // // Simple registration, no fancy features yet -> NOTE: doing this in bonfire_notify now 
  // window.addEventListener('load', () => {
  //   navigator.serviceWorker.register('/pwabuilder-sw.js')
  //     .then(registration => {
  //       console.log('SW registered:', registration.scope);
  //     })
  //     .catch(error => {
  //       console.error('SW registration failed:', error);
  //     });
  // });
}