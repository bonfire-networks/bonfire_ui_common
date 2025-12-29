// first include JS shared with non_live pages
import "./bonfire_common";

// then define live JS
import { Socket } from "../../../../deps/phoenix";
import { LiveSocket } from "../../../../deps/phoenix_live_view";
import NProgress from "nprogress";

// for JS features & extensions to hook into LiveView
let Hooks = {};

// Universal JS executor - uses LiveView JS if connected, vanilla JS if not
window.JS_exec = function (lv_js_b64, vanilla_js_b64) {
	if (window.liveSocket && window.liveSocket.isConnected()) {
		// Execute LiveView JS command on the triggering element
		const lv_js = atob(lv_js_b64);
		liveSocket.execJS(this, lv_js);
	} else {
		// Execute vanilla JS using Function constructor (rather than eval)
		const vanilla_js = atob(vanilla_js_b64);
		new Function(vanilla_js).call(this);
	}
};
// let JS_exec = (selector, event) => {
// 	document
// 		.querySelectorAll(selector)
// 		.forEach((el) => liveSocket.execJS(el, event));
// };

let JS_exec_attr_event = (selector, attr) => {
	document.querySelectorAll(selector).forEach((el) => {
		// console.log(attr);
		let event = el.getAttribute(attr);
		// console.log(el);
		// console.log(event);
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

// Execute JS commands directly from the server
// Usage: push_event(socket, "js-exec", %{to: "#selector", js: JS.hide() |> JS.encode()})
window.addEventListener("phx:js-exec", ({ detail }) => {
	console.log("js-exec", detail);
	const target = document.querySelector(detail.to);
	if (target && detail.js) {
		liveSocket.execJS(target, detail.js);
	}
});

// Reset composer UI after posting (must use execJS to clear LiveView's sticky state)
window.addEventListener("phx:smart_input:reset_sensitive", () => {
	const container = document.getElementById("smart_input") || document.body;

	const commands = [
		["hide", { to: "#smart_input_summary", time: 0 }],
		["hide", { to: "#smart_input_post_title", time: 0 }],
		["hide", { to: "#smart_input_scheduled_at", time: 0 }],
		["hide", { to: ".sensitive_alert", time: 0 }],
		["remove_class", { to: "#sensitive_btn label", names: ["bg-warning", "text-warning-content"] }],
		["remove_class", { to: "#summary_btn", names: ["btn-active"] }],
		["remove_class", { to: "#title_btn", names: ["btn-active"] }],
		["remove_class", { to: "#scheduled_at_btn", names: ["btn-active"] }]
	];

	commands.forEach(([cmd, opts]) => {
		try {
			liveSocket.execJS(container, JSON.stringify([[cmd, opts]]));
		} catch (e) {}
	});

	// Clear form values
	const checkbox = document.querySelector("#sensitive_btn input[type='checkbox']");
	if (checkbox) checkbox.checked = false;

	["#smart_input_summary textarea", "#smart_input_post_title input", "#smart_input_scheduled_at input"].forEach(sel => {
		const el = document.querySelector(sel);
		if (el) el.value = "";
	});
});

// window.addEventListener("phx:js-show", ({ detail }) => {
//   document.querySelectorAll(detail.to).forEach(el =>
//     JS_exec(detail.to, "show")
//     // JS.show(el)
//     // liveSocket.show(el)
//   )
// })

// show socket connection status
// liveSocket
// 	.getSocket()
// 	.onOpen(() => JS_exec_attr_event("#connection-status", "js-hide"));
// liveSocket
// 	.getSocket()
// 	.onError(() => JS_exec_attr_event("#connection-status", "js-show"));

const shouldAutoConnect = !document.querySelector('script[data-live-socket="false"]');
if (shouldAutoConnect) {
	// connect if there are any LiveViews on the page
	console.log("LiveSocket connecting...");
	liveSocket.connect();
} else {
	// Otherwise we don't auto-connect, and wait for potential trigger
	console.log("LiveSocket *not* auto-connecting");
}

// Function to manually connect the socket
window.connectLiveSocket = function () {
	if (!liveSocket.isConnected()) {
		liveSocket.connect();
	}
};

// Function to disconnect if needed
window.disconnectLiveSocket = function () {
	if (liveSocket.isConnected()) {
		liveSocket.disconnect();
	}
};

// themeChange()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()

window.liveSocket = liveSocket;

import { CopyHooks } from "./copy";
import { TooltipHooks } from "./tooltip";
import { DraggableHooks } from "./draggable_widget";
import { ScrollHooks } from "./scroll.js";
import { TranslateHooks } from "./translate.js"; 

// import DynamicImport from '@rtvision/esbuild-dynamic-import';
// note depending on your setup you may need to do DynamicImport.default() instead
// DynamicImport({ transformExtensions: ['.js'], changeRelativeToAbsolute: false, filter: "../../config/current_flavour/deps.hooks.js" }) 

import { ExtensionHooks } from "../../../../config/current_flavour/deps.hooks.js";
// import SourceInspect from "./../../../../deps/source_inspector/priv/js/source_inspector.js"
// ExtensionHooks.SourceInspect = SourceInspect
// ExtensionHooks.SourceInspect = SourceInspect(csrfToken)

import ComponentHooks from "../../../../config/current_flavour/assets/hooks/index.js";

// Add Extensions' Hooks... 
Object.assign(liveSocket.hooks, ExtensionHooks, DraggableHooks, ComponentHooks, CopyHooks, TooltipHooks, ScrollHooks, TranslateHooks);
// test change

