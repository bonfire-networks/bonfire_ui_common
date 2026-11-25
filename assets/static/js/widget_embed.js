/**
 * Bonfire embeddable widgets
 *
 * Drop this script tag anywhere in your page to embed one of the instance's embeddable widgets:
 *
 *   <script src="https://your-instance.social/js/widget_embed.js" data-widget="circle_members" data-circle="CIRCLE_ID" data-theme="dark" async></script>
 *
 * Required attributes:
 *   data-widget   - the widget's id, e.g. "instance_pinned" or "circle_members"
 *
 * Optional attributes, for every widget:
 *   data-theme    - DaisyUI theme name to apply inside the iframe (e.g. "dark", "light")
 *   data-width    - "full" to fill the page's width, or a maximum width in pixels (default: 720)
 *
 * Any other data-* attribute is passed on to the widget as it is, e.g.:
 *   circle_members:  data-circle (required, a circle with public visibility), data-variant="portrait"
 *   instance_pinned: data-items (how many cards show side by side)
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

  var widget = script.getAttribute("data-widget");
  if (!widget) return;

  // every data-* attribute but the widget's id is one of the embed's query params (`data-circle` -> `circle`)
  var params = new URLSearchParams();
  for (var i = 0; i < script.attributes.length; i++) {
    var attr = script.attributes[i];
    if (attr.name.indexOf("data-") === 0 && attr.name !== "data-widget" && attr.value) {
      params.set(attr.name.slice(5), attr.value);
    }
  }

  var id = "bonfire-widget-" + widget + (params.toString() ? "-" + params.toString() : "");

  // a widget may scroll sideways (eg. a carousel), which on touch screens holds on to vertical swipes: the frame sends them here to scroll the page
  params.set("embed_parent", window.location.origin);
  params.set("scroll_relay", "1");

  embedIframe(
    id,
    script,
    "/embed/widget/" + encodeURIComponent(widget),
    params,
    script.getAttribute("title") || "Bonfire",
    instanceUrl,
    "width:100%;min-height:140px",
    relayPageScroll
  );
})();
