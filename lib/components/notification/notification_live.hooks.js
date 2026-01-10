// Track active hook instances to prevent duplicate initialization
const activeHooks = new Set();

// Debug logging - set to false in production
const DEBUG = true; // TODO: Set to false or use process.env.NODE_ENV === 'development'
const log = DEBUG ? console.log.bind(console) : () => {};
const debug = DEBUG ? console.debug.bind(console) : () => {};

export default {
	mounted() {
		// Use the element's ID as a unique identifier
		const hookId = this.el.id;
		log(`🔔 Notifications: hook mounting: ${hookId}`);

		// Check if this hook is already initialized
		if (activeHooks.has(hookId)) {
			log(`⚠️ Notifications: Hook ${hookId} already initialized, skipping`);
			return;
		}

		// Register this hook instance
		activeHooks.add(hookId);
		log(`✅ Notifications: Registered hook ${hookId}, active hooks: ${activeHooks.size}`);

		// Store references to clean up later
		this.observer = null;

		// Add click handler to cancel timers when user manually dismisses
		this.el.addEventListener('click', (e) => {
			const closeButton = e.target.closest('button[phx-click="clear-flash"]');
			if (closeButton) {
				const alert = closeButton.closest('[role="alert"]');
				if (alert && alert._autoFadeTimer) {
					clearTimeout(alert._autoFadeTimer);
					delete alert._autoFadeTimer;
					log(`Cancelled auto-fade timer for manual dismiss: ${alert.getAttribute('data-id')}`);
				}
			}
		});

		// Check if Notification API is available
		if (typeof Notification !== 'undefined' && 'Notification' in window) {
			if (Notification.permission === "default") {
				this.pushEvent("Bonfire.UI.Common.Notifications:request");
				debug("Notifications: permission should be requested");
			} else {
				debug("Notifications: permission is already granted");
			}
		} else {
			debug("Notifications: Notification API not available (mobile browser or WebView)");
		}

		this.handleEvent(`notify:${hookId}`, ({ title, message, url, icon }) => {
			debug(`Notifications ${hookId}: received: ` + title);
			this.sendNotification(title, message, url, icon);
		});

		// Set up auto-fade for any alerts that are already present
		const container = this.el.querySelector('[data-id="notifications-container"]');
		log(`🔍 Notifications ${hookId}: Looking for container...`, container ? 'FOUND' : 'NOT FOUND');

		if (container) {
			const existingAlerts = container.querySelectorAll('[role="alert"]');
			log(`📋 Notifications ${hookId}: Found ${existingAlerts.length} existing alerts`);

			if (existingAlerts.length !== 0) {
				existingAlerts.forEach((element, index) => {
					log(`  Alert ${index + 1}: data-id="${element.getAttribute('data-id')}", visible=${element.offsetParent !== null}, hasTimer=${!!element._autoFadeTimer}`);
					// Only setup fade if not already setup
					if (!element._autoFadeTimer) {
						setupAutoFade(element, 5000, this);
					} else {
						log(`  ⏭️ Skipping - already has timer`);
					}
				});
			}

			// Monitor for new flash messages (handles both new nodes and attribute changes)
			log(`👀 Notifications ${hookId}: Setting up MutationObserver on container`);

			this.observer = new MutationObserver((mutations) => {
				log(`🔄 Notifications ${hookId}: MutationObserver fired with ${mutations.length} mutations`);

				for (const mutation of mutations) {
					// Handle new nodes being added
					if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
						log(`  ➕ childList mutation: ${mutation.addedNodes.length} nodes added`);

						mutation.addedNodes.forEach((node, index) => {
							if (node.nodeType === Node.ELEMENT_NODE) {
								const role = node.getAttribute('role');
								const dataId = node.getAttribute('data-id');
								log(`    Node ${index + 1}: role="${role}", data-id="${dataId}", tagName="${node.tagName}"`);

								// Check if this node has role="alert"
								if (role === 'alert') {
									log(`    ✨ Found alert element! data-id="${dataId}", hasTimer=${!!node._autoFadeTimer}`);
									if (!node._autoFadeTimer) {
										setupAutoFade(node, 5000, this);
									} else {
										log(`    ⏭️ Skipping - already has timer`);
									}
								}
							}
						});
					}

					// Handle attribute changes (for Phoenix LiveView's DOM patching)
					// This catches when elements become visible via conditional rendering
					if (mutation.type === 'attributes') {
						const target = mutation.target;
						const role = target.getAttribute('role');
						const dataId = target.getAttribute('data-id');
						const isVisible = target.offsetParent !== null;

						log(`  🔧 attributes mutation: target="${target.tagName}", role="${role}", data-id="${dataId}", visible=${isVisible}, attribute="${mutation.attributeName}"`);

						if (target.nodeType === Node.ELEMENT_NODE &&
						    role === 'alert' &&
						    isVisible) { // Element is visible
							log(`    ✨ Alert became visible! data-id="${dataId}", hasTimer=${!!target._autoFadeTimer}`);
							if (!target._autoFadeTimer) {
								setupAutoFade(target, 5000, this);
							} else {
								log(`    ⏭️ Skipping - already has timer`);
							}
						}
					}
				}
			});

			// Observe both childList changes and attribute changes, with subtree enabled
			this.observer.observe(container, {
				childList: true,
				subtree: true,
				attributes: true,
				attributeFilter: ['class', 'style', 'data-id'] // Watch for changes that might indicate visibility
			});
		} else {
			console.error("Notifications: Could not find container");
		}
	},

	destroyed() {
		// Clean up when the hook is destroyed
		const hookId = this.el.id;
		debug(`Notifications: hook destroying: ${hookId}`);

		// Cancel all active timers on notifications
		const container = this.el.querySelector('[data-id="notifications-container"]');
		if (container) {
			container.querySelectorAll('[role="alert"]').forEach(element => {
				if (element._autoFadeTimer) {
					clearTimeout(element._autoFadeTimer);
					delete element._autoFadeTimer;
					log(`Cancelled timer for ${element.getAttribute('data-id')}`);
				}
			});
		}

		// Disconnect observer if it exists
		if (this.observer) {
			this.observer.disconnect();
			this.observer = null;
		}

		// Remove this hook from the active set
		activeHooks.delete(hookId);
		debug(`Notifications: Unregistered hook ${hookId}, active hooks: ${activeHooks.size}`);
	},

	sendNotification(title, message, url, icon) {
		// Check if Notification API is available
		if (typeof Notification === 'undefined' || !('Notification' in window)) {
			debug("Notifications: API not available, skipping");
			return;
		}

		if (Notification.permission === "granted") {
			try {
				const n = new Notification(title, {
					body: message,
					icon: icon,
					requireInteraction: false,
				});
				debug("Notifications: attempted...");
				// Hide the notification after X seconds
				setTimeout(n.close.bind(n), 2000);
				if (url && url != "") {
					n.onclick = function () {
						window.location.href = url;
					};
				}
			} catch (e) {
				debug("Notifications: error: " + e);
			}
		} else {
			Notification.requestPermission();
		}
	}
};

function setupAutoFade(element, delay, hook) {
	const dataId = element.getAttribute('data-id') || 'unknown';
	log(`⏰ Setting up auto-fade for "${dataId}" with ${delay}ms delay`);

	// Store timer ref so it can be cancelled if user manually dismisses
	const timerId = setTimeout(() => {
		log(`🎬 Starting fade-out animation for "${dataId}"`);

		// Add transition for smooth fade-out
		element.style.transition = 'opacity 500ms ease-out';
		element.style.opacity = '0';

		// After fade completes, notify server and remove element
		setTimeout(() => {
			if (element.parentNode) {
				// Get the flash key from data-id attribute
				const flashType = element.getAttribute('data-id');

				// Notify server to clear the flash on server side
				if (flashType && hook) {
					// Handle both flash_info, flash_error, and notification formats
					const key = flashType.replace('flash_', '');
					log(`📤 Sending clear-flash event to server for key: "${key}"`);
					// Use pushEventTo to send to the NotificationLive component (via the hook's element)
					// instead of pushEvent which goes to the parent LiveView
					hook.pushEventTo(hook.el, "clear-flash", { key: key });
				}

				log(`🗑️ Removing element "${dataId}" from DOM`);
				element.remove();
				delete element._autoFadeTimer;
			} else {
				log(`⚠️ Element "${dataId}" no longer has parent, cannot remove`);
			}
		}, 500);
	}, delay);

	// Store timer reference on element so it can be cancelled
	element._autoFadeTimer = timerId;
	log(`✅ Auto-fade timer set for "${dataId}", timer ID:`, timerId);
}
