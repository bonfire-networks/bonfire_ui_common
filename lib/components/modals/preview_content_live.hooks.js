
let closingPreviewUntil = 0;

const previewState = {
  storageKey: "bonfire_preview_session",
  hideFeedKey: "bonfire_hide_feed",

  sameOriginUrl(url, baseUrl = window.location.href) {
    try {
      const base = new URL(baseUrl, window.location.origin);
      const parsed = new URL(url, base);
      if (parsed.origin !== base.origin) return null;
      return parsed.href;
    } catch (_e) {
      return null;
    }
  },

  scrollTop(scroll) {
    const parsed = parseInt(scroll, 10);
    return Number.isFinite(parsed) ? parsed : 0;
  },

  save(entryUrl, previewUrl, previousScroll) {
    const normalizedEntryUrl = this.sameOriginUrl(entryUrl);
    const normalizedPreviewUrl = this.sameOriginUrl(previewUrl, normalizedEntryUrl || undefined);

    if (!normalizedEntryUrl || !normalizedPreviewUrl) return null;

    const session = {
      entryUrl: normalizedEntryUrl,
      previewUrl: normalizedPreviewUrl,
      previousScroll: this.scrollTop(previousScroll)
    };

    try {
      sessionStorage.setItem(this.storageKey, JSON.stringify(session));
      return session;
    } catch (e) {
      console.warn("Failed to save preview session:", e);
      return null;
    }
  },

  read() {
    try {
      const raw = sessionStorage.getItem(this.storageKey);
      if (!raw) return null;

      const session = JSON.parse(raw);
      const normalizedEntryUrl = this.sameOriginUrl(session.entryUrl);
      const normalizedPreviewUrl = this.sameOriginUrl(session.previewUrl);

      if (!normalizedEntryUrl || !normalizedPreviewUrl) {
        this.clear();
        return null;
      }

      return {
        entryUrl: normalizedEntryUrl,
        previewUrl: normalizedPreviewUrl,
        previousScroll: this.scrollTop(session.previousScroll)
      };
    } catch (e) {
      console.warn("Failed to read preview session:", e);
      this.clear();
      return null;
    }
  },

  clear() {
    try {
      sessionStorage.removeItem(this.storageKey);
    } catch (e) {
      console.warn("Failed to clear preview session:", e);
    }
  },

  historyState(session) {
    // Carry LiveView's history bookkeeping: an entry without `position` resets
    // its history counter to 0 on pop, corrupting back/forward detection. The
    // half-step keeps direction reads exact from both neighbours; `id` is
    // omitted so a pop onto this entry is never treated as a same-view patch.
    const lvState = history.state || {};
    return {
      bonfirePreview: true,
      entryUrl: session.entryUrl,
      previewUrl: session.previewUrl,
      previousScroll: session.previousScroll,
      position: typeof lvState.position === "number" ? lvState.position + 0.5 : undefined,
      type: lvState.type,
      backType: lvState.backType
    };
  },

  isPreviewHistory(state = history.state) {
    return !!(state && state.bonfirePreview === true);
  },

  isCurrent(session = this.read()) {
    if (!session) return false;
    const currentUrl = this.sameOriginUrl(window.location.href);
    return currentUrl === session.previewUrl;
  }
};

function markClosingPreview() {
  closingPreviewUntil = Date.now() + 2000;
}

function isClosingPreview() {
  return Date.now() < closingPreviewUntil;
}

// A synthetic preview entry left behind in the stack (e.g. by a promotion or
// reload) makes a same-URL back-swipe a dead gesture: LiveView ignores the
// popstate and there is no overlay to close, so the swipe eats a history entry
// while the screen stays put. Consume such orphans so one swipe traverses one
// page. Cross-URL pops are left to LiveView / PreviewContainer recovery.
let lastKnownHref = window.location.href;

function trackHref() {
  lastKnownHref = window.location.href;
}

// Hash-only URL changes fire neither popstate nor phx:navigate, so the orphan
// detector compares URLs with the hash stripped.
window.addEventListener("hashchange", trackHref);

function stripHash(url) {
  const i = url.indexOf("#");
  return i === -1 ? url : url.slice(0, i);
}

// Rewrite the current entry as LiveView-owned, dropping the preview marker
// but keeping LV's position/type/backType bookkeeping.
function stripPreviewHistoryMarker(extra = {}) {
  if (!previewState.isPreviewHistory(history.state)) return;
  const { bonfirePreview, entryUrl, previewUrl, previousScroll, ...lvState } = history.state;
  try {
    history.replaceState({ ...lvState, ...extra }, "", window.location.href);
  } catch (err) {
    console.warn("Failed to strip preview history marker:", err);
  }
}

window.addEventListener("phx:navigate", (e) => {
  trackHref();

  // LiveView skips pushState when navigating to the URL it is already on, so
  // promoting a preview to its real page leaves the synthetic entry current.
  // Rebrand it and drop the session; otherwise PreviewContainer recovery
  // treats the promoted page as a broken preview and yanks the user around.
  if (!e.detail?.pop && previewState.isPreviewHistory(history.state)) {
    stripPreviewHistoryMarker({
      type: e.detail?.patch ? "patch" : "redirect",
      position:
        typeof window.liveSocket?.currentHistoryPosition === "number"
          ? window.liveSocket.currentHistoryPosition
          : history.state.position
    });
    previewState.clear();
  }
});

// --- Overlay controller ---
// Visibility is client-authoritative: open/close paint immediately via inline
// styles; server "open"/"close" events load content and clean up state, never
// gate what the user sees. Invariant: synthetic entry current ⇔ overlay visible.

let overlayOpen = false;
let previewHook = null; // PreviewContainer instance (always mounted on #preview_content)

function notifyServerClose() {
  try {
    previewHook?.pushEventTo(utils.selectors.previewContent, "close", {});
  } catch (_e) {}
}

const SCROLL_RESTORE_MS = 1000;

// Put the feed back where the reader left it, in the frame it reappears
// (showMainContent has just shown it): one write, so one layout. A fixed 100 ms
// wait plus a MutationObserver re-writing scrollTop on every patch cost a 127 ms
// forced layout at 4x CPU. Retries only while the page is too short for the
// offset, and yields once anything else moves it, like retryScrollRestore in
// bonfire_live.js.
function restoreFeedAfterClose(session) {
  const position = session?.previousScroll || 0;
  previewState.clear();

  const layout = utils.getScrollContainer();
  if (!layout) return;

  const deadline = Date.now() + SCROLL_RESTORE_MS;
  let written = null;
  const attempt = () => {
    if (written !== null && layout.scrollTop !== written) return;
    const reachable = Math.min(position, layout.scrollHeight - layout.clientHeight);
    layout.scrollTop = reachable;
    written = layout.scrollTop;
    if (reachable < position && Date.now() < deadline) requestAnimationFrame(attempt);
  };
  attempt();
}

// Single close path for every trigger: hide client-side first, then notify
// the server, then fix history.
function closePreviewFully({ restoreUrl = true } = {}) {
  const session = previewState.read();
  overlayOpen = false;
  markClosingPreview();
  utils.hidePreviewNow();
  notifyServerClose();

  if (restoreUrl) {
    if (previewState.isPreviewHistory(history.state)) {
      // consume the synthetic entry; the resulting popstate is inert behind
      // the isClosingPreview() guard
      try {
        history.back();
      } catch (e) {
        console.warn("Failed to navigate back from preview:", e);
      }
    } else if (session?.entryUrl && session.entryUrl !== window.location.href) {
      try {
        history.replaceState(history.state || {}, "", session.entryUrl);
        trackHref();
      } catch (e) {
        console.warn("Failed to restore URL:", e);
      }
    }
  }

  restoreFeedAfterClose(session);
}

// Global Esc-to-close (the old CloseAll hook never actually mounted);
// defaultPrevented lets inner widgets consume their own Escape.
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !e.defaultPrevented && utils.isPreviewVisible()) {
    closePreviewFully();
  }
});

window.addEventListener("popstate", (e) => {
  const previousHref = lastKnownHref;
  trackHref();

  if (isClosingPreview()) return;

  const onPreviewEntry = previewState.isPreviewHistory(e.state);

  // Popped off the overlay's entry while it shows: close, client-side first.
  if (!onPreviewEntry && utils.isPreviewVisible()) {
    const session = previewState.read();
    overlayOpen = false;
    markClosingPreview();
    utils.hidePreviewNow();
    notifyServerClose();
    restoreFeedAfterClose(session);
    return;
  }

  if (onPreviewEntry && !utils.isPreviewVisible()) {
    if (stripHash(window.location.href) === stripHash(previousHref)) {
      // Dead same-URL pop onto an orphaned entry: consume it.
      try {
        history.back();
      } catch (err) {
        console.warn("Failed to skip orphaned preview history entry:", err);
      }
    } else {
      // Cross-URL pop onto a marked entry: strip the marker, let LiveView
      // render the real page.
      stripPreviewHistoryMarker();
      previewState.clear();
    }
  }
});

// Utility functions for scroll and navigation
const utils = {
  // DOM element selectors - centralized for consistency
  selectors: {
    previewContent: "#preview_content",
    previewContents: "#the_preview_contents",
    loadingMessage: "[data-id='modal-contents'] div.m-3.text-center",
    feedActivityList: '[data-id="feed_activity_list"]',
    rootElement: "#root",
    innerContent: "#main-content"
  },
  
  // Animation timing constants
  timing: {
    standardTransition: "180ms",
    easing: "cubic-bezier(0.19, 1, 0.22, 1)"
  },

  opacityTransition(duration, animate = true) {
    return animate ? `opacity ${duration} ${this.timing.easing}` : "none";
  },

  // Movement threshold in pixels - if pointer moves more than this, it's a scroll not a tap
  scrollThreshold: 10,

  // Storage keys - centralized for consistency
  storageKeys: {
    hideFeed: previewState.hideFeedKey
  },

  // What the user actually sees, not the server's possibly-stale data-show.
  isPreviewVisible() {
    const previewContent = document.querySelector(this.selectors.previewContent);
    return !!previewContent && getComputedStyle(previewContent).display !== "none";
  },

  // Client-side hide, mirror of showLoadingState — closing never waits on a
  // server round-trip.
  hidePreviewNow() {
    const previewContent = document.querySelector(this.selectors.previewContent);
    if (previewContent) {
      previewContent.style.display = "none";
      previewContent.setAttribute("data-show", "false");
      previewContent.setAttribute("data-hide", "true");
    }

    const contents = document.getElementById(this.selectors.previewContents.substring(1));
    if (contents) contents.style.display = "none";

    this.showMainContent();
  },
  
  // Find the best scrollable container
  getScrollContainer() {
    const root = document.getElementById(this.selectors.rootElement.substring(1));
    if (root && root.scrollHeight > root.clientHeight) {
      return root;
    }
    return document.documentElement || document.body;
  },

  // Escape target for a previewable click, ONLY for embeds that opt in via
  // [data-embed-links] (the pins embed → "_blank"). Returns null otherwise —
  // notably in the interactive comments embed, where a comment-body click must
  // NOT navigate the host page away.
  embedLinkTarget() {
    const marker = document.querySelector("[data-embed-links]");
    return marker ? marker.getAttribute("data-embed-links") || "_blank" : null;
  },
  
  // Show loading state immediately when preview is requested
  showLoadingState() {
    const previewContent = document.querySelector(this.selectors.previewContent);
    if (!previewContent) {
      console.warn("Preview content element not found");
      return;
    }
    
    // Make preview content visible
    previewContent.style.display = "block";
    previewContent.setAttribute("data-show", "true");
    if (previewContent.hasAttribute("data-hide")) {
      previewContent.removeAttribute("data-hide");
    }
    
    // Show the preview container
    const contents = document.getElementById(this.selectors.previewContents.substring(1));
    if (contents) {
      contents.style.display = "block";
      if (contents.classList.contains("hidden")) {
        contents.classList.remove("hidden");
      }
    }
    
    // Ensure loading message is visible
    const loadingElement = previewContent.querySelector(this.selectors.loadingMessage);
    if (loadingElement) {
      loadingElement.style.display = "flex";
    }
    
    // Hide the page under the preview. display:none, the state the server's
    // `hidden: @hide_main` ends in anyway: visibility:hidden is inherited, so it
    // restyled every feed element before the first paint (median 277 ms of no
    // feedback at 4x CPU, 99 ms with display:none). It also collapses the page,
    // so the browser moves the scroll to the top before that paint.
    const innerContent = document.getElementById(this.selectors.innerContent.substring(1));
    if (innerContent) innerContent.style.display = "none";
  },
  
  // Also drops the server's `hidden` class: the open patch replaces our inline
  // display:none with it (`hidden: @hide_main`), and only the server's reply to
  // "close" would remove it, so the feed waited a round trip to reappear.
  showMainContent() {
    const innerContent = document.getElementById(this.selectors.innerContent.substring(1));
    if (!innerContent) return;
    innerContent.style.removeProperty("display");
    innerContent.classList.remove("hidden");
  },
  
  liveSocketConnected() {
    return !!(window.liveSocket && (!window.liveSocket.isConnected || window.liveSocket.isConnected()));
  },

  findPreviewTrigger(previewUrl) {
    const normalizedPreviewUrl = previewState.sameOriginUrl(previewUrl);
    if (!normalizedPreviewUrl) return null;

    return Array.from(document.querySelectorAll("a.open_preview_link[href], .open_preview_link a[href]"))
      .find((trigger) => previewState.sameOriginUrl(trigger.getAttribute("href")) === normalizedPreviewUrl) ||
      null;
  },

  // True when the document was actually fetched from `url`, vs merely showing
  // it via pushState (preview modal over the feed). The navigation timing
  // entry, unlike location.href, isn't touched by pushState. Fragments ignored.
  documentLoadedAt(url) {
    try {
      const nav = performance.getEntriesByType("navigation")[0];
      if (!nav || !nav.name) return false;

      const stripHash = (u) => {
        const normalized = previewState.sameOriginUrl(u);
        if (!normalized) return null;
        const parsed = new URL(normalized);
        parsed.hash = "";
        return parsed.href;
      };

      const documentUrl = stripHash(nav.name);
      const targetUrl = stripHash(url);
      return !!documentUrl && documentUrl === targetUrl;
    } catch (_e) {
      return false;
    }
  }
};


// Helper for checking if a click or keyboard action should open a preview
function shouldHandlePreviewOpen(e, trigger, pointerState, uri, opts = {}) {
  // If pointer moved beyond threshold, this was a scroll/drag — not a tap
  if (pointerState && pointerState.moved) return false;

  if (e.defaultPrevented) return false;

  if (!opts.keyboard && e.button !== undefined && e.button !== 0) return false;

  // Quick rules first to fail early
  if (e.ctrlKey || e.metaKey || e.altKey || e.shiftKey) return false;

  if (opts.keyboard && e.target !== opts.container) return false;

  // Check for selection
  const hasSelection = window.getSelection &&
                      window.getSelection().toString &&
                      window.getSelection().toString().trim() !== "";
  if (hasSelection) return false;

  // Check for ignored targets
  if (e.target.closest("button") ||
      e.target.closest("form") ||
      e.target.closest("input") ||
      e.target.closest("select") ||
      e.target.closest("textarea") ||
      e.target.closest("[contenteditable='true']") ||
      e.target.closest("figure") ||
      e.target.closest(".dropdown") ||
      e.target.closest("[data-id=activity_actions]") ||
      e.target.closest("[data-id=labelled_widget]")) {
    return false;
  }

  // Skip if a tooltip/dropdown was just dismissed (click-outside closing a tooltip)
  const visibleTooltip = document.querySelector('.tooltip[style*="display: block"]');
  if (visibleTooltip) return false;

  const anchor = e.target.closest("a");

  if (!trigger && !uri) return false;

  // Anchor check
  if (anchor && !anchor.classList.contains("preview_activity_link")) return false;

  return true;
}

let PreviewActivity = {
  isTruncated(element) {
    if (element && 
        (element.offsetHeight < element.scrollHeight ||
         element.offsetWidth < element.scrollWidth)) {
      return true;
    }
    return false;
  },
  
  mounted() {
    // Track pointer movement to distinguish taps from scrolls on mobile
    this.pointerState = { startX: 0, startY: 0, moved: false };

    this.openPreview = (e, opts = {}) => {
      // If the click originated inside a nested article (e.g. a quoted post
      // preview), let that inner article's hook handle it — don't also open
      // the outer article's preview from the bubbled event.
      const nearestArticle = e.target.closest("article");
      if (nearestArticle && nearestArticle !== this.el) {
        return;
      }

      const trigger = this.el.querySelector(".open_preview_link");
      const uri = this.el.dataset.href || trigger?.getAttribute("href");

      if (!shouldHandlePreviewOpen(e, trigger, this.pointerState, uri, {
        keyboard: opts.keyboard,
        container: this.el
      })) {
        return;
      }

      e.preventDefault();

      // In an embed, escape the frame rather than previewing/navigating in-frame
      // (the discussion view forbids framing). Named-target nav works cross-origin.
      const embedTarget = utils.embedLinkTarget();
      if (embedTarget && uri) {
        if (embedTarget === "_blank") {
          window.open(uri, "_blank", "noopener");
        } else {
          window.open(uri, embedTarget);
        }
        return;
      }

      if (utils.liveSocketConnected() && trigger) {
        const layout = utils.getScrollContainer();
        const previous_scroll = layout ? layout.scrollTop : null;
        const entryUrl = document.location.href;
        const session = previewState.save(entryUrl, uri, previous_scroll);

        if (!session) {
          window.location.assign(uri);
          return;
        }

        // Push BEFORE blanking the view, so WebKit's back-swipe snapshot of
        // the outgoing entry shows the feed rather than the loading overlay.
        try {
          history.pushState(previewState.historyState(session), "", session.previewUrl);
          trackHref();
        } catch(e) {
          console.warn("Failed to update browser history:", e);
        }

        utils.showLoadingState();
        overlayOpen = true;

        // After the first paint, not before: setting the scroll here forced a
        // synchronous layout (median 99 → 72 ms blocked at 4x CPU). Collapsing
        // the page has usually reset it already, so this is the safety net.
        // A single rAF still runs before the first paint; the second runs after.
        requestAnimationFrame(() => requestAnimationFrame(() => {
          window.scrollTo(0, 0);
          if (layout) layout.scrollTop = 0;
        }));

        this.pushEventTo(
          trigger,
          "open",
          {
            previous_url: session.entryUrl,
            previous_scroll: session.previousScroll
          }
        );
      } else if (uri) {
        window.location.assign(uri);
      }
    };

    this.handlePointerDown = (e) => {
      this.pointerState.startX = e.clientX;
      this.pointerState.startY = e.clientY;
      this.pointerState.moved = false;
    };

    this.handlePointerMove = (e) => {
      if (this.pointerState.moved) return;
      const dx = e.clientX - this.pointerState.startX;
      const dy = e.clientY - this.pointerState.startY;
      if (dx * dx + dy * dy > utils.scrollThreshold * utils.scrollThreshold) {
        this.pointerState.moved = true;
      }
    };

    // Store handler reference for proper cleanup
    this.handleClick = (e) => {
      this.openPreview(e);
    };

    this.handleKeyDown = (e) => {
      if (e.key === "Enter" || e.key === " ") {
        this.openPreview(e, { keyboard: true });
      }
    };

    // Add event listeners
    this.el.addEventListener("pointerdown", this.handlePointerDown);
    this.el.addEventListener("pointermove", this.handlePointerMove);
    this.el.addEventListener("click", this.handleClick);
    this.el.addEventListener("keydown", this.handleKeyDown);
  },

  destroyed() {
    // Clean up event listeners
    if (this.handlePointerDown) {
      this.el.removeEventListener("pointerdown", this.handlePointerDown);
    }
    if (this.handlePointerMove) {
      this.el.removeEventListener("pointermove", this.handlePointerMove);
    }
    if (this.handleClick) {
      this.el.removeEventListener("click", this.handleClick);
    }
    if (this.handleKeyDown) {
      this.el.removeEventListener("keydown", this.handleKeyDown);
    }
  }
};

let PreviewExtra = {
  mounted() {
    
    // Clean up loading state when extra view is shown
    const previewContent = document.querySelector(utils.selectors.previewContent);
    if (previewContent) {
      const loadingElement = previewContent.querySelector(utils.selectors.loadingMessage);
      if (loadingElement && loadingElement.textContent && loadingElement.textContent.includes("Loading")) {
        loadingElement.style.display = "none";
      }
    }
    
    // Store handler reference for proper cleanup
    this.handleClick = (e) => {
      e.preventDefault();
      this.pushEventTo(utils.selectors.previewContent, "show_extra", {});
    };
    
    // Add event listener
    this.el.addEventListener("click", this.handleClick);
  },
  
  destroyed() {
    // Clean up event listener
    if (this.handleClick) {
      this.el.removeEventListener("click", this.handleClick);
    }
  }
};

let ClosePreview = {
  mounted() {
    this.handleClick = (e) => {
      e.preventDefault();
      closePreviewFully();
    };

    this.el.addEventListener("click", this.handleClick);
  },

  destroyed() {
    if (this.handleClick) {
      this.el.removeEventListener("click", this.handleClick);
    }
  }
};

let PreviewContainer = {
  mounted() {
    previewHook = this;
    // Module state must match reality after any remount.
    overlayOpen = utils.isPreviewVisible();
    this.cleanupStaleSession();
    this.syncVisibility();
  },

  updated() {
    this.syncVisibility();
  },

  reconnected() {
    this.maybeReopenAfterReconnect();
  },

  destroyed() {
    if (previewHook === this) previewHook = null;
  },

  // Reloaded directly onto the preview URL: the page itself shows the
  // content now — drop the session and the entry's marker.
  cleanupStaleSession() {
    const session = previewState.read();
    if (!session) return;

    if (utils.documentLoadedAt(session.previewUrl)) {
      previewState.clear();
      stripPreviewHistoryMarker();
    } else if (!previewState.isCurrent(session)) {
      previewState.clear();
    }
  },

  // Server renders are advisory: re-hide (and re-notify) if one re-shows an
  // overlay the client closed.
  syncVisibility() {
    if (!overlayOpen && utils.isPreviewVisible()) {
      utils.hidePreviewNow();
      // The reply to our own "close" always re-shows it once (the server sets
      // hide_main a message later), so re-sending then only cost a second round
      // trip and render. Outside the closing window, re-send: the server missed it.
      if (!isClosingPreview()) notifyServerClose();
    }
  },

  // One shot after reconnect: re-request the content if its trigger is on the
  // page, else settle cleanly on the real page.
  maybeReopenAfterReconnect() {
    if (!overlayOpen) return;

    const session = previewState.read();
    if (session && previewState.isCurrent(session) && previewState.isPreviewHistory()) {
      const trigger = utils.findPreviewTrigger(session.previewUrl);
      if (trigger) {
        utils.showLoadingState();
        this.pushEventTo(trigger, "open", {
          previous_url: session.entryUrl,
          previous_scroll: session.previousScroll
        });
        return;
      }
    }

    overlayOpen = false;
    utils.hidePreviewNow();
    stripPreviewHistoryMarker();
    previewState.clear();
  }
};

// Simple MainFeed hook to handle feed visibility during navigation
let MainFeed = {
  mounted() {
    const shouldHide = sessionStorage.getItem(utils.storageKeys.hideFeed) === 'true';
    
    // Track timeout for cleanup
    this.showFeedTimeout = null;
    
    if (!previewState.isCurrent()) {
      previewState.clear();
    }
    
    if (shouldHide) {
      const feedElement = document.querySelector(utils.selectors.feedActivityList);
      if (feedElement) {
        feedElement.style.opacity = "0";
        feedElement.style.transition = utils.opacityTransition(utils.timing.standardTransition);
        
        // Store the element for later
        this.hiddenFeedElement = feedElement;
        
        // Show the feed after a brief delay to allow transition to be set
        this.showFeedTimeout = setTimeout(() => {
          if (this.hiddenFeedElement) {
            this.hiddenFeedElement.style.opacity = "1";
            try {
              sessionStorage.removeItem(utils.storageKeys.hideFeed);
            } catch(e) {
              console.warn("Failed to remove hideFeed flag:", e);
            }
            this.hiddenFeedElement = null;
          }
          this.showFeedTimeout = null;
        }, 10);
      }
    }
  },
  
  destroyed() {
    // Clean up timeout first
    if (this.showFeedTimeout) {
      clearTimeout(this.showFeedTimeout);
      this.showFeedTimeout = null;
    }
    
    // Make sure feed is visible if we're being destroyed
    if (this.hiddenFeedElement) {
      this.hiddenFeedElement.style.opacity = "1";
      this.hiddenFeedElement = null;
    }
  }
};

export { PreviewActivity, PreviewExtra, ClosePreview, PreviewContainer, MainFeed };
