const DEBUG_FLAG = "bonfire:live_socket:lifecycle_debug";
const FORCE_RESUME_GUARD_FLAG = "bonfire:live_socket:force_mobile_resume_guard";
const DISABLE_RESUME_GUARD_FLAG = "bonfire:live_socket:disable_mobile_resume_guard";
const EVENTS_STORAGE_KEY = "bonfire:live_socket:lifecycle_events";
const EVENTS_STORAGE_NAMES = ["sessionStorage", "localStorage"];
const LIFECYCLE_VERSION = "mobile-resume-guard-feed-state-v6";
const MAX_LIFECYCLE_EVENTS = 50;
const PERSIST_DEBOUNCE_MS = 250;
const RECONNECT_GRACE_MS = 750;
const RECONNECT_IN_FLIGHT_TIMEOUT_MS = 10000;
const IMMEDIATE_PERSIST_EVENTS = new Set([
	"liveview_pageshow_reload_suppressed",
	"pagehide",
	"reload_with_jitter_allowed",
	"reload_with_jitter_suppressed",
	"socket_close",
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
	if (navigator.userAgentData && typeof navigator.userAgentData.mobile === "boolean") {
		return navigator.userAgentData.mobile;
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
		socketConnected: Boolean(liveSocket && liveSocket.isConnected && liveSocket.isConnected()),
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
	return Boolean(liveSocket && liveSocket.hasPendingLink && liveSocket.hasPendingLink());
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
	if (!liveSocket || !liveSocket.reloadWithJitterTimer) return;
	clearTimeout(liveSocket.reloadWithJitterTimer);
	liveSocket.reloadWithJitterTimer = null;
}

function clearLiveViewUnloadFlag(liveSocket, log, event) {
	if (liveSocket && liveSocket.isUnloaded && liveSocket.isUnloaded()) {
		// Phoenix LiveView treats pagehide as unload. On mobile, pagehide may
		// be a recoverable browser lifecycle pause, so keep the view reconnectable.
		// Revisit this shim when phoenix_live_view#3896 / phoenix#6534 land here.
		liveSocket.unloaded = false;
		log("liveview_unload_flag_cleared", { trigger: event });
	}
}

function socketConnectionState(liveSocket) {
	const socket = liveSocket && liveSocket.getSocket && liveSocket.getSocket();
	return socket && socket.connectionState && socket.connectionState();
}

function beginReconnectAttempt(state, log, trigger) {
	if (state.reconnectInFlight) {
		log("manual_reconnect_skipped", { trigger, reason: "in_flight" });
		return false;
	}

	state.reconnectInFlight = true;
	clearTimeout(state.reconnectInFlightTimer);
	state.reconnectInFlightTimer = window.setTimeout(() => {
		state.reconnectInFlight = false;
		state.reconnectInFlightTimer = null;
		log("manual_reconnect_timeout", { trigger });
	}, RECONNECT_IN_FLIGHT_TIMEOUT_MS);
	return true;
}

function finishReconnectAttempt(state) {
	state.reconnectInFlight = false;
	clearTimeout(state.reconnectInFlightTimer);
	state.reconnectInFlightTimer = null;
}

function reconnectSocket(liveSocket, state, log, trigger) {
	if (!beginReconnectAttempt(state, log, trigger)) return;

	window.setTimeout(() => {
		if (!liveSocket || !liveSocket.isConnected) {
			finishReconnectAttempt(state);
			return;
		}

		if (liveSocket.isConnected()) {
			markLifecycleRecovered(state, log, trigger);
			finishReconnectAttempt(state);
			return;
		}

		if (socketConnectionState(liveSocket) === "connecting") {
			clearReloadTimer(liveSocket);
			log("manual_reconnect_skipped", { trigger, reason: "connecting" });
			finishReconnectAttempt(state);
			return;
		}

		clearReloadTimer(liveSocket);
		log("manual_reconnect", { trigger });

		const socket = liveSocket.getSocket && liveSocket.getSocket();
		if (socket && socket.teardown && socket.connect) {
			socket.teardown(() => {
				socket.connect();
				finishReconnectAttempt(state);
			});
		} else {
			liveSocket.connect();
			finishReconnectAttempt(state);
		}
	}, RECONNECT_GRACE_MS);
}

function installReloadGuard(liveSocket, state, log) {
	if (!liveSocket || !liveSocket.reloadWithJitter) return;

	const reloadWithJitter = liveSocket.reloadWithJitter.bind(liveSocket);

	liveSocket.reloadWithJitter = (view, reloadLog) => {
		if (shouldRecoverLifecycleDisconnect(state, liveSocket)) {
			clearReloadTimer(liveSocket);
			clearLiveViewUnloadFlag(liveSocket, log, "reloadWithJitter");
			log("reload_with_jitter_suppressed", {
				pendingLink: hasPendingLink(liveSocket),
			});

			if (document.visibilityState === "visible") {
				reconnectSocket(liveSocket, state, log, "reloadWithJitter");
			}

			return;
		}

		log("reload_with_jitter_allowed", {
			lifecycleResumePending: state.lifecycleResumePending,
			pagehidePending: state.pagehidePending,
			pendingLink: hasPendingLink(liveSocket),
		});
		return reloadWithJitter(view, reloadLog);
	};
}

function installLiveViewPageshowGuard(liveSocket, state, log) {
	if (!liveSocket || !liveSocket.bindTopLevelEvents || liveSocket.__bonfirePageshowGuard) return;

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
							clearReloadTimer(liveSocket);
							clearLiveViewUnloadFlag(liveSocket, log, "liveview_pageshow");
							log("liveview_pageshow_reload_suppressed", { persisted: true });
							reconnectSocket(liveSocket, state, log, "liveview_pageshow");
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
		reconnectInFlight: false,
		reconnectInFlightTimer: null,
	};

	window.Bonfire = Object.assign(window.Bonfire || {}, { liveSocketLifecycle: state });
	const log = makeLogger(liveSocket, state);
	installLiveViewPageshowGuard(liveSocket, state, log);

	window.addEventListener("visibilitychange", () => {
		log("visibilitychange");

		if (document.visibilityState === "hidden") {
			markLifecyclePause(state);
			return;
		}

		if (shouldRecoverLifecycleDisconnect(state, liveSocket)) {
			clearReloadTimer(liveSocket);
			clearLiveViewUnloadFlag(liveSocket, log, "visibilitychange");
			reconnectSocket(liveSocket, state, log, "visibilitychange");
		}
	});

	window.addEventListener("pagehide", (event) => {
		markLifecyclePause(state);
		state.pagehidePending = true;
		log("pagehide", { persisted: event.persisted === true });

		if (shouldGuardMobileResume(state)) {
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

			clearReloadTimer(liveSocket);
			clearLiveViewUnloadFlag(liveSocket, log, "pageshow");
			reconnectSocket(liveSocket, state, log, "pageshow");
			window.setTimeout(() => {
				state.pagehidePending = false;
			}, 0);
		},
		true
	);

	const socket = liveSocket.getSocket && liveSocket.getSocket();
	if (socket && socket.onOpen) {
		socket.onOpen(() => {
			clearReloadTimer(liveSocket);
			finishReconnectAttempt(state);
			clearLiveViewUnloadFlag(liveSocket, log, "socket_open");
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

	installReloadGuard(liveSocket, state, log);
	log("lifecycle_setup", { mobileBrowser: state.mobileBrowser });
	state.version = LIFECYCLE_VERSION;
	log("lifecycle_version", { version: LIFECYCLE_VERSION });
	return state;
}
