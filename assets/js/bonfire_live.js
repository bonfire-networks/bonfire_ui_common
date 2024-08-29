// first include JS shared with non_live pages
import "./bonfire_common";

// then define live JS
import { Socket } from "../../../../deps/phoenix";
import { LiveSocket } from "../../../../deps/phoenix_live_view";
import NProgress from "nprogress";

// for JS features & extensions to hook into LiveView
let Hooks = {};

let JS_exec = (selector, event) => {
	document
		.querySelectorAll(selector)
		.forEach((el) => liveSocket.execJS(el, event));
};
let JS_exec_attr_event = (selector, attr) => {
	document.querySelectorAll(selector).forEach((el) => {
		console.log(attr);
		let event = el.getAttribute(attr);
		console.log(el);
		console.log(event);
		liveSocket.execJS(el, event);
	});
};

let csrfToken = document
	.querySelector("meta[name='csrf-token']")
	.getAttribute("content");
// let random_socket_id = if (window.Gon !== undefined) {
//   window.Gon.getAsset("random_socket_id"
// }
let liveSocket = new LiveSocket("/live", Socket, {
	timeout: 60000,
	params: {
		_csrf_token: csrfToken,
		// random_socket_id: random_socket_id
	},
	dom: {
		onBeforeElUpdated(from, to) {
			if (from._x_dataStack) {
				window.Alpine.clone(from, to);
			}
		},
	},
	hooks: Hooks,
});

// Show progress bar on live navigation and form submits
// Only displays if still loading after 120 msec
let topBarScheduled = undefined;
window.addEventListener("phx:page-loading-start", () => {
	if (!topBarScheduled) {
		topBarScheduled = setTimeout(() => NProgress.start(), 120);
	}
});
window.addEventListener("phx:page-loading-stop", () => {
	clearTimeout(topBarScheduled);
	topBarScheduled = undefined;
	NProgress.done();
});

// To trigger JS commands from the server, eg using this in LV:
// push_event(socket, "js-exec", % {
//   to: "#my_spinner",
//   attr: "data-ok-done"
// })
// FIXME: see https://elixirforum.com/t/there-should-be-a-built-in-hook-for-running-exec-js-commands/59849/4
window.addEventListener("phx:js-exec-attr-event", ({ detail }) => {
	console.log(detail);
	JS_exec_attr_event(detail.to, detail.attr);
});
// window.addEventListener("phx:js-show", ({ detail }) => {
//   document.querySelectorAll(detail.to).forEach(el =>
//     JS_exec(detail.to, "show")
//     // JS.show(el)
//     // liveSocket.show(el)
//   )
// })

// show socket connection status
liveSocket
	.getSocket()
	.onOpen(() => JS_exec_attr_event("#connection-status", "js-hide"));
liveSocket
	.getSocket()
	.onError(() => JS_exec_attr_event("#connection-status", "js-show"));
// connect if there are any LiveViews on the page
liveSocket.connect();
// themeChange()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()

window.liveSocket = liveSocket;

// import DynamicImport from '@rtvision/esbuild-dynamic-import';
// note depending on your setup you may need to do DynamicImport.default() instead
// DynamicImport({ transformExtensions: ['.js'], changeRelativeToAbsolute: false, filter: "../../data/current_flavour/config/deps_hooks.js" })

import { ExtensionHooks } from "../../../../data/current_flavour/config/deps_hooks.js";
// import SourceInspect from "./../../../../deps/source_inspector/priv/js/source_inspector.js"
// ExtensionHooks.SourceInspect = SourceInspect
// ExtensionHooks.SourceInspect = SourceInspect(csrfToken)

import ComponentHooks from "../../../../data/current_flavour/config/flavour_assets/hooks/index.js";

// Add Extensions' Hooks...
Object.assign(liveSocket.hooks, ExtensionHooks, ComponentHooks);
