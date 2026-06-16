/**
 * Bonfire embeddable comments
 *
 * Drop this script tag anywhere in your page to embed a Bonfire comment thread:
 *
 *   <script src="https://your-instance.social/js/comments_embed.js" data-theme="dark" data-mode="nested" async></script>
 *
 * Optional attributes:
 *   data-post-id        - the Bonfire post/thread ID (optional, otherwise will use media URI)
 *   data-media-uri      - find or create a thread for this URL (optional, defaults to current page URL)
 *   data-canonical-slug      - find or create a thread for this post/page slug on the original website (eg. Ghost post slug)
 *   data-canonical-id      - find or create a thread for this post/page ID on the original website (eg. Ghost post ID)
 *   data-boundary       - visibility boundary for the created thread (e.g. "public", "local")
 *   data-group-id       - what Bonfire group to post the article in (if any)
 *   data-require-topic  - only import the article and generate a comment thread if the canonical category or main tag matches a topic on Bonfire (boolean)
 *   data-creator        - user ID to attribute thread creation to
 *   data-sort-by        - initial sort order: "latest_reply", "reply_count", "boost_count", "like_count", "popularity_score", or "newest" (default: thread order)
 *   data-sort-order     - sort direction for the chosen sort: "asc" or "desc" (default: per sort type)
 *   data-mode           - initial thread display mode: "flat" or "nested" (default: instance/user setting)
 *   data-theme          - DaisyUI theme name to apply inside the iframe (e.g. "dark", "light")
 *   data-token-max-age  - hours before the stored auth token is considered stale and the user is prompted to re-authenticate (default: 720 = 30 days). Invalid or non-positive values fall back to the default. The server enforces a hard maximum regardless of this value (1 year by default), and this value is clamped to it.
 *
 * Authentication:
 *   Third-party cookies are blocked in cross-origin iframes, so this script implements a token-based auth flow. After the user signs in on the Bonfire instance, they are redirected back here with ?bonfire_embed_token=... which is stored in localStorage and passed to the iframe on future page loads.
 *
 * The iframe resizes automatically to fit its content.
 */
(function () {
  var script = document.currentScript;
  if (!script) return;

  var postId = script.getAttribute("data-post-id");

  // --- Shared embed helpers (keep in sync with pins_embed.js) ---

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

  // bail cleanly if the script src can't yield an origin (relative/blob/bad URL)
  var instanceUrl = getOrigin(script);
  if (!instanceUrl) return;

  // --- Token max age (validated) ---
  // invalid input must not yield NaN (would silently disable token expiry)
  var DEFAULT_TOKEN_MAX_AGE_HOURS = 720; // ~30 days
  var MAX_TOKEN_MAX_AGE_HOURS = 365 * 24; // server hard cap (1 year)
  var rawMaxAge = parseInt(script.getAttribute("data-token-max-age"), 10);
  var tokenMaxAgeHours =
    Number.isFinite(rawMaxAge) && rawMaxAge > 0
      ? Math.min(rawMaxAge, MAX_TOKEN_MAX_AGE_HOURS)
      : DEFAULT_TOKEN_MAX_AGE_HOURS;
  var tokenMaxAgeMs = tokenMaxAgeHours * 3600 * 1000;
  var storageKey = "bonfire_embed_token:" + instanceUrl;

  // --- Safe localStorage ---
  // localStorage access throws (not null) in Safari Private Mode / disabled
  // storage; wrap every call so the widget still renders (no token persistence)

  function safeGet(key) {
    try {
      return window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  function safeSet(key, value) {
    try {
      window.localStorage.setItem(key, value);
    } catch (_) {}
  }

  function safeRemove(key) {
    try {
      window.localStorage.removeItem(key);
    } catch (_) {}
  }

  // --- Token lifecycle ---

  function saveToken(token) {
    safeSet(storageKey, JSON.stringify({ token: token, ts: Date.now() }));
  }

  function storedToken() {
    var raw = safeGet(storageKey);
    if (!raw) return null;
    try {
      var entry = JSON.parse(raw);
      if (!entry || !entry.token) return null;
      if (Date.now() - entry.ts > tokenMaxAgeMs) {
        safeRemove(storageKey);
        return null;
      }
      return entry.token;
    } catch (_) {
      return null;
    }
  }

  var urlParams = new URLSearchParams(window.location.search);

  function receiveToken(freshToken) {
    if (!freshToken) return;
    saveToken(freshToken);
    // strip only the token param, leaving the host page's own query/hash
    urlParams.delete("bonfire_embed_token");
    var cleanSearch = urlParams.toString();
    try {
      history.replaceState(
        null,
        "",
        window.location.pathname + (cleanSearch ? "?" + cleanSearch : "") + window.location.hash
      );
    } catch (_) {}
  }

  // Check if we're returning from a Bonfire login redirect with a fresh token
  receiveToken(urlParams.get("bonfire_embed_token"));

  // --- Build iframe ---

  var mediaUri = script.getAttribute("data-media-uri") || window.location.href;
  var token = storedToken();
  var theme = script.getAttribute("data-theme");

  var params = new URLSearchParams({ media_uri: mediaUri });
  var boundary = script.getAttribute("data-boundary");
  var creator = script.getAttribute("data-creator");
  var sortBy = script.getAttribute("data-sort-by");
  var sortOrder = script.getAttribute("data-sort-order");
  var mode = script.getAttribute("data-mode");
  var canonicalSlug = script.getAttribute("data-canonical-slug");
  var canonicalId = script.getAttribute("data-canonical-id");
  var groupId = script.getAttribute("data-group-id");
  var requireTopic = script.getAttribute("data-require-topic");
  var authMode = script.getAttribute("data-auth-mode");

  if (boundary) params.set("boundary", boundary);
  if (creator) params.set("creator", creator);
  if (sortBy) params.set("sort_by", sortBy);
  if (sortOrder) params.set("sort_order", sortOrder);
  if (mode) params.set("mode", mode);
  if (canonicalSlug) params.set("canonical_slug", canonicalSlug);
  if (canonicalId) params.set("canonical_id", canonicalId);
  if (groupId) params.set("group_id", groupId);
  if (requireTopic) params.set("require_topic", requireTopic);
  if (authMode) params.set("auth_mode", authMode);
  if (token) params.set("bonfire_embed_token", token);
  if (theme) params.set("theme", theme);
  // Tell the LV the parent article URL so in-iframe actions (sign in, reply)
  // can redirect back here afterwards with the embed token.
  params.set("embed_parent", window.location.href);

  // Unique id so two default (postId-less) embeds on one page don't collide.
  var embedSeq = (window.__bonfireCommentsEmbedCount =
    (window.__bonfireCommentsEmbedCount || 0) + 1);
  embedIframe(
    "bonfire-comments-" + (postId || "embed-" + embedSeq),
    script,
    "/comments/embed" + (postId ? "/" + postId : ""),
    params,
    "Comments",
    instanceUrl,
    "width:100%;min-height:160px"
  );
})();
