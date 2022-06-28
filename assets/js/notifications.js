let NotificationsHooks = {};

NotificationsHooks.Notification = {
    mounted() {
        if (Notification.permission === "default") {
            this.pushEvent("Bonfire.UI.Common.Notifications:request") // ask the server to ask the client to ask the user for permission
            console.debug("notification permission should be requested ")
        } else {
            console.debug("notification permission is already granted ")
        }

        this.handleEvent("notify", ({ title, message, icon }) => sendNotification(title, message, icon));
    }
} 

function sendNotification(title, message, icon) {
    console.debug("notification received: " + title)
    // console.debug(title + message + icon)
    console.debug("notification permission: " + Notification.permission)
    if (Notification.permission === "granted") {
        try {
            new Notification(title, {
                body: message,
                icon: icon,
                requireInteraction: false
            });
            console.debug("notification attempted...")
        } catch (e) {
            console.debug("notification error: " + e)
        }
    } else {
        Notification.requestPermission();
    }
}

export { NotificationsHooks }