// Track active hook instances to prevent duplicate initialization
const activeHooks = new Set();

export default {
	mounted() {
		// Use the element's ID as a unique identifier
		const hookId = this.el.id;
		console.debug(`Notifications: hook mounting: ${hookId}`);

		// Check if this hook is already initialized
		if (activeHooks.has(hookId)) {
			console.debug(`Notifications: Hook ${hookId} already initialized, skipping`);
			return;
		}

		// Register this hook instance
		activeHooks.add(hookId);
		console.debug(`Notifications: Registered hook ${hookId}, active hooks: ${activeHooks.size}`);

		// Store references to clean up later
		this.observer = null;

		if (Notification.permission === "default") {
			this.pushEvent("Bonfire.UI.Common.Notifications:request");
			console.debug("Notifications: permission should be requested");
		} else {
			console.debug("Notifications: permission is already granted");
		}

		this.handleEvent(`notify:${hookId}`, ({ title, message, url, icon }) => {
			console.debug(`Notifications ${hookId}: received: ` + title);
			this.sendNotification(title, message, url, icon);
		});

		const container = this.el.querySelector('[data-id="notifications-container"]');

		// Set up auto-fade for any alerts that are already present
		if (container) {
			const existingAlerts = container.querySelectorAll('[role="alert"]');
			if (existingAlerts.length !== 0) {
				console.debug(`Notifications ${hookId}: Found ${existingAlerts.length} existing alerts`);
				existingAlerts.forEach(element => {
					setupAutoFade(element, 4000);
				});
			}

			// Monitor for new flash messages
			console.debug(`Notifications ${hookId}: Setting up observer on container`);

			this.observer = new MutationObserver((mutations) => {
				for (const mutation of mutations) {
					if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
						console.debug(`Notifications ${hookId}: Mutation detected: ${mutation.addedNodes.length} nodes added`);

						// Check each added node
						mutation.addedNodes.forEach(node => {
							// For direct nodes with role="alert"
							if (node.nodeType === Node.ELEMENT_NODE) {
								// Check if this node has role="alert"
								if (node.getAttribute('role') === 'alert') {
									console.debug(`Notifications ${hookId}: Found direct alert element:`, node.getAttribute('data-id'));
									setupAutoFade(node, 4000);
								}
							}
						});
					}
				}
			});

			// Observe both direct children and the entire subtree
			this.observer.observe(container, {
				childList: true,
				subtree: true
			});
		} else {
			console.error("Notifications: Could not find container");
		}
	},

	destroyed() {
		// Clean up when the hook is destroyed
		const hookId = this.el.id;
		console.debug(`Notifications: hook destroying: ${hookId}`);

		// Disconnect observer if it exists
		if (this.observer) {
			this.observer.disconnect();
			this.observer = null;
		}

		// Remove this hook from the active set
		activeHooks.delete(hookId);
		console.debug(`Notifications: Unregistered hook ${hookId}, active hooks: ${activeHooks.size}`);
	},

	sendNotification(title, message, url, icon) {
		if (Notification.permission === "granted") {
			try {
				const n = new Notification(title, {
					body: message,
					icon: icon,
					requireInteraction: false,
				});
				console.debug("Notifications: attempted...");
				// Hide the notification after X seconds
				setTimeout(n.close.bind(n), 2000);
				if (url && url != "") {
					n.onclick = function () {
						window.location.href = url;
					};
				}
			} catch (e) {
				console.debug("Notifications: error: " + e);
			}
		} else {
			Notification.requestPermission();
		}
	}
};

function setupAutoFade(element, delay) {
	console.debug(`Notifications: Setting up auto-fade for ${element.getAttribute('data-id') || 'unknown'} element`);
	setTimeout(() => {
		element.style.transition = 'opacity 0.5s ease-out';
		element.style.opacity = '0';
		setTimeout(() => {
			if (element.parentNode) {
				element.remove();
				console.debug("Notifications: Element removed after fade");
			}
		}, 500);
	}, delay);
}