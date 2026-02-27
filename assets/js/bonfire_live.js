// first include JS shared with non_live pages
import "./bonfire_common";

// then define live JS
import { Socket } from "../../../../deps/phoenix";
import { LiveSocket } from "../../../../deps/phoenix_live_view";
import NProgress from "nprogress";

// for JS features & extensions to hook into LiveView
let Hooks = {};

// Import and register hooks BEFORE creating LiveSocket
import { CopyHooks } from "./copy";
import { TooltipHooks } from "./tooltip";
import { DraggableHooks } from "./draggable_widget";
import { ScrollHooks } from "./scroll.js";
import { TranslateHooks } from "./translate.js";
import { KeyboardShortcutHooks } from "./keyboard_shortcuts.js";
import { ExtensionHooks } from "../../../../config/current_flavour/deps.hooks.js";
import ComponentHooks from "../../../../config/current_flavour/assets/hooks/index.js";

Object.assign(Hooks, ExtensionHooks, DraggableHooks, ComponentHooks, CopyHooks, TooltipHooks, ScrollHooks, TranslateHooks, KeyboardShortcutHooks);

console.log("Registered LiveView hooks:", Object.keys(Hooks));

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
	params: () => {
		const readingPositions = {};
		const maxAge = 60 * 60 * 1000; // 1 hour
		const now = Date.now();
		for (let i = localStorage.length - 1; i >= 0; i--) {
			const key = localStorage.key(i);
			if (key.startsWith("reading_pos:")) {
				try {
					const val = JSON.parse(localStorage.getItem(key));
					if (val && val.consumed) {
						// Already used once — clear it and don't send
						localStorage.removeItem(key);
					} else if (val && val.ts && now - val.ts < maxAge) {
						readingPositions[key.slice("reading_pos:".length)] = val.id;
					} else {
						localStorage.removeItem(key); // evict expired
					}
				} catch {
					// Old format (plain string) — migrate or evict
					const raw = localStorage.getItem(key);
					if (raw) {
						readingPositions[key.slice("reading_pos:".length)] = raw;
						localStorage.setItem(
							key,
							JSON.stringify({ id: raw, ts: now }),
						);
					}
				}
			}
		}
		return {
			_csrf_token: csrfToken,
			// random_socket_id: random_socket_id
			reading_positions: readingPositions,
		};
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

// Shared helper for CW textarea manipulation
// (visibility and button state are now server-controlled via show_cw/show_sensitive assigns)
function setCwTextarea(value) {
	const cwTextarea = document.querySelector("#smart_input_summary textarea");
	if (cwTextarea) cwTextarea.value = value;
}

// Reset composer UI after posting
window.addEventListener("phx:smart_input:reset_sensitive", () => {
	setCwTextarea("");

	// Also clear title and scheduled_at input values
	["#smart_input_post_title input", "#smart_input_scheduled_at input"].forEach(sel => {
		const el = document.querySelector(sel);
		if (el) el.value = "";
	});
});

// Fill CW textarea when replying to a CW post
window.addEventListener("phx:smart_input:set_cw", ({ detail }) => {
	setCwTextarea(detail.cw || "");
});

// Clear CW textarea when replying to a non-CW post
window.addEventListener("phx:smart_input:clear_cw", () => {
	setCwTextarea("");
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

