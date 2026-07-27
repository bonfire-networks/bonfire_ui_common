/**
 * Bonfire embeddable spotlight (featured/pinned content)
 *
 * Drop this script tag anywhere in your page to embed the instance spotlight:
 *
 *   <script src="https://your-instance.social/js/pins_embed.js" data-theme="dark" async></script>
 *
 * Optional attributes:
 *   data-theme    - DaisyUI theme name to apply inside the iframe (e.g. "dark", "light")
 *   data-variant  - "carousel" to use the horizontal carousel layout (default: spotlight grid)
 *
 * The iframe resizes automatically to fit its content.
 */
(function () {
  // --- Shared embed helpers (keep in sync with comments_embed.js) ---

  function getOrigin(scriptEl) {
    try {
      var o = new URL(scriptEl.src).origin;
      return o && o !== "null" ? o : null;
    } catch (_) { return null; }
  }

  function relayPageScroll(rawDelta) {
    // postMessage already crosses an event loop; another frame made continuous
    // mobile Safari touch movement arrive at the parent in visible bursts.
    var delta = Number(rawDelta);
    if (!Number.isFinite(delta) || delta === 0) return;
    window.scrollBy(0, Math.max(-120, Math.min(120, delta)));
  }

  function embedIframe(id, scriptEl, path, params, title, origin, style, relayScroll) {
    var qs = params.toString();
    var iframe = document.createElement("iframe");
    iframe.id = id;
    iframe.style.cssText = "border:none;overflow:hidden;display:block" + (style ? ";" + style : "");
    iframe.setAttribute("scrolling", "no");
    iframe.setAttribute("loading", "lazy");
    iframe.setAttribute("title", title || "Embed");
    window.addEventListener("message", function (e) {
      if (e.origin !== origin) return;
      if (e.source && iframe.contentWindow && e.source !== iframe.contentWindow) return;
      if (!e.data) return;
      if (e.data.type === "bonfire:iframe-resize") {
        var height = Number(e.data.height);
        if (!Number.isFinite(height) || height <= 0) return;
        iframe.style.height = Math.min(height, 100000) + "px";
      } else if (
        relayScroll &&
        e.source === iframe.contentWindow &&
        e.data.type === "bonfire:iframe-scroll"
      ) {
        relayScroll(e.data.deltaY);
      }
    });
    iframe.src = origin + path + (qs ? "?" + qs : "");
    if (!scriptEl.parentNode) return;
    scriptEl.parentNode.insertBefore(iframe, scriptEl.nextSibling);
    return iframe;
  }

  // ---

  var script = document.currentScript;
  if (!script) return;

  var instanceUrl = getOrigin(script);
  if (!instanceUrl) return;

  var params = new URLSearchParams();
  var theme = script.getAttribute("data-theme");
  if (theme) params.set("theme", theme);

  var variant = script.getAttribute("data-variant");
  var path = variant === "carousel" ? "/instance/pins/carousel/embed" : "/instance/pins/embed";
  var relayScroll = null;
  if (variant === "carousel") {
    params.set("embed_parent", window.location.origin);
    params.set("scroll_relay", "1");
    relayScroll = relayPageScroll;
  }

  embedIframe(
    "bonfire-pins",
    script,
    path,
    params,
    "Spotlight",
    instanceUrl,
    "width:100%;min-height:140px",
    relayScroll
  );
})();
