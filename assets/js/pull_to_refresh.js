// Pull-to-refresh for the installed PWA, which has no other way to reload a
// page (live_socket_lifecycle.js suppresses LiveView's automatic mobile
// reloads). No-ops outside standalone display modes.
//
// A `data-ptr-refresh="<event>"` attribute on a LiveComponent root names the
// event that reloads it in place; pages without one get location.reload().
import { prefersReducedMotion } from "./motion";
import { hasScrollableAncestor } from "./scroll.js";
import { flagEnabled } from "./live_socket_lifecycle.js";

// Mirrors pwa-utils.js in bonfire_notify (optional extension, so not imported);
// deliberately wider: minimal-ui/fullscreen lack a reload control too.
const isPWAMode = () =>
  window.matchMedia(
    "(display-mode: standalone), (display-mode: minimal-ui), (display-mode: fullscreen)",
  ).matches || window.navigator.standalone === true;

const THRESHOLD_PX = 72; // visible pull distance that arms the refresh
const MAX_PULL_PX = 130; // asymptotic cap on indicator travel
const SLOP_PX = 10; // movement before we commit to a direction
const HIDDEN_Y_PX = -64; // indicator resting position above the viewport
const PARKED_Y_PX = 8; // indicator position while refreshing
const MIN_SPINNER_MS = 500; // mirror NEWER_LOADING_MIN_MS in feed_live.hooks.js
const REPLY_TIMEOUT_MS = 8000; // push never acked -> hard reload
const TRANSITION = "transform 200ms ease, opacity 200ms ease";

export function setupPullToRefresh(liveSocket) {
  if (!(navigator.maxTouchPoints > 0)) return;
  // Debug override for DevTools device emulation:
  // localStorage.setItem("bonfire:ptr:force", "true")
  if (!isPWAMode() && !flagEnabled("bonfire:ptr:force")) return;

  let state = "idle"; // idle | tracking | pulling | refreshing
  let startTarget = null;
  let startX = 0;
  let startY = 0;
  let lastVisible = 0;
  let refreshStartedAt = 0;
  let hideTimer = null;
  let abortRefresh = null;

  let indicator = null;
  let pill = null;
  let arrow = null;
  let spinner = null;

  const ensureIndicator = () => {
    // on <body>, outside the LiveView container, so morphdom never touches it
    if (indicator && document.body.contains(indicator)) return;
    indicator = document.createElement("div");
    indicator.setAttribute("role", "status");
    indicator.setAttribute("aria-live", "polite");
    // z-max: sticky page headers are opaque z-[9999999] on mobile
    indicator.style.cssText =
      "position:fixed;left:0;right:0;top:env(safe-area-inset-top,0px);z-index:var(--z-max,9999999999999);display:none;justify-content:center;pointer-events:none;";
    pill = document.createElement("div");
    pill.className =
      "flex max-w-full items-center gap-2 rounded-full bg-base-100 px-3 py-2 shadow-md";
    pill.style.transition = TRANSITION;
    arrow = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    arrow.setAttribute("viewBox", "0 0 16 16");
    arrow.setAttribute("width", "16");
    arrow.setAttribute("height", "16");
    arrow.setAttribute("fill", "none");
    arrow.setAttribute("aria-hidden", "true");
    arrow.classList.add("text-base-content", "shrink-0");
    arrow.innerHTML =
      '<path d="M8 2v11m0 0 4.5-4.5M8 13 3.5 8.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>';
    arrow.style.transition = "transform 150ms ease";
    spinner = document.createElement("span");
    spinner.className =
      "loading loading-spinner loading-sm shrink-0 text-primary motion-reduce:animate-none";
    spinner.setAttribute("aria-hidden", "true");
    spinner.style.display = "none";
    pill.appendChild(arrow);
    pill.appendChild(spinner);
    indicator.appendChild(pill);
    document.body.appendChild(indicator);
  };

  const hideIndicator = () => {
    if (!indicator) return;
    indicator.style.display = "none";
    pill.style.transition = TRANSITION;
    pill.style.transform = "";
    pill.style.opacity = "";
    arrow.style.display = "";
    arrow.style.transform = "";
    spinner.style.display = "none";
  };

  const showIndicator = () => {
    ensureIndicator();
    // a previous retreat's pending hide would blank this gesture's display
    clearTimeout(hideTimer);
    indicator.style.display = "flex";
    if (prefersReducedMotion()) {
      // no finger-tracking: fade in statically once past the threshold
      pill.style.transform = `translateY(${PARKED_Y_PX}px)`;
      pill.style.opacity = "0";
    } else {
      pill.style.transition = "none";
      pill.style.transform = `translateY(${HIDDEN_Y_PX}px) scale(0.85)`;
      pill.style.opacity = "1";
    }
  };

  const renderPull = (visible) => {
    const past = visible >= THRESHOLD_PX;
    arrow.style.transform = past ? "rotate(180deg)" : "";
    if (prefersReducedMotion()) {
      pill.style.opacity = past ? "1" : "0";
      return;
    }
    const y = Math.min(HIDDEN_Y_PX + visible, PARKED_Y_PX + 16);
    const scale = 0.85 + 0.15 * Math.min(visible / THRESHOLD_PX, 1);
    pill.style.transform = `translateY(${y}px) scale(${scale})`;
  };

  const retreat = () => {
    // reduced motion keeps the opacity fade, skips only the movement
    if (!prefersReducedMotion()) {
      pill.style.transform = `translateY(${HIDDEN_Y_PX}px) scale(0.85)`;
    }
    pill.style.opacity = "0";
    clearTimeout(hideTimer);
    hideTimer = setTimeout(hideIndicator, 220);
  };

  const parkAndSpin = () => {
    arrow.style.display = "none";
    spinner.style.display = "";
    pill.style.opacity = "1";
    pill.style.transform = `translateY(${PARKED_Y_PX}px)`;
  };

  const settle = () => {
    const elapsed = performance.now() - refreshStartedAt;
    setTimeout(
      () => {
        retreat();
        state = "idle";
      },
      Math.max(0, MIN_SPINNER_MS - elapsed),
    );
  };

  const findTarget = () => {
    // refresh what's visible: the feed behind an open preview overlay sits in
    // a display:none #main-content (null offsetParent)
    const candidates = Array.from(
      document.querySelectorAll("[data-ptr-refresh]"),
    ).filter((el) => el.offsetParent !== null);
    return candidates.find((el) => el.closest("#main-content")) || candidates[0];
  };

  const dispatchRefresh = () => {
    const el = findTarget();

    if (!el || !liveSocket.isConnected()) {
      // The reload replaces the page; the spinner just stays up meanwhile.
      window.location.reload();
      return;
    }

    // js().push returns void: a page-loading-stop matching our element proves
    // the ack — until then the watchdog hard-reloads. After the ack the
    // target's own loading skeleton covers the async data arrival.
    const cleanup = () => {
      clearTimeout(reloadTimer);
      window.removeEventListener("phx:page-loading-stop", onStop);
      abortRefresh = null;
    };
    const onStop = (e) => {
      // only our own push's ack may disarm the watchdog
      if (e.detail?.kind !== "element") return;
      if (e.detail.target && e.detail.target !== el) return;
      cleanup();
      settle();
    };
    const reloadTimer = setTimeout(
      () => window.location.reload(),
      REPLY_TIMEOUT_MS,
    );
    window.addEventListener("phx:page-loading-stop", onStop);
    abortRefresh = cleanup;
    // without an explicit `target`, targetComponentID resolves null and the
    // event lands on the parent LiveView instead of the component
    liveSocket.js().push(el, el.getAttribute("data-ptr-refresh"), {
      target: el,
      page_loading: true,
    });
  };

  const gestureBlocked = () =>
    // set by the composer (open = unsaved draft, locked = owns the gesture);
    // new lockers should set one of the same attributes
    "scrollLocked" in document.documentElement.dataset ||
    "composerOpen" in document.documentElement.dataset;

  const cancelGesture = () => {
    const wasPulling = state === "pulling";
    teardownGesture();
    if (wasPulling) retreat();
  };

  const onTouchMove = (e) => {
    if (e.touches.length > 1) return cancelGesture(); // pinch, not a pull
    const touch = e.touches[0];
    const dy = touch.clientY - startY;
    const dx = touch.clientX - startX;

    if (state === "tracking") {
      if (dy < 0 || Math.abs(dx) > Math.abs(dy)) return teardownGesture();
      if (dy < SLOP_PX) return;
      // layout-forcing checks, deferred until a pull actually commits
      if (
        startTarget &&
        (startTarget.closest('[role="dialog"]') ||
          hasScrollableAncestor(startTarget, document.body))
      ) {
        return teardownGesture();
      }
      state = "pulling";
      showIndicator();
    }

    if (state === "pulling") {
      if (e.cancelable) e.preventDefault(); // suppress iOS rubber-band / native PTR
      lastVisible = Math.max(
        0,
        MAX_PULL_PX * (1 - Math.exp(-(dy - SLOP_PX) / MAX_PULL_PX)),
      );
      renderPull(lastVisible);
    }
  };

  const onTouchFinish = (e) => {
    const commit =
      e.type === "touchend" &&
      state === "pulling" &&
      lastVisible >= THRESHOLD_PX;
    const wasPulling = state === "pulling";
    teardownGesture();
    if (!wasPulling) return;
    pill.style.transition = TRANSITION;
    if (commit) {
      state = "refreshing";
      refreshStartedAt = performance.now();
      parkAndSpin();
      dispatchRefresh();
    } else {
      retreat();
    }
  };

  function teardownGesture() {
    window.removeEventListener("touchmove", onTouchMove);
    window.removeEventListener("touchend", onTouchFinish);
    window.removeEventListener("touchcancel", onTouchFinish);
    if (state === "tracking" || state === "pulling") state = "idle";
  }

  window.addEventListener(
    "touchstart",
    (e) => {
      if (state !== "idle" || e.touches.length !== 1) return;
      // <= 0 rather than === 0: iOS rubber-banding reports negative offsets.
      if (document.scrollingElement.scrollTop > 0 || gestureBlocked()) return;
      // iOS WebKit can report a Text node as the touch target
      startTarget =
        e.target instanceof Element ? e.target : e.target?.parentElement;
      startX = e.touches[0].clientX;
      startY = e.touches[0].clientY;
      lastVisible = 0;
      state = "tracking";
      // per-gesture listeners only, so the permanent listener stays passive
      window.addEventListener("touchmove", onTouchMove, { passive: false });
      window.addEventListener("touchend", onTouchFinish);
      window.addEventListener("touchcancel", onTouchFinish);
    },
    { passive: true },
  );

  // live navigation cancels gesture/refresh — the reload watchdog especially
  // must not survive onto the next page
  window.addEventListener("phx:page-loading-start", (e) => {
    if (e.detail?.kind !== "redirect") return;
    if (state === "tracking" || state === "pulling") {
      teardownGesture();
      hideIndicator();
    } else if (state === "refreshing") {
      abortRefresh?.();
      hideIndicator();
      state = "idle";
    }
  });
}
