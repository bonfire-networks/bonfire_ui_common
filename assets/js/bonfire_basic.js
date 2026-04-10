import "./bonfire_common";

let Hooks = {};

// import { ImageHooks } from "./image"
import { CopyHooks } from "./copy";
import { TooltipHooks } from "./tooltip";

// import { FeedHooks } from "./feed"
import * as c1 from "../../../../config/current_flavour/assets/hooks/Bonfire.UI.Common.PreviewContentLive.hooks";
import * as c2 from "../../../../config/current_flavour/assets/hooks/Bonfire.UI.Social.Activity.TruncatableContentLive.hooks";

// Universal JS executor - uses vanilla JS when there's no LiveView 
window.JS_exec = function (_lv_js, vanilla_js_b64) {
	// Execute vanilla JS using Function constructor (rather than eval)
	const vanilla_js = atob(vanilla_js_b64);
	new Function(vanilla_js).call(this);
};

function ns(hooks, nameSpace) {
	const updatedHooks = {};
	Object.keys(hooks).map(function (key) {
		updatedHooks[`${nameSpace}#${key}`] = hooks[key];
	});
	return updatedHooks;
}

let FeedHooks = ns(c1, "Bonfire.UI.Common.PreviewContentLive");
let TruncatableHooks = ns(c2, "Bonfire.UI.Social.Activity.TruncatableContentLive");

Object.assign(Hooks, CopyHooks, TooltipHooks, FeedHooks, TruncatableHooks);
// ImageHooks

// run LiveView Hooks without LiveView
(function () {
	[...document.querySelectorAll("[phx-hook]")].map((hookEl) => {
		let hookName = hookEl.getAttribute("phx-hook");
		let hook = Hooks[hookName];

		if (hook) {
			let mountedFn = hook.mounted.bind({ ...hook, el: hookEl });
			mountedFn();
		}
	});
})();

// attempt graceful degradation for LiveView click events without LiveView
// Collect all <meta name="session-param-*"> tags as extra params to pass with LiveHandler fallback requests.
// This lets server-rendered pages inject session-like context (e.g. go) for guests.
function getMetaParams() {
	return [...document.querySelectorAll("meta[name^='session-param-']")].reduce((obj, el) => {
		obj[el.getAttribute("name").substring(14)] = el.getAttribute("content");
		return obj;
	}, {});
}

function phxClick(event) {
	// event.preventDefault(); // Override the native event?
	let name = this.getAttribute("phx-click");
	if (name && typeof name === "string") {
		if (name.charAt(0) == "[") {
			name = JSON.parse(name)[0][1]["event"];
		}
		if (name && typeof name === "string") {
			let params = Object.assign(getMetaParams(), getPhxValues(this));
			window.top.location.href =
				"/LiveHandler/" +
				name.replace(":", "/") +
				"?" +
				new URLSearchParams(params).toString();
		}
	}
}

(function () {
	[...document.querySelectorAll("[phx-click]")].map((el) => {
		el.addEventListener("click", phxClick);
	});
})();

// attempt graceful degradation for LiveView submit events without LiveView

(function () {
	[...document.querySelectorAll("form[phx-submit]")].map((el) => {
		if (!el.getAttribute("action")) {
			let name = el.getAttribute("phx-submit");
			el.action = "/LiveHandler/" + name.replace(":", "/");
			if (!el.getAttribute("method")) {
				el.method = "get";
			}
		}
	});
})();

function getPhxValues(el) {
	// console.log(el);
	return el
		.getAttributeNames()
		.filter((name) => name.startsWith("phx-value-"))
		.reduce(
			(obj, name) => ({
				...obj,
				[name.substring(10)]: el.getAttribute(name),
			}),
			{},
		);
}
