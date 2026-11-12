// Smart Input Container Hook
// Handles scroll lock + visual viewport sync for mobile composer

// bare specifier, resolved via NODE_PATH: these hooks are collected into config/current_flavour/assets/hooks/ before bundling, so a path relative to this file's source location would not resolve from where esbuild actually reads it
import { hasScrollableAncestor } from "scroll.js";

export default {
  _observer: null,
  _viewportHandler: null,
  _touchMoveHandler: null,
  _isLocked: false,

  mounted() {
    this._setupResize();
    this._observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === "attributes" && mutation.attributeName === "class") {
          const isHidden = this.el.classList.contains("translate-y-100");
          this._setComposerOpen(!isHidden);
          if (isHidden && this._isLocked) {
            this._unlockScroll();
            this._stopViewportSync();
          } else if (!isHidden && !this._isLocked) {
            this._lockScroll();
            this._startViewportSync();
          }
        }
      }
    });

    this._observer.observe(this.el, { attributes: true, attributeFilter: ["class"] });

    // Check initial state
    if (!this.el.classList.contains("translate-y-100") && !this.el.hasAttribute("data-hidden")) {
      this._setComposerOpen(true);
      this._lockScroll();
      this._startViewportSync();
    }
  },

  destroyed() {
    this._stopResize();
    if (this._observer) {
      this._observer.disconnect();
      this._observer = null;
    }
    this._stopViewportSync();
    if (this._isLocked) {
      this._unlockScroll();
    }
    this._setComposerOpen(false);
  },

  updated() {
    this._syncResize();
    this._syncFullscreen();
  },

  _setupResize() {
    this._resizeHeight = null;
    this._fullscreen = false;
    this._fullscreenClick = event => {
      const button = event.target.closest("[data-role=composer_fullscreen]");
      if (!button || !this.el.contains(button) || this._isMobile()) return;
      if (!this._fullscreen && this._resizeHeight === null) {
        this._resizeHeight = this.el.getBoundingClientRect().height;
      }
      this._resizeDrag = null;
      this._fullscreen = !this._fullscreen;
      this._syncFullscreen();
      this._syncResize();
    };
    this.el.addEventListener("click", this._fullscreenClick);
    const isHandle = event => this.el.contains(event.target.closest("[data-role=composer_resize]"));
    this._resizeDown = event => {
      if (this._fullscreen || this._isMobile() || event.button !== 0 || !isHandle(event)) return;
      event.preventDefault();
      event.target.setPointerCapture(event.pointerId);
      this._resizeDrag = { id: event.pointerId, y: event.clientY, height: this.el.getBoundingClientRect().height };
    };
    this._resizeMove = event => {
      if (!this._resizeDrag || event.pointerId !== this._resizeDrag.id) return;
      this._resizeHeight = this._resizeDrag.height + this._resizeDrag.y - event.clientY;
      this._syncResize();
    };
    this._resizeEnd = () => { this._resizeDrag = null; };
    this._resizeKey = event => {
      if (this._fullscreen || this._isMobile() || !isHandle(event)) return;
      const height = this._resizeHeight ?? this.el.getBoundingClientRect().height;
      const next = { ArrowUp: height + 24, ArrowDown: height - 24, Home: 360, End: window.innerHeight - 32 }[event.key];
      if (next === undefined) return;
      event.preventDefault();
      this._resizeHeight = next;
      this._syncResize();
    };
    this._resizeViewport = () => { this._resizeDrag = null; this._syncResize(); };
    this.el.addEventListener("pointerdown", this._resizeDown);
    this.el.addEventListener("keydown", this._resizeKey);
    window.addEventListener("pointermove", this._resizeMove);
    window.addEventListener("pointerup", this._resizeEnd);
    window.addEventListener("pointercancel", this._resizeEnd);
    window.addEventListener("resize", this._resizeViewport);
    this._syncResize();
  },

  _syncFullscreen() {
    const root = document.documentElement;
    if (this._fullscreen) root.dataset.composerFullscreen = "true";
    else delete root.dataset.composerFullscreen;
    const button = this.el.querySelector("[data-role=composer_fullscreen]");
    if (button) {
      const label = this._fullscreen ? button.dataset.restoreLabel : button.dataset.expandLabel;
      button.setAttribute("aria-pressed", String(this._fullscreen));
      button.setAttribute("aria-label", label);
      button.setAttribute("title", label);
    }
  },

  _syncResize() {
    if (this._fullscreen || this._isMobile()) return;
    const max = Math.max(0, window.innerHeight - 32);
    const min = Math.min(360, max);
    const height = Math.round(Math.min(max, Math.max(min, this._resizeHeight ?? this.el.getBoundingClientRect().height)));
    if (this._resizeHeight !== null) {
      this._resizeHeight = height;
      // Root variables survive server patches without replacing the editor.
      document.documentElement.style.setProperty("--composer-desktop-height", `${height}px`);
    }
    const handle = this.el.querySelector("[data-role=composer_resize]");
    handle?.setAttribute("aria-valuemin", min);
    handle?.setAttribute("aria-valuemax", max);
    handle?.setAttribute("aria-valuenow", height);
  },

  _stopResize() {
    this.el.removeEventListener("click", this._fullscreenClick);
    delete document.documentElement.dataset.composerFullscreen;
    this.el.removeEventListener("pointerdown", this._resizeDown);
    this.el.removeEventListener("keydown", this._resizeKey);
    window.removeEventListener("pointermove", this._resizeMove);
    window.removeEventListener("pointerup", this._resizeEnd);
    window.removeEventListener("pointercancel", this._resizeEnd);
    window.removeEventListener("resize", this._resizeViewport);
    this._resizeDrag = null;
    document.documentElement.style.removeProperty("--composer-desktop-height");
  },

  // Distinct from scrollLocked: at wider widths the open composer doesn't lock
  // scrolling, but pull-to-refresh must still not reload over a draft.
  _setComposerOpen(open) {
    if (open) document.documentElement.dataset.composerOpen = "true";
    else delete document.documentElement.dataset.composerOpen;
  },

  _isMobile() {
    return window.matchMedia("(max-width: 768px), (pointer: coarse) and (max-width: 1024px)").matches;
  },

  _lockScroll() {
    if (!this._isMobile()) return;

    // Modern scroll-lock: `overflow: hidden` on the scroll roots, no body
    // position changes. The deprecated `body { position: fixed; top: -scrollY }`
    // pattern preserved scroll visually but corrupted `position: fixed`
    // descendants (notably the mobile dock) on iOS Safari. With overflow-only
    // locking the current scroll offset is retained automatically — no
    // save/restore needed — and fixed descendants stay anchored.
    document.documentElement.style.overflow = "hidden";
    document.documentElement.style.overscrollBehavior = "none";
    document.body.style.overflow = "hidden";
    document.body.style.overscrollBehavior = "none";
    // declared lock signal for other gesture code (pull_to_refresh.js)
    document.documentElement.dataset.scrollLocked = "true";
    // Block touch-scrolling everywhere except inside scrollable children (editor area).
    // iOS allows touch-scrolling even inside overflow:hidden containers.
    this._touchMoveHandler = (e) => {
      // Touch is outside composer OR inside non-scrollable part — block it; two fingers are a pinch zoom, let it through
      if (e.touches?.length < 2 && !hasScrollableAncestor(e.target, this.el)) e.preventDefault();
    };
    document.addEventListener("touchmove", this._touchMoveHandler, { passive: false });

    this._isLocked = true;
  },

  _unlockScroll() {
    if (this._touchMoveHandler) {
      document.removeEventListener("touchmove", this._touchMoveHandler);
      this._touchMoveHandler = null;
    }
    document.documentElement.style.overflow = "";
    document.documentElement.style.overscrollBehavior = "";
    document.body.style.overflow = "";
    document.body.style.overscrollBehavior = "";
    delete document.documentElement.dataset.scrollLocked;
    this._isLocked = false;
  },

  _startViewportSync() {
    if (!this._isMobile() || !window.visualViewport) return;

    // the full height before the keyboard opens: the container keeps it, with the keyboard as bottom padding
    const measure = () => {
      this._fullHeight = window.visualViewport.height * window.visualViewport.scale;
      this._fullWidth = window.visualViewport.width * window.visualViewport.scale;
    };
    measure();

    // on the container itself (its style attribute is kept from LiveView patches by JS.ignore_attributes), so only the composer restyles
    this._viewportHandler = () => {
      const vv = window.visualViewport;
      if (vv.width * vv.scale !== this._fullWidth) measure(); // rotation: a new full height
      // in screen px, so pinch zoom (smaller vv.height, scale > 1) is not taken for a keyboard
      const visibleHeight = vv.height * vv.scale;
      const keyboardHeight = this._fullHeight - visibleHeight;
      const keyboardOpen = keyboardHeight > 50;
      if (!keyboardOpen && visibleHeight > this._fullHeight) this._fullHeight = visibleHeight; // address bar
      // a hardware keyboard opens no keyboard but iOS still scrolls the viewport: follow it (the full height stays right: its accessory bar covers the bottom safe area, checked on the iPhone simulator)
      const shifted = !keyboardOpen && vv.scale === 1 && vv.offsetTop > 0;

      this._setViewportVars({
        "--composer-height": keyboardOpen ? `${this._fullHeight}px` : null,
        "--composer-top": keyboardOpen || shifted ? `${vv.offsetTop}px` : null,
        "--composer-pb": keyboardOpen ? `${keyboardHeight}px` : null,
      });

      // the layout viewport keeps its height (`interactive-widget=resizes-visual`), so no media query sees the keyboard
      const root = document.documentElement;
      if (keyboardOpen === (root.dataset.composerKeyboard === "true")) return;
      if (keyboardOpen) {
        root.dataset.composerKeyboard = "true";
        this._collapseHeader();
      } else delete root.dataset.composerKeyboard;
    };

    this._viewportHandler();

    window.visualViewport.addEventListener("resize", this._viewportHandler);
    window.visualViewport.addEventListener("scroll", this._viewportHandler);
  },

  // writes only what differs from the element's current style, so a style cleared by something else is put back
  _setViewportVars(vars) {
    for (const [name, value] of Object.entries(vars)) {
      if ((this.el.style.getPropertyValue(name) || null) === value) continue;
      if (value === null) this.el.style.removeProperty(name);
      else this.el.style.setProperty(name, value);
    }
  },

  // typing gets the room: an expanded header folds back to its summary line, unless the keyboard is for a field in the header
  _collapseHeader() {
    const header = document.getElementById("composer_header");
    if (!header?.hasAttribute("data-controls-open") || header.contains(document.activeElement)) return;
    this.js?.().removeAttribute(header, "data-controls-open");
    const summary = document.getElementById("composer_summary");
    if (summary) this.js?.().setAttribute(summary, "aria-expanded", "false");
  },

  _stopViewportSync() {
    if (this._viewportHandler && window.visualViewport) {
      window.visualViewport.removeEventListener("resize", this._viewportHandler);
      window.visualViewport.removeEventListener("scroll", this._viewportHandler);
    }
    this._viewportHandler = null;
    this._setViewportVars({ "--composer-height": null, "--composer-top": null, "--composer-pb": null });
    delete document.documentElement.dataset.composerKeyboard;
  },
};
