// On back/forward LiveView keeps the page being left on screen until the
// popped-to one joins (~0.5-1s), which after a back-swipe looks like the old page
// coming back. Hide its content column meanwhile; sidebar, dock and progress
// bar stay. phx:navigate only fires for pops that change location (not preview
// entries or cancelled navigations).
const LEAVING_MAX_HIDDEN_MS = 8000;

function showLeftPage() {
  document
    .querySelectorAll("[data-leaving]")
    .forEach((el) => el.removeAttribute("data-leaving"));
}

export function setupHideLeavingPage(liveSocket) {
  window.addEventListener("phx:navigate", ({ detail }) => {
    if (!detail?.pop) return;

    const leaving = liveSocket.main;
    const patchesCurrentView =
      detail.patch && leaving?.isConnected() && history.state?.id === leaving.id;
    if (!leaving?.el || patchesCurrentView) return;

    // not on the view root: LiveView shallow-clones it (attributes too) for the incoming view
    const column = leaving.el.querySelector('[data-id="main_section"]');
    if (!column) return;
    column.setAttribute("data-leaving", "");
    // never stays hidden if the new page doesn't arrive
    setTimeout(() => column.removeAttribute("data-leaving"), LEAVING_MAX_HIDDEN_MS);
  });

  // normally the column is replaced with its page; this covers failed joins
  window.addEventListener("phx:page-loading-stop", ({ detail }) => {
    if (detail?.kind !== "element") showLeftPage();
  });
}
