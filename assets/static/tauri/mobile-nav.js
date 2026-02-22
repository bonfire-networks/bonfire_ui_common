// Mobile bottom navigation bar.
// Injected via initialization_script — runs on every page load in the single WebviewWindow.
// Calls the same Tauri commands as the desktop chrome bar: switch_tab, get_active_tab.
(function() {
  'use strict';

  const path = window.location.pathname;
  const host = window.location.hostname;

  // Skip login page
  if (path.includes('pick-instance')) return;
  // Skip non-chat local Tauri pages (OAuth callbacks, etc.)
  const isChat = path.includes('ap_c2s_client');
  if (host === 'tauri.localhost' && !isChat) return;

  // Prevent double injection
  if (document.getElementById('bonfire-mobile-nav')) return;
  // Require Tauri API
  if (!window.__TAURI__) return;

  const { invoke } = window.__TAURI__.core;
  const { listen } = window.__TAURI__.event;

  function inject() {
    if (document.getElementById('bonfire-mobile-nav')) return;

    const style = document.createElement('style');
    style.textContent = `
      #bonfire-mobile-nav {
        position: fixed !important;
        bottom: 0 !important;
        left: 0 !important;
        right: 0 !important;
        z-index: 99999 !important;
        transform: translate3d(0, 0, 0);
        display: flex;
        justify-content: space-around;
        align-items: center;
        height: calc(56px + env(safe-area-inset-bottom, 0px));
        padding-bottom: env(safe-area-inset-bottom, 0px);
        background: rgba(20, 20, 25, 0.95);
        backdrop-filter: blur(12px);
        -webkit-backdrop-filter: blur(12px);
        border-top: 1px solid rgba(255, 255, 255, 0.1);
      }
      #bonfire-mobile-nav button {
        flex: 1;
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 2px;
        padding: 8px 0;
        border: none;
        background: none;
        color: rgba(255, 255, 255, 0.45);
        font-size: 11px;
        font-family: system-ui, -apple-system, sans-serif;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
      }
      #bonfire-mobile-nav button.active {
        color: #818cf8;
      }
      #bonfire-mobile-nav button svg {
        width: 24px;
        height: 24px;
      }
      body {
        padding-bottom: calc(56px + env(safe-area-inset-bottom, 0px)) !important;
      }
    `;
    document.head.appendChild(style);

    const nav = document.createElement('nav');
    nav.id = 'bonfire-mobile-nav';
    nav.innerHTML = `
      <button id="bnav-home" class="${isChat ? '' : 'active'}">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round"
            d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>
        </svg>
        <span>Home</span>
      </button>
      <button id="bnav-chat" class="${isChat ? 'active' : ''}">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round"
            d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
        </svg>
        <span>Messages</span>
      </button>
    `;
    // Append to <html> instead of <body> to avoid body's flex/grid layout
    // interfering with position:fixed on Android WebView
    document.documentElement.appendChild(nav);

    // Click handlers — same invoke('switch_tab', { tab }) as the desktop chrome bar
    document.getElementById('bnav-home').addEventListener('click', () => {
      invoke('switch_tab', { tab: 'main' }).catch(e => console.error('[mobile-nav]', e));
    });
    document.getElementById('bnav-chat').addEventListener('click', () => {
      invoke('switch_tab', { tab: 'chat' }).catch(e => console.error('[mobile-nav]', e));
    });

    // Sync active indicator — same 'tab-changed' event the desktop chrome bar listens to
    listen('tab-changed', (event) => {
      const tab = event.payload;
      document.getElementById('bnav-home')?.classList.toggle('active', tab === 'main');
      document.getElementById('bnav-chat')?.classList.toggle('active', tab === 'chat');
    });
  }

  if (document.body) inject();
  else document.addEventListener('DOMContentLoaded', inject);
})();
