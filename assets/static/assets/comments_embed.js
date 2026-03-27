/**
 * Bonfire embeddable comments
 *
 * Drop this script tag anywhere in your page to embed a Bonfire comment thread:
 *
 *   <script src="https://your-instance.social/assets/embed/comments.js" data-post-id="POST_ID" data-theme="dark" async></script>
 *
 * Optional attributes:
 *   data-post-id  — the Bonfire post/thread ID (required)
 *   data-theme    — DaisyUI theme name to apply inside the iframe (e.g. "dark", "light")
 *
 * The iframe resizes automatically to fit its content with no library required.
 */
(function () {
  var script = document.currentScript;
  if (!script) return;

  var instanceUrl = new URL(script.src).origin;
  var postId = script.getAttribute("data-post-id");

  var theme = script.getAttribute("data-theme");
  var src = instanceUrl + "/comments/embed/" + (postId || "");
  
  const params = new URLSearchParams({
    media_uri: window.location.href,
    theme: theme,
  });

  var iframe = document.createElement("iframe");
  iframe.id = "bonfire-comments-" + postId;
  iframe.src = src + "?" + params.toString();
  iframe.style.cssText = "width:100%;border:none;overflow:hidden;display:block";
  iframe.setAttribute("scrolling", "no");
  iframe.setAttribute("loading", "lazy");
  iframe.setAttribute("title", "Comments");
  script.parentNode.insertBefore(iframe, script.nextSibling);

  window.addEventListener("message", function (e) {
    if (
      e.data &&
      e.data.type === "bonfire:iframe-resize" &&
      e.origin === instanceUrl
    ) {
      iframe.style.height = e.data.height + "px";
    }
  });
})();
