import { Hook, makeHook } from "phoenix_typed_hook";
import { Cookie } from "./cookie"

class ChangeLocaleHook extends Hook {
  destroyed() {
    Cookie.set("locale", this.el.value)
  }
}

let ChangeLocaleHooks = {};

ChangeLocaleHooks.ChangeLocaleHook = makeHook(ChangeLocaleHook);

export { ChangeLocaleHooks }
