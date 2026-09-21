// Track active hook instances to prevent duplicate initialization
const activeHooks = new Set();

const AUTO_FADE_DELAY = 5000;
const FADE_DURATION = 150;
const FADE_EASING = "cubic-bezier(0.19, 1, 0.22, 1)";

// Debug logging - disabled by default
const DEBUG = false;
const log = DEBUG ? console.log.bind(console) : () => {};

export default {
	mounted() {
		const hookId = this.el.id;
		log(`Notifications: hook mounting: ${hookId}`);

		if (activeHooks.has(hookId)) {
			log(`Notifications: Hook ${hookId} already initialized, skipping`);
			return;
		}

		activeHooks.add(hookId);
		this.hookId = hookId;
		this.observer = null;
		this.clickHandler = this.handleClick.bind(this);

		this.pushStateHandler = () => this.reportPushState();

		this.el.addEventListener('click', this.clickHandler);
		// the push toggle lives on another page, so it announces a change rather than calling here
		window.addEventListener('bonfire:push:changed', this.pushStateHandler);
		this.setupBrowserNotifications();
		this.handleEvent(`notify:${hookId}`, (data) => this.sendNotification(data));
		this.setupContainer();
		this.reportPushState();
	},

	// This browser's push subscription, or null. Half of the answer: it says this device could be reached, while only the server knows whether the person reading this page is still linked to it, which is why the endpoint goes along and the server decides.
	async pushSubscription() {
		try {
			if (!('serviceWorker' in navigator) || !('PushManager' in window)) return null;

			const registration = await navigator.serviceWorker.getRegistration();
			if (!registration) return null;

			return await registration.pushManager.getSubscription();
		} catch (e) {
			log("Notifications: could not read the push subscription: " + e);
			return null;
		}
	},

	async hasWorkingPush() {
		return !!(await this.pushSubscription());
	},

	// Tells the server whether this socket needs the in-page fallback, and caches the answer for the next connect so the first render already knows. Not the same question as permission: push can be off while permission is granted, which is the case the fallback exists for.
	async reportPushState() {
		const subscription = await this.pushSubscription();

		window.Bonfire?.setBonfireParam?.("push", "active", !!subscription);
		this.pushEventTo(this.el, "push_state", {
			active: !!subscription,
			endpoint: subscription ? subscription.endpoint : null
		});
	},

	handleClick(e) {
		const closeButton = e.target.closest('button[phx-click="clear-flash"]');
		if (!closeButton) return;

		const alert = closeButton.closest('[role="alert"]');
		if (alert?._autoFadeTimer) {
			clearTimeout(alert._autoFadeTimer);
			delete alert._autoFadeTimer;
			log(`Cancelled auto-fade timer for manual dismiss: ${alert.getAttribute('data-id')}`);
		}
	},

	setupBrowserNotifications() {
		if (typeof Notification === 'undefined' || !('Notification' in window)) {
			log("Notifications: API not available (mobile browser or WebView)");
			return;
		}

		// Reporting only, never asking. Permission is the user's to give, from the push toggle, at a gesture: asking on mount pops a browser prompt nobody invited, and a `default` permission used to trigger a server round-trip that flashed "Notifications enabled" before anyone had enabled anything.
		log(`Notifications: permission is ${Notification.permission}`);
	},

	setupContainer() {
		const container = this.el.querySelector('[data-id="notifications-container"]');
		if (!container) {
			console.error("Notifications: Could not find container");
			return;
		}

		// Set up auto-fade for existing alerts
		container.querySelectorAll('[role="alert"]').forEach((element) => {
			if (!element._autoFadeTimer) {
				this.setupAutoFade(element);
			}
		});

		// Monitor for new alerts
		this.observer = new MutationObserver((mutations) => {
			for (const mutation of mutations) {
				if (mutation.type !== 'childList' || mutation.addedNodes.length === 0) {
					continue;
				}

				for (const node of mutation.addedNodes) {
					if (node.nodeType !== Node.ELEMENT_NODE) continue;

					// Check if this node is an alert
					if (node.getAttribute('role') === 'alert' && !node._autoFadeTimer) {
						this.setupAutoFade(node);
					}

					// Check nested alerts (in case wrapper elements are added)
					node.querySelectorAll?.('[role="alert"]').forEach((alert) => {
						if (!alert._autoFadeTimer) {
							this.setupAutoFade(alert);
						}
					});
				}
			}
		});

		// Only observe childList to prevent feedback loops from attribute/style changes
		this.observer.observe(container, { childList: true, subtree: true });
	},

	setupAutoFade(element) {
		const dataId = element.getAttribute('data-id') || 'unknown';
		log(`Setting up auto-fade for "${dataId}"`);

		const timerId = setTimeout(() => {
			element.style.transition = `opacity ${FADE_DURATION}ms ${FADE_EASING}`;
			element.style.opacity = '0';

			setTimeout(() => {
				if (!element.parentNode) return;

				const flashType = element.getAttribute('data-id');
				if (flashType) {
					const key = flashType.replace('flash_', '');
					this.pushEventTo(this.el, "clear-flash", { key });
				}

				element.remove();
				delete element._autoFadeTimer;
			}, FADE_DURATION);
		}, AUTO_FADE_DELAY);

		element._autoFadeTimer = timerId;
	},

	destroyed() {
		const hookId = this.hookId;
		log(`Notifications: hook destroying: ${hookId}`);

		// Remove click handler
		this.el.removeEventListener('click', this.clickHandler);
		window.removeEventListener('bonfire:push:changed', this.pushStateHandler);

		// Cancel all active timers
		const container = this.el.querySelector('[data-id="notifications-container"]');
		container?.querySelectorAll('[role="alert"]').forEach((element) => {
			if (element._autoFadeTimer) {
				clearTimeout(element._autoFadeTimer);
				delete element._autoFadeTimer;
			}
		});

		// Disconnect observer
		if (this.observer) {
			this.observer.disconnect();
			this.observer = null;
		}

		activeHooks.delete(hookId);
	},

	async sendNotification({ title, message, url, icon, activity_id }) {
		if (typeof Notification === 'undefined' || !('Notification' in window)) {
			return;
		}

		// Never prompt from here: a browser resolves `requestPermission()` to `denied` without a prompt once blocked, and a prompt nobody asked for is what the push toggle exists to avoid. Without permission the in-app toast is the whole notification, which is what someone who refused OS notifications gets.
		if (Notification.permission !== "granted") {
			log("Notifications: no permission for an OS notification, the in-app toast stands alone");
			return;
		}

		// The server subscribes this socket only where push looks inactive, and this asks again anyway: the cached answer can be seconds old, and a subscription that started working in the meantime would mean the service worker and this page both showing the same thing.
		if (await this.hasWorkingPush()) {
			log("Notifications: push is working here, so the service worker shows this one");
			return;
		}

		try {
			const notification = new Notification(title, {
				body: message,
				icon: icon,
				// the activity itself, so the same activity heard by several open tabs (and by the service worker, which keys on the same id) replaces itself instead of stacking one popup per tab
				tag: activity_id,
				requireInteraction: false,
			});

			// No forced close: how long a notification stays is the operating system's business, and closing it after 2s meant anyone who looked away missed it entirely.

			if (url) {
				notification.onclick = () => {
					window.location.href = url;
				};
			}
		} catch (e) {
			log("Notifications: error: " + e);
		}
	}
};
