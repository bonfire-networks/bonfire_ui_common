// Mobile bottom navigation bar using DaisyUI dock classes.
// Injected via initialization_script — runs on every page load in the single WebviewWindow.
// Includes :where() fallback styles so it works on pages without DaisyUI loaded.
// On pages WITH DaisyUI (e.g. chat), DaisyUI's own dock styles take priority.
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

    // Fallback styles using :where() — zero specificity so DaisyUI wins when present
    const style = document.createElement('style');
    style.textContent = `
      #bonfire-mobile-nav {
        position: fixed !important;
        bottom: 0 !important;
        left: 0 !important;
        right: 0 !important;
        z-index: 99999 !important;
        transform: translate3d(0, 0, 0);
        padding-bottom: env(safe-area-inset-bottom, 0px);
      }
      :where(.dock) {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 100%;
        height: 56px;
        background: oklch(0.2 0.01 260);
        border-top: 1px solid oklch(0.3 0.01 260);
        font-family: system-ui, -apple-system, sans-serif;
      }
      :where(.dock) > :where(button) {
        flex: 1;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        gap: 2px;
        border: none;
        background: transparent;
        color: oklch(0.6 0.01 260);
        font-size: 10px;
        padding: 6px 0;
        cursor: pointer;
        transition: color 0.15s;
        -webkit-tap-highlight-color: transparent;
      }
      :where(.dock) > :where(button.dock-active) {
        color: oklch(0.95 0 0);
      }
      :where(.dock) > :where(button) :where(svg) {
        width: 22px;
        height: 22px;
      }
      #bonfire-mobile-nav svg {
        width: 22px !important;
        height: 22px !important;
      }
      :where(.dock-label) {
        font-size: 10px;
      }
      body {
        padding-bottom: calc(56px + env(safe-area-inset-bottom, 0px)) !important;
      }
    `;
    document.head.appendChild(style);

    // Expose nav height as CSS custom property so Shadow DOM components can account for it
    document.documentElement.style.setProperty('--bonfire-nav-height', 'calc(56px + env(safe-area-inset-bottom, 0px))');

    const nav = document.createElement('nav');
    nav.id = 'bonfire-mobile-nav';
    nav.className = 'dock dock-sm';
    nav.innerHTML = `
      <button id="bnav-home" class="${isChat ? '' : 'dock-active'}">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round"
            d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>
        </svg>
        <span class="dock-label">Home</span>
      </button>
      <button id="bnav-chat" class="${isChat ? 'dock-active' : ''}">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round"
            d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
        </svg>
        <span class="dock-label">Messages</span>
      </button>
    `;
    document.documentElement.appendChild(nav);

    document.getElementById('bnav-home').addEventListener('click', () => {
      invoke('switch_tab', { tab: 'main' }).catch(e => console.error('[mobile-nav]', e));
    });
    document.getElementById('bnav-chat').addEventListener('click', () => {
      invoke('switch_tab', { tab: 'chat' }).catch(e => console.error('[mobile-nav]', e));
    });

    listen('tab-changed', (event) => {
      const tab = event.payload;
      const home = document.getElementById('bnav-home');
      const chat = document.getElementById('bnav-chat');
      if (home) { home.classList.toggle('dock-active', tab === 'main'); }
      if (chat) { chat.classList.toggle('dock-active', tab === 'chat'); }
    });
  }

  if (document.body) inject();
  else document.addEventListener('DOMContentLoaded', inject);
})();
