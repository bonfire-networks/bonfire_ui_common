
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

window.addEventListener("popstate", (e) => {
  const previousHref = lastKnownHref;
  trackHref();

  if (isClosingPreview()) return;
  if (!previewState.isPreviewHistory(e.state)) return;
  if (stripHash(window.location.href) !== stripHash(previousHref)) return;
  if (utils.isPreviewVisible()) return;

  try {
    history.back();
  } catch (err) {
    console.warn("Failed to skip orphaned preview history entry:", err);
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
    fastTransition: "50ms",
    standardTransition: "180ms",
    easing: "cubic-bezier(0.19, 1, 0.22, 1)",
    previewRecoveryTimeout: 2000
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

  // Track active timeouts for cleanup
  activeTimeouts: new Set(),
  
  // Debounce state for preventing rapid operations
  debounceState: {
    scrollRestoration: false,
    lastScrollRestore: 0
  },
  
  // Timeout management for memory leak prevention
  createTimeout(callback, delay) {
    const timeoutId = setTimeout(() => {
      this.activeTimeouts.delete(timeoutId);
      callback();
    }, delay);
    this.activeTimeouts.add(timeoutId);
    return timeoutId;
  },
  
  clearTimeout(timeoutId) {
    if (timeoutId) {
      clearTimeout(timeoutId);
      this.activeTimeouts.delete(timeoutId);
    }
  },
  
  clearAllTimeouts() {
    this.activeTimeouts.forEach(timeoutId => clearTimeout(timeoutId));
    this.activeTimeouts.clear();
  },
  
  // Consistent preview visibility check - single source of truth
  isPreviewVisible() {
    const previewContent = document.querySelector(this.selectors.previewContent);
    return previewContent && 
           previewContent.style.display !== "none" && 
           previewContent.getAttribute("data-show") === "true";
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
  showLoadingState({ animate = true } = {}) {
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
    
    // Hide inner content for better visual experience 
    const innerContent = document.getElementById(this.selectors.innerContent.substring(1));
    if (innerContent) {
      innerContent.style.transition = this.opacityTransition(this.timing.fastTransition, animate);
      innerContent.style.opacity = "0";
      innerContent.style.pointerEvents = "none";
      innerContent.style.visibility = "hidden";
    }
  },
  
  // Apply scroll position with consistent approach (single method to avoid conflicts)
  applyScroll(layout, scrollPosition) {
    if (!layout || scrollPosition === null || scrollPosition === undefined) return false;
    
    try {
      // Apply scroll using multiple methods for maximum compatibility
      layout.scrollTop = scrollPosition;
      
      // Use scrollTo API as primary method
      if (layout.scrollTo) {
        layout.scrollTo({
          top: scrollPosition,
          behavior: "auto"
        });
      }
      
      // Also apply to window as fallback for edge cases
      window.scrollTo(0, scrollPosition);
      
      return true;
    } catch(e) {
      console.error("Error applying scroll:", e);
      return false;
    }
  },
  
  // Hide feed to prevent flash during navigation
  hideFeed({ animate = true } = {}) {
    try {
      sessionStorage.setItem(this.storageKeys.hideFeed, 'true');
      const feedElement = document.querySelector(this.selectors.feedActivityList);
      if (feedElement) {
        feedElement.style.transition = this.opacityTransition(this.timing.fastTransition, animate);
        feedElement.style.opacity = "0";
        return feedElement;
      }
    } catch(e) {
      console.warn("Failed to hide feed:", e);
    }
    return null;
  },

  showMainContent({ animate = true } = {}) {
    const innerContent = document.getElementById(this.selectors.innerContent.substring(1));

    if (innerContent) {
      innerContent.style.transition = this.opacityTransition(this.timing.standardTransition, animate);
      innerContent.style.opacity = "1";
      innerContent.style.pointerEvents = "auto";
      innerContent.style.visibility = "visible";
    }
  },
  
  // Show feed after scrolling applied
  showFeed(feedElement) {
    if (!feedElement) {
      feedElement = document.querySelector(this.selectors.feedActivityList);
    }
    
    if (feedElement) {
      feedElement.style.opacity = "1";
      try {
        sessionStorage.removeItem(this.storageKeys.hideFeed);
      } catch(e) {
        console.warn("Failed to remove feed hide flag:", e);
      }
    }
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

// Clean up active timeouts on page unload to prevent memory leaks
if (typeof window !== 'undefined') {
  window.addEventListener('beforeunload', () => utils.clearAllTimeouts());
}

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

        utils.showLoadingState({ animate: !opts.keyboard });

        window.scrollTo(0, 0);
        if (layout) layout.scrollTop = 0;

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
    
    // Store the handler references for proper cleanup
    this.handleClick = (e) => {
      e.preventDefault();
      this.closePreview({ restoreUrl: true });
    };
    
    this.handlePopState = (e) => {
      if (isClosingPreview()) {
        return;
      }

      if (utils.isPreviewVisible() && !previewState.isPreviewHistory(e.state)) {
        this.closePreview({ restoreUrl: false });
      }
    };
    
    // Add event listeners
    this.el.addEventListener("click", this.handleClick);
    window.addEventListener("popstate", this.handlePopState);
  },
  
  destroyed() {
    // Clean up event listeners
    if (this.handleClick) {
      this.el.removeEventListener("click", this.handleClick);
    }
    
    if (this.handlePopState) {
      window.removeEventListener("popstate", this.handlePopState);
    }
  },

  closePreview(opts = {}) {
    const session = previewState.read();
    const navData = {
      previous_url: session?.entryUrl || document.referrer || window.location.href,
      previous_scroll: session?.previousScroll || 0
    };

    markClosingPreview();
    this.pushEventTo(utils.selectors.previewContent, "close", {});
    this.restoreUrlAndScroll(navData, opts);
  },

  // Enhanced method for more reliable URL and scroll restoration
  restoreUrlAndScroll(navData, opts = {}) {
    // Implement debouncing to prevent rapid successive calls
    const now = Date.now();
    if (utils.debounceState.scrollRestoration && (now - utils.debounceState.lastScrollRestore) < 300) {
      return;
    }
    utils.debounceState.scrollRestoration = true;
    utils.debounceState.lastScrollRestore = now;

    if (opts.restoreUrl !== false && navData.previous_url && navData.previous_url !== window.location.href) {
      if (previewState.isPreviewHistory(history.state)) {
        try {
          history.back();
        } catch(e) {
          console.warn("Failed to navigate back from preview:", e);
        }
      } else {
        try {
          // Keep LiveView's position/type bookkeeping; only the URL changes.
          history.replaceState(history.state || {}, "", navData.previous_url);
          trackHref();
        } catch(e) {
          console.warn("Failed to restore URL:", e);
        }
      }
    }

    // Ensure we have a valid scroll position (default to 0 if none found)
    const scrollPosition = parseInt(navData.previous_scroll, 10);
    if (isNaN(scrollPosition)) {
      navData.previous_scroll = 0;
    } else {
      navData.previous_scroll = scrollPosition;
    }

    // Hide feed to prevent flash
    const animate = opts.animate !== false;
    const feedElement = utils.hideFeed({ animate });

    utils.showMainContent({ animate });

    // Delay scroll restoration until after LiveView updates are complete
    setTimeout(() => {
      this.applyScrollRestore(navData.previous_scroll, feedElement);
      previewState.clear();
    }, 100);

    // Reset debounce state immediately after operation completes
    utils.debounceState.scrollRestoration = false;
  },
  
  // Scroll restoration with MutationObserver for reliable timing
  applyScrollRestore(position, feedElement) {
    const layout = utils.getScrollContainer();

    if (!layout) {
      window.scrollTo(0, position);
      utils.showFeed(feedElement);
      return;
    }

    try {
      // Apply scroll with utility method
      utils.applyScroll(layout, position);

      // Force scroll restoration with MutationObserver to handle LiveView interference
      if (position > 0) {
        // Method 1: Immediate application
        if (layout.scrollTo) {
          layout.scrollTo({ top: position, behavior: 'instant' });
        }
        layout.scrollTop = position;

        // Method 2: Use MutationObserver for more reliable timing than setTimeout
        if (typeof MutationObserver !== 'undefined') {
          let attempts = 0;
          const maxAttempts = 5;
          const observer = new MutationObserver(() => {
            if (layout.scrollTop !== position && attempts < maxAttempts) {
              layout.scrollTop = position;
              attempts++;
            } else {
              observer.disconnect();
            }
          });
          observer.observe(layout, { childList: true, subtree: true, attributes: true });
          // Disconnect after a reasonable timeout to prevent memory leaks
          setTimeout(() => observer.disconnect(), 500);
        } else {
          // Fallback for browsers without MutationObserver
          const retryScroll = () => {
            layout.scrollTop = position;
            if (layout.scrollTop === 0 && position > 0) {
              setTimeout(() => { layout.scrollTop = position; }, 50);
            }
          };
          requestAnimationFrame(retryScroll);
        }
      }

      // Show feed immediately - scroll is applied synchronously
      utils.showFeed(feedElement);

    } catch(e) {
      console.error("Error during scroll restoration:", e);
      utils.showFeed(feedElement); // Always show feed, even if scroll fails
    }
  }
};
  
let CloseAll = {
  mounted() {
    if (!utils.liveSocketConnected()) return;

    const trigger = this.el.querySelector(".open_preview_link");
    
    // Simplified close function without complex method binding
    this.triggerClose = ({ animate = true } = {}) => {
      const session = previewState.read();
      const storedPosition = session?.previousScroll || 0;

      markClosingPreview();

      // Send event to LiveView to handle state changes
      this.pushEventTo(trigger || utils.selectors.previewContent, "close", {});
      utils.showMainContent({ animate });
      
      // Simple scroll restoration fallback
      try {
        const layout = utils.getScrollContainer();
        if (layout) {
          utils.applyScroll(layout, storedPosition);
        } else {
          window.scrollTo(0, storedPosition);
        }
        
        previewState.clear();
      } catch(e) {
        console.warn("Error during simple scroll restoration:", e);
      }
    };
    
    // Simplified click handler using the centralized visibility check
    this.handleClick = (e) => {
      // Only prevent default and trigger close if preview content is actually visible
      if (utils.isPreviewVisible()) {
        e.preventDefault();
        this.triggerClose();
      }
      // Otherwise, let the link work normally
    };
    
    // Store reference to DOM event handlers for cleanup
    this.handleKeyDown = (e) => {
      // Add Escape key support for accessibility - only if preview is visible
      if (e.key === 'Escape' && utils.isPreviewVisible()) {
        this.triggerClose({ animate: false });
      }
    };
    
    // Add event listeners
    this.el.addEventListener("click", this.handleClick);
    document.addEventListener("keydown", this.handleKeyDown);
  },
  
  destroyed() {
    // Clean up event listeners
    if (this.handleClick) {
      this.el.removeEventListener("click", this.handleClick);
    }
    
    if (this.handleKeyDown) {
      document.removeEventListener("keydown", this.handleKeyDown);
    }
  }
};

let PreviewContainer = {
  mounted() {
    this.recoveringPreview = false;
    this.previewRecoveryObserver = null;
    this.previewRecoveryTimeout = null;
    this.recoverPreview();
  },

  reconnected() {
    this.recoverPreview();
  },

  destroyed() {
    this.cancelPreviewRecovery();
  },

  recoverPreview() {
    if (this.recoveringPreview || this.previewRecoveryObserver || isClosingPreview()) return;

    const session = previewState.read();
    if (!session || !previewState.isCurrent(session) || utils.isPreviewVisible()) return;

    // Refreshed onto the real preview page: it's already showing, so drop the
    // stale session — and the entry's preview marker, which survives reloads
    // and would later feed the orphan detector — instead of hard-reloading.
    if (utils.documentLoadedAt(session.previewUrl)) {
      previewState.clear();
      stripPreviewHistoryMarker();
      return;
    }

    // A stored URL alone is not enough to recover an overlay: after back/forward
    // traversal it can briefly outlive the history entry that actually owns it.
    if (!previewState.isPreviewHistory()) {
      previewState.clear();
      return;
    }

    const trigger = utils.findPreviewTrigger(session.previewUrl);
    if (!trigger) {
      this.waitForPreviewTrigger(session);
      return;
    }

    this.openRecoveredPreview(session, trigger);
  },

  waitForPreviewTrigger(session) {
    if (this.previewRecoveryObserver || this.previewRecoveryTimeout) return;

    if (typeof MutationObserver !== "undefined" && document.documentElement) {
      this.previewRecoveryObserver = new MutationObserver(() => {
        this.continuePreviewRecovery(session);
      });
      this.previewRecoveryObserver.observe(document.documentElement, {
        childList: true,
        subtree: true
      });
    }

    this.previewRecoveryTimeout = utils.createTimeout(() => {
      this.previewRecoveryTimeout = null;

      if (!this.previewRecoveryActive(session)) {
        this.cancelPreviewRecovery();
        return;
      }

      const trigger = utils.findPreviewTrigger(session.previewUrl);
      if (trigger) {
        this.openRecoveredPreview(session, trigger);
      } else {
        this.abandonPreviewRecovery(session);
      }
    }, utils.timing.previewRecoveryTimeout);
  },

  continuePreviewRecovery(session) {
    if (!this.previewRecoveryActive(session)) {
      this.cancelPreviewRecovery();
      return;
    }

    if (utils.isPreviewVisible()) {
      this.cancelPreviewRecovery();
      return;
    }

    const trigger = utils.findPreviewTrigger(session.previewUrl);
    if (trigger) {
      this.openRecoveredPreview(session, trigger);
    }
  },

  previewRecoveryActive(session) {
    if (isClosingPreview() ||
        !previewState.isPreviewHistory() ||
        !previewState.isCurrent(session)) {
      return false;
    }

    const storedSession = previewState.read();
    return !!storedSession &&
      storedSession.entryUrl === session.entryUrl &&
      storedSession.previewUrl === session.previewUrl;
  },

  openRecoveredPreview(session, trigger) {
    // Never blank the view for an "open" the server can't receive: once the
    // loading overlay is up, isPreviewVisible() blocks any later recovery.
    // reconnected() re-enters recoverPreview when the socket is back.
    if (!utils.liveSocketConnected()) {
      this.cancelPreviewRecovery();
      return;
    }

    this.cancelPreviewRecovery();
    this.recoveringPreview = true;
    utils.showLoadingState();

    this.pushEventTo(
      trigger,
      "open",
      {
        previous_url: session.entryUrl,
        previous_scroll: session.previousScroll
      }
    );

    utils.createTimeout(() => {
      this.recoveringPreview = false;
    }, 500);
  },

  abandonPreviewRecovery(session) {
    this.cancelPreviewRecovery();
    markClosingPreview();
    previewState.clear();

    this.pushEventTo(utils.selectors.previewContent, "close", {});
    utils.showMainContent({ animate: false });

    const layout = utils.getScrollContainer();
    if (layout) {
      utils.applyScroll(layout, session.previousScroll);
    } else {
      window.scrollTo(0, session.previousScroll);
    }
    utils.showFeed();

    // Consume the synthetic overlay entry when it still owns the current
    // history position. This is programmatic history traversal, which mobile
    // WebKit handles more reliably than an edge-swipe-created popstate.
    if (previewState.isPreviewHistory(history.state)) {
      try {
        history.back();
      } catch(e) {
        console.warn("Failed to leave unrecoverable preview:", e);
      }
    } else if (previewState.sameOriginUrl(window.location.href) === session.previewUrl) {
      // Corrupt/stale state must still never turn recovery into a page reload.
      try {
        history.replaceState(history.state || {}, "", session.entryUrl);
        trackHref();
      } catch(e) {
        console.warn("Failed to restore preview entry URL:", e);
      }
    }
  },

  cancelPreviewRecovery() {
    if (this.previewRecoveryObserver) {
      this.previewRecoveryObserver.disconnect();
      this.previewRecoveryObserver = null;
    }

    if (this.previewRecoveryTimeout) {
      utils.clearTimeout(this.previewRecoveryTimeout);
      this.previewRecoveryTimeout = null;
    }
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

export { PreviewActivity, PreviewExtra, ClosePreview, CloseAll, PreviewContainer, MainFeed };
