// first include JS shared with non_live pages
import "./bonfire_common"

// then define live JS
import { Socket } from "../../../../deps/phoenix"
import {LiveSocket} from "../../../../deps/phoenix_live_view"
import NProgress from "nprogress"      

// for JS features & extensions to hook into LiveView
let Hooks = {}; 

let execJS = (selector, attr) => {
  document.querySelectorAll(selector).forEach(el => liveSocket.execJS(el, el.getAttribute(attr)))
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
    timeout: 60000,
    params: { _csrf_token: csrfToken }, 
    dom: {
      onBeforeElUpdated(from, to) {
        if (from._x_dataStack) { window.Alpine.clone(from, to) }
      }
    }, 
    hooks: Hooks
}) 

// Show progress bar on live navigation and form submits
// Only displays if still loading after 120 msec
let topBarScheduled = undefined;
window.addEventListener("phx:page-loading-start", () => {
  if (!topBarScheduled) {
    topBarScheduled = setTimeout(() => NProgress.start(), 120);
  };
});
window.addEventListener("phx:page-loading-stop", () => {
  clearTimeout(topBarScheduled);
  topBarScheduled = undefined;
  NProgress.done()
});

// show socket connection status
liveSocket.getSocket().onOpen(() => execJS("#connection-status", "js-hide"))
liveSocket.getSocket().onError(() => execJS("#connection-status", "js-show"))
// connect if there are any LiveViews on the page
liveSocket.connect()
// themeChange()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
 
window.liveSocket = liveSocket

// import DynamicImport from '@rtvision/esbuild-dynamic-import';
// note depending on your setup you may need to do DynamicImport.default() instead
// DynamicImport({ transformExtensions: ['.js'], changeRelativeToAbsolute: false, filter: "../../data/current_flavour/config/deps_hooks.js" })

import { ExtensionHooks } from "../../../../data/current_flavour/config/deps_hooks.js"
import SourceInspect from "./../../../../deps/source_inspector/priv/js/source_inspector.js"
ExtensionHooks.SourceInspect = SourceInspect
ExtensionHooks.SourceInspect = SourceInspect(csrfToken)

// Add Extensions' Hooks...   
Object.assign(liveSocket.hooks, ExtensionHooks);
