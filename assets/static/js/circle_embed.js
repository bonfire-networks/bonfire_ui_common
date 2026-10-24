/**
 * Bonfire embeddable circle members (e.g. for a website's team section)
 *
 * Drop this script tag anywhere in your page to embed the members of a public circle:
 *
 *   <script src="https://your-instance.social/js/circle_embed.js" data-circle="CIRCLE_ID" data-theme="dark" async></script>
 *
 * Required attributes:
 *   data-circle   - ID of the circle, which must have public visibility
 *
 * Optional attributes:
 *   data-theme    - DaisyUI theme name to apply inside the iframe (e.g. "dark", "light")
 *   data-variant  - "portrait" for avatar tiles without cards (default: cards with banners)
 *
 * The iframe resizes automatically to fit its content.
 */
(function () {
  // --- Shared embed helpers (keep in sync with pins_embed.js and comments_embed.js) ---

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

  var circle = script.getAttribute("data-circle");
  if (!circle) return;

  var params = new URLSearchParams();
  var theme = script.getAttribute("data-theme");
  if (theme) params.set("theme", theme);

  var variant = script.getAttribute("data-variant");
  if (variant) params.set("variant", variant);

  embedIframe(
    "bonfire-circle-" + circle,
    script,
    "/circle/" + encodeURIComponent(circle) + "/embed",
    params,
    "Circle members",
    instanceUrl,
    "width:100%;min-height:140px"
  );
})();
