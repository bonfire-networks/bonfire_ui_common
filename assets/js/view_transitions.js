// Crossfades link navigations between LiveViews (full page loads: `@view-transition`
// in app.css). LiveView calls `onDocumentPatch` before *every* diff, so it's armed
// only by page-loading-start of kind "redirect" and spent on the next patch.
// Back/forward never arms it (its join reports "initial"), so it can't double up
// with a browser swipe animation; patches and live updates are never animated.
import { prefersReducedMotion } from "./motion";

let armed = false;

// The transition applies its update a frame later; diffs arriving meanwhile
// queue behind it so they can't land before the mount they belong to.
let pending = null;

function afterPending(run) {
  const done = (pending || Promise.resolve()).then(run).catch((e) => console.error(e));
  pending = done;
  done.then(() => {
    if (pending === done) pending = null;
  });
}

function transition(start) {
  try {
    return document.startViewTransition(start).updateCallbackDone;
  } catch (_e) {
    // an unusable transition must never leave the page unpatched
    return start();
  }
}

export function onDocumentPatch(start) {
  const animate =
    armed &&
    typeof document.startViewTransition === "function" &&
    document.visibilityState === "visible" &&
    !prefersReducedMotion();

  armed = false;

  if (animate) return afterPending(() => transition(start));
  if (pending) return afterPending(start);
  start();
}

export function setupViewTransitions() {
  window.addEventListener("phx:page-loading-start", (e) => {
    if (e.detail?.kind === "redirect") armed = true;
  });

  // a navigation that ended without a patch
  window.addEventListener("phx:page-loading-stop", () => {
    armed = false;
  });
}
