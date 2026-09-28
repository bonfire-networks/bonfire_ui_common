// Reports the current user's unseen notifications + messages to the service
// worker, which owns the app icon badge (it also counts pushes while no page is
// on screen). A feed can have two badges on a page (dock, sidebar) that don't
// both get every update, so the last one whose count changed wins for its feed.
const latestByFeed = new Map();
let scheduled = false;

function reportAppBadge() {
  scheduled = false;
  if (latestByFeed.size === 0) return;

  const count = [...latestByFeed.values()].reduce((sum, n) => sum + n, 0);

  // `ready` rather than `controller`: also reaches the worker on a first visit, before it controls the page
  navigator.serviceWorker?.ready.then((registration) =>
    registration.active?.postMessage({ type: "APP_BADGE", count })
  );
}

// the worker may have counted pushes while the app was hidden
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") reportAppBadge();
});

export default {
  mounted() {
    this.report();
  },

  updated() {
    this.report();
  },

  report() {
    const feed = this.el.dataset.appBadgeFeed;
    const count = parseInt(this.el.dataset.appBadgeCount, 10);
    // the feed is only set for the current user's loaded counts
    if (!feed || !Number.isFinite(count)) return;
    // an unchanged re-render mustn't overwrite a newer count from the other badge
    if (this.feed === feed && this.count === count) return;

    this.feed = feed;
    this.count = count;
    latestByFeed.set(feed, count);

    // badges mount in bursts
    if (!scheduled) {
      scheduled = true;
      queueMicrotask(reportAppBadge);
    }
  },
};
