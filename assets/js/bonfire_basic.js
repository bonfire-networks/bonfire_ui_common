import "./bonfire_common"

let Hooks = {};

import { ImageHooks } from "./image"
import { CopyHooks } from "./copy"
// import { FeedHooks } from "./feed"
import * as c1 from "../../../../data/current_flavour/config/flavour_assets/hooks/Bonfire.UI.Common.PreviewContentLive.hooks"
let FeedHooks = ns(c1, "Bonfire.UI.Common.PreviewContentLive")

Object.assign(Hooks, ImageHooks, CopyHooks, FeedHooks);

// run LiveView Hooks without LiveView
(function() {
  [...document.querySelectorAll("[phx-hook]")].map((hookEl) => {
    let hookName = hookEl.getAttribute("phx-hook");
    let hook = Hooks[hookName];

    if (hook) {
      let mountedFn = hook.mounted.bind({ ...hook, el: hookEl });
      mountedFn();
    }
  });
})();

function phxClick(event) {
  // event.preventDefault(); // Override the native event?
  let name = this.getAttribute("phx-click")
  if (name.charAt(0) == "[") {
    name = JSON.parse(name)[0][1]["event"]
  }
  window.location = "/LiveHandler/" + name.replace(":", "/") + "?" + new URLSearchParams(getPhxValues(this)).toString()
}

// attempt graceful degradation for LiveView events without LiveView
(function() {
  [...document.querySelectorAll("[phx-click]")].map((el) => {
    el.addEventListener('click', phxClick);
  });
})();

function getPhxValues(el) {
  console.log(el)
  return el
    .getAttributeNames()
    .filter(name => name.startsWith("phx-value-"))
    .reduce((obj, name) => ({
      ...obj,
      [name.substring(10)]: el.getAttribute(name)
    }), {})
}
