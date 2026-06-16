/**
 * Bonfire embeddable spotlight (featured/pinned content)
 *
 * Drop this script tag anywhere in your page to embed the instance spotlight:
 *
 *   <script src="https://your-instance.social/js/pins_embed.js" data-theme="dark" async></script>
 *
 * Optional attributes:
 *   data-theme  - DaisyUI theme name to apply inside the iframe (e.g. "dark", "light")
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

  function embedIframe(id, scriptEl, path, params, title, origin, style) {
    var qs = params.toString();
    var iframe = document.createElement("iframe");
    iframe.id = id;
    iframe.src = origin + path + (qs ? "?" + qs : "");
    iframe.style.cssText = "border:none;overflow:hidden;display:block" + (style ? ";" + style : "");
    iframe.setAttribute("scrolling", "no");
    iframe.setAttribute("loading", "lazy");
    iframe.setAttribute("title", title || "Embed");
    if (!scriptEl.parentNode) return;
    scriptEl.parentNode.insertBefore(iframe, scriptEl.nextSibling);
    window.addEventListener("message", function (e) {
      if (e.origin !== origin) return;
      if (e.source && iframe.contentWindow && e.source !== iframe.contentWindow) return;
      if (!e.data || e.data.type !== "bonfire:iframe-resize") return;
      var height = Number(e.data.height);
      if (!Number.isFinite(height) || height <= 0) return;
      iframe.style.height = Math.min(height, 100000) + "px";
    });
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

  embedIframe("bonfire-pins", script, "/instance/pins/embed", params, "Spotlight", instanceUrl, "width:100%;min-height:140px");
})();
