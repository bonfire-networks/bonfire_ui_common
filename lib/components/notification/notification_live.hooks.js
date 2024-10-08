export default {
	mounted() {
		if (Notification.permission === "default") {
			this.pushEvent("Bonfire.UI.Common.Notifications:request"); // ask the server to ask the client to ask the user for permission
			console.debug("notification permission should be requested ");
		} else {
			console.debug("notification permission is already granted ");
		}
		this.handleEvent("notify", ({ title, message, url, icon }) =>
			sendNotification(title, message, url, icon),
		);

		const notificationElement = this.el;
		setTimeout(() => {
			notificationElement.style.transition = "opacity 0.5s ease-out";
			notificationElement.style.opacity = "0";
			setTimeout(() => {
				notificationElement.remove();
			}, 500);
		}, 5000);
	},
};

function sendNotification(title, message, url, icon) {
	console.debug("notification received: " + title);
	// console.debug(title + message + icon)
	console.debug("notification permission: " + Notification.permission);
	if (Notification.permission === "granted") {
		try {
			n = new Notification(title, {
				body: message,
				icon: icon,
				requireInteraction: false,
			});
			console.debug("notification attempted...");
			// Hide the notification after 5 seconds
			setTimeout(n.close.bind(n), 2000);
			if (url && url != "") {
				n.onclick = function () {
					window.location.href = url;
				};
			}
		} catch (e) {
			console.debug("notification error: " + e);
		}
	} else {
		Notification.requestPermission();
	}
}
