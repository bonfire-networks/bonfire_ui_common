import { Hook, makeHook } from "phoenix_typed_hook";
import { Cookie } from "./cookie"

function expires() {
  let expiry = new Date()
  // Set expiry to ten days
  expiry.setDate(expiry.getDate() + 10)
  return expiry.toGMTString()
}

class ChangeLocaleHook extends Hook {
  destroyed() {
    console.log(this.el.value)
    document.cookie = `locale=${this.el.value}; path=/; expires=${expires()}`
    // Cookie.set("locale", this.el.value)
  }
}

let ChangeLocaleHooks = {};

ChangeLocaleHooks.ChangeLocaleHook = makeHook(ChangeLocaleHook);

export { ChangeLocaleHooks }
