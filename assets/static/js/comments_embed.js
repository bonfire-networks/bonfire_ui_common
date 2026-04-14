/**
 * Bonfire embeddable comments
 *
 * Drop this script tag anywhere in your page to embed a Bonfire comment thread:
 *
 *   <script src="https://your-instance.social/js/comments_embed.js" data-theme="dark" async></script>
 *
 * Optional attributes:
 *   data-post-id        - the Bonfire post/thread ID (optional, otherwise will use media URI)
 *   data-media-uri      - find or create a thread for this URL (optional, defaults to current page URL)
 *   data-boundary       - visibility boundary for the created thread (e.g. "public", "local")
 *   data-creator        - user ID to attribute thread creation to
 *   data-theme          - DaisyUI theme name to apply inside the iframe (e.g. "dark", "light")
 *   data-token-max-age  - hours before the stored auth token is considered stale and the user
 *                         is prompted to re-authenticate (default: 720 = 30 days).
 *                         The server enforces a hard maximum regardless of this value (1 year by default).
 *
 * Authentication:
 *   Third-party cookies are blocked in cross-origin iframes, so this script implements
 *   a token-based auth flow. After the user signs in on the Bonfire instance, they are
 *   redirected back here with ?bonfire_embed_token=... which is stored in localStorage and
 *   passed to the iframe on future page loads.
 *
 * The iframe resizes automatically to fit its content.
 */
(function () {
  var script = document.currentScript;
  if (!script) return;

  var instanceUrl = new URL(script.src).origin;
  var postId = script.getAttribute("data-post-id");
  var tokenMaxAgeHours = parseInt(script.getAttribute("data-token-max-age") || "720", 10);
  var tokenMaxAgeMs = tokenMaxAgeHours * 3600 * 1000;
  var storageKey = "bonfire_embed_token:" + instanceUrl;

  // --- Token lifecycle ---

  function receiveToken(freshToken) {
    if (freshToken) {
      saveToken(freshToken);
      urlParams.delete("bonfire_embed_token");
      var cleanSearch = urlParams.toString();
      history.replaceState(
        null,
        "",
        window.location.pathname + (cleanSearch ? "?" + cleanSearch : "") + window.location.hash
      );
    }
  }

  function saveToken(token) {
    try {
      localStorage.setItem(storageKey, JSON.stringify({ token: token, ts: Date.now() }));
    } catch (_) {}
  }

  function storedToken(raw) {
    try {
      var entry = raw ? JSON.parse(raw) : null;
      if (!entry) return null;
      if (Date.now() - entry.ts > tokenMaxAgeMs) {
        localStorage.removeItem(storageKey);
        return null;
      }
      return entry.token;
    } catch (_) {
      return null;
    }
  }

  // Check if we're returning from a Bonfire login redirect with a fresh token
  var urlParams = new URLSearchParams(window.location.search);
  receiveToken(urlParams.get("bonfire_embed_token"));

  // --- Build iframe src ---

  var mediaUri = script.getAttribute("data-media-uri") || window.location.href;
  var src = instanceUrl + "/comments/embed" + (postId ? "/" + postId : "");
  var token = storedToken(localStorage.getItem(storageKey));
  var theme = script.getAttribute("data-theme");

  var params = new URLSearchParams({ media_uri: mediaUri });
  var boundary = script.getAttribute("data-boundary");
  var creator = script.getAttribute("data-creator");
  if (boundary) params.set("boundary", boundary);
  if (creator) params.set("creator", creator);
  if (token) params.set("bonfire_embed_token", token);
  if (theme) params.set("theme", theme);
  // Tell the LV the parent article URL so in-iframe actions (sign in, reply)
  // can redirect back here afterwards with the embed token.
  params.set("embed_parent", window.location.href);

  // --- Create iframe ---

  var iframe = document.createElement("iframe");
  iframe.id = "bonfire-comments-" + (postId || "embed");
  iframe.src = src + "?" + params.toString();
  iframe.style.cssText = "width:100%;min-height:160px;border:none;overflow:hidden;display:block";
  iframe.setAttribute("scrolling", "no");
  iframe.setAttribute("loading", "lazy");
  iframe.setAttribute("title", "Comments");
  script.parentNode.insertBefore(iframe, script.nextSibling);

  // --- Auto-resize ---

  window.addEventListener("message", function (e) {
    if (e.origin !== instanceUrl) return;
    if (e.data && e.data.type === "bonfire:iframe-resize") {
      iframe.style.height = e.data.height + "px";
    }
  });
})();
