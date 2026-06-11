// Mobile LiveView lifecycle guard.
//
// Layering (important): phoenix.js (>= 1.8) already owns *socket* reconnection —
// it cleanly disconnects on pagehide and reconnects on pageshow, reconnects
// immediately on visibilitychange->visible after an unclean close, and pauses
// its reconnect timer while hidden. This module therefore only guards the
// *LiveView* layer, which still treats mobile lifecycle pauses as unloads and
// hard-reloads the page via three paths:
//   1. `unloaded` flag set on pagehide -> location.reload() when the socket reopens
//   2. the `bindTopLevelEvents` pageshow listener -> location.reload() on BFCache restore
//   3. `reloadWithJitter` -> scheduled on any code-1000 close with a main view
//      (which includes phoenix's own clean pagehide disconnect) and on view join errors
// We suppress those reloads when they look like a recoverable mobile pause and
// let phoenix's reconnect + LiveView's rejoin resync state instead.
// Revisit when phoenix_live_view#3896 / phoenix#6534 land here.

const DEBUG_FLAG = "bonfire:live_socket:lifecycle_debug";
const FORCE_RESUME_GUARD_FLAG = "bonfire:live_socket:force_mobile_resume_guard";
const DISABLE_RESUME_GUARD_FLAG = "bonfire:live_socket:disable_mobile_resume_guard";
const EVENTS_STORAGE_KEY = "bonfire:live_socket:lifecycle_events";
const EVENTS_STORAGE_NAMES = ["sessionStorage", "localStorage"];
const LIFECYCLE_VERSION = "mobile-resume-guard-feed-state-v7";
const MAX_LIFECYCLE_EVENTS = 50;
const PERSIST_DEBOUNCE_MS = 250;
const IMMEDIATE_PERSIST_EVENTS = new Set([
	"liveview_pageshow_reload_suppressed",
	"pagehide",
	"reload_with_jitter_allowed",
	"reload_with_jitter_suppressed",
	"socket_close",
	"guard_inactive",
]);

function storageGet(storageName, key) {
	try {
		const storage = window[storageName];
		return storage && storage.getItem(key);
	} catch (_e) {
		return null;
	}
}

function flagEnabled(key) {
	return (
		storageGet("localStorage", key) === "true" ||
		storageGet("sessionStorage", key) === "true"
	);
}

function readEventsFromStorage(storageName) {
	try {
		const storage = window[storageName];
		const raw = storage && storage.getItem(EVENTS_STORAGE_KEY);
		const events = raw && JSON.parse(raw);
		return Array.isArray(events) ? events : null;
	} catch (_e) {
		return null;
	}
}

function readStoredEvents() {
	for (const storageName of EVENTS_STORAGE_NAMES) {
		const events = readEventsFromStorage(storageName);
		if (events && events.length > 0) return { events, source: storageName };
	}

	return { events: [], source: null };
}

function writeStoredEvents(events) {
	const payload = JSON.stringify(events.slice(-MAX_LIFECYCLE_EVENTS));

	for (const storageName of EVENTS_STORAGE_NAMES) {
		try {
			const storage = window[storageName];
			storage && storage.setItem(EVENTS_STORAGE_KEY, payload);
		} catch (_e) {
			// Diagnostic only: blocked storage must not affect LiveView recovery.
		}
	}
}

function persistStoredEvents(state, event) {
	if (IMMEDIATE_PERSIST_EVENTS.has(event)) {
		clearTimeout(state.persistEventsTimer);
		state.persistEventsTimer = null;
		writeStoredEvents(state.events);
		return;
	}

	if (state.persistEventsTimer) return;

	state.persistEventsTimer = window.setTimeout(() => {
		state.persistEventsTimer = null;
		writeStoredEvents(state.events);
	}, PERSIST_DEBOUNCE_MS);
}

function mobileBrowser() {
	// Only trust a positive signal: userAgentData.mobile is false on Android
	// tablets, which need the guard just as much — fall through to UA sniffing.
	if (navigator.userAgentData && navigator.userAgentData.mobile === true) {
		return true;
	}

	const ua = navigator.userAgent || "";
	return (
		/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini|Mobile/i.test(ua) ||
		(navigator.maxTouchPoints > 1 && /Macintosh/i.test(ua))
	);
}

function eventContext(liveSocket, detail = {}) {
	return {
		...detail,
		visibilityState: document.visibilityState,
		online: navigator.onLine,
		wasDiscarded: document.wasDiscarded === true,
		socketConnected: Boolean(liveSocket.isConnected?.()),
	};
}

function makeLogger(liveSocket, state) {
	return (event, detail = {}) => {
		const entry = {
			event,
			at: new Date().toISOString(),
			...eventContext(liveSocket, detail),
		};
		state.events.push(entry);
		if (state.events.length > MAX_LIFECYCLE_EVENTS) state.events.shift();

		if (flagEnabled(DEBUG_FLAG)) {
			persistStoredEvents(state, event);
			console.debug("[bonfire:live_socket]", event, entry);
		}
	};
}

function shouldGuardMobileResume(state) {
	if (flagEnabled(DISABLE_RESUME_GUARD_FLAG)) return false;
	return state.mobileBrowser || flagEnabled(FORCE_RESUME_GUARD_FLAG);
}

function hasPendingLink(liveSocket) {
	return Boolean(liveSocket.hasPendingLink?.());
}

function shouldRecoverLifecycleDisconnect(state, liveSocket) {
	return (
		shouldGuardMobileResume(state) &&
		!hasPendingLink(liveSocket) &&
		(document.visibilityState === "hidden" || state.lifecycleResumePending)
	);
}

function markLifecyclePause(state) {
	state.lifecycleResumePending = true;
}

function markLifecycleRecovered(state, log, trigger) {
	if (!state.lifecycleResumePending) return;

	state.lifecycleResumePending = false;
	log("lifecycle_recovered", { trigger });
}

function clearReloadTimer(liveSocket) {
	if (!liveSocket.reloadWithJitterTimer) return;
	clearTimeout(liveSocket.reloadWithJitterTimer);
	liveSocket.reloadWithJitterTimer = null;
}

function clearLiveViewUnloadFlag(liveSocket, log, event) {
	if (liveSocket.isUnloaded?.()) {
		// Phoenix LiveView treats pagehide as unload and reloads the page as soon
		// as the socket reopens while the flag is set, so it must be cleared on the
		// resume paths *before* the reconnect completes (the socket_open clear is
		// too late: LiveView's own onOpen callback was registered first).
		liveSocket.unloaded = false;
		log("liveview_unload_flag_cleared", { trigger: event });
	}
}

// Shared resume path: stop any scheduled LiveView reload, keep the view
// reconnectable, and close the suppression window if the socket survived
// (otherwise socket_open closes it once phoenix's reconnect completes).
function resumeFromLifecyclePause(liveSocket, state, log, trigger) {
	clearReloadTimer(liveSocket);
	clearLiveViewUnloadFlag(liveSocket, log, trigger);
	if (liveSocket.isConnected?.()) {
		markLifecycleRecovered(state, log, trigger);
	}
}

function installReloadGuard(liveSocket, state, log) {
	if (typeof liveSocket.reloadWithJitter !== "function") return false;

	const reloadWithJitter = liveSocket.reloadWithJitter.bind(liveSocket);

	liveSocket.reloadWithJitter = (view, reloadLog) => {
		if (shouldRecoverLifecycleDisconnect(state, liveSocket)) {
			clearReloadTimer(liveSocket);
			clearLiveViewUnloadFlag(liveSocket, log, "reloadWithJitter");
			log("reload_with_jitter_suppressed", {
				pendingLink: hasPendingLink(liveSocket),
			});
			// No manual reconnect here: phoenix reconnects on pageshow /
			// visibilitychange->visible itself, and channels rejoin on their own.
			return;
		}

		log("reload_with_jitter_allowed", {
			lifecycleResumePending: state.lifecycleResumePending,
			pagehidePending: state.pagehidePending,
			pendingLink: hasPendingLink(liveSocket),
		});
		return reloadWithJitter(view, reloadLog);
	};
	return true;
}

function installLiveViewPageshowGuard(liveSocket, state, log) {
	if (typeof liveSocket.bindTopLevelEvents !== "function") return false;
	if (liveSocket.__bonfirePageshowGuard) return true;

	const bindTopLevelEvents = liveSocket.bindTopLevelEvents.bind(liveSocket);
	const wrappedPageshowListeners = new WeakMap();
	liveSocket.__bonfirePageshowGuard = true;

	liveSocket.bindTopLevelEvents = (...args) => {
		const originalAddEventListener = window.addEventListener;

		window.addEventListener = function (type, listener, options) {
			if (type === "pageshow" && typeof listener === "function") {
				let guardedListener = wrappedPageshowListeners.get(listener);
				if (!guardedListener) {
					guardedListener = function (event) {
						const suppressLiveViewReload =
							event &&
							event.persisted === true &&
							state.pagehidePending &&
							shouldGuardMobileResume(state) &&
							!hasPendingLink(liveSocket);

						if (suppressLiveViewReload) {
							resumeFromLifecyclePause(liveSocket, state, log, "liveview_pageshow");
							log("liveview_pageshow_reload_suppressed", { persisted: true });
							return;
						}

						return listener.call(this, event);
					};
					wrappedPageshowListeners.set(listener, guardedListener);
				}

				return originalAddEventListener.call(this, type, guardedListener, options);
			}

			return originalAddEventListener.call(this, type, listener, options);
		};

		try {
			return bindTopLevelEvents(...args);
		} finally {
			window.addEventListener = originalAddEventListener;
		}
	};
	return true;
}

export function setupLiveSocketLifecycle(liveSocket) {
	const storedEvents = readStoredEvents();
	const state = {
		events: [],
		lifecycleResumePending: document.visibilityState === "hidden",
		mobileBrowser: mobileBrowser(),
		pagehidePending: false,
		previousEvents: storedEvents.events,
		previousEventsSource: storedEvents.source,
		persistEventsTimer: null,
	};

	window.Bonfire = Object.assign(window.Bonfire || {}, { liveSocketLifecycle: state });
	const log = makeLogger(liveSocket, state);
	const pageshowGuardOk = installLiveViewPageshowGuard(liveSocket, state, log);

	window.addEventListener("visibilitychange", () => {
		log("visibilitychange");

		if (document.visibilityState === "hidden") {
			markLifecyclePause(state);
			return;
		}

		if (shouldRecoverLifecycleDisconnect(state, liveSocket)) {
			resumeFromLifecyclePause(liveSocket, state, log, "visibilitychange");
		}
	});

	window.addEventListener("pagehide", (event) => {
		markLifecyclePause(state);
		state.pagehidePending = true;
		log("pagehide", { persisted: event.persisted === true });

		if (shouldGuardMobileResume(state)) {
			// Not resumeFromLifecyclePause: we're pausing, so the socket may still
			// be open and recovery must not be marked yet. The timeout defers the
			// clears until after LiveView's own pagehide listener has set the flag.
			window.setTimeout(() => {
				clearReloadTimer(liveSocket);
				clearLiveViewUnloadFlag(liveSocket, log, "pagehide");
			}, 0);
		}
	});

	window.addEventListener(
		"pageshow",
		(event) => {
			const guardResume =
				state.pagehidePending &&
				shouldGuardMobileResume(state);

			log("pageshow", { persisted: event.persisted === true, guardResume });

			if (!guardResume) return;

			resumeFromLifecyclePause(liveSocket, state, log, "pageshow");
			window.setTimeout(() => {
				state.pagehidePending = false;
			}, 0);
		},
		true
	);

	const socket = liveSocket.getSocket?.();

	// Phoenix reconnects on visibility changes but not on network regain — after
	// airplane mode / connection loss it sits out the remaining backoff (up to 5s).
	// Mirror its visibilitychange->visible logic for the `online` event.
	// (`closeWasClean` has no public accessor; it's the same predicate phoenix's
	// own visibilitychange handler reads.)
	window.addEventListener("online", () => {
		if (
			document.visibilityState === "visible" &&
			socket &&
			!socket.isConnected() &&
			socket.closeWasClean === false
		) {
			clearReloadTimer(liveSocket);
			log("online_reconnect");
			socket.disconnect(() => socket.connect());
		}
	});

	if (socket && socket.onOpen) {
		socket.onOpen(() => {
			clearReloadTimer(liveSocket);
			markLifecycleRecovered(state, log, "socket_open");
			log("socket_open");
		});
	}

	if (socket && socket.onClose) {
		socket.onClose((event) => {
			log("socket_close", {
				code: event && event.code,
				reason: event && event.reason,
				wasClean: event && event.wasClean,
			});
		});
	}

	const reloadGuardOk = installReloadGuard(liveSocket, state, log);

	// The guard monkey-patches LiveView internals (`reloadWithJitter`, `unloaded`,
	// `bindTopLevelEvents`); surface loudly when an upgrade removed them instead
	// of silently degrading back to hard reloads.
	if (!reloadGuardOk || !pageshowGuardOk || typeof liveSocket.isUnloaded !== "function") {
		log("guard_inactive", {
			reloadGuard: reloadGuardOk,
			pageshowGuard: pageshowGuardOk,
			isUnloaded: typeof liveSocket.isUnloaded === "function",
		});
		console.warn(
			"[bonfire:live_socket] lifecycle guard could not patch LiveView internals — mobile resume guard is (partially) inactive"
		);
	}

	log("lifecycle_setup", { mobileBrowser: state.mobileBrowser });
	state.version = LIFECYCLE_VERSION;
	log("lifecycle_version", { version: LIFECYCLE_VERSION });
	return state;
}
