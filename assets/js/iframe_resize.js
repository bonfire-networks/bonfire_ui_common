let IframeResizeHooks = {}

IframeResizeHooks.IframeResize = {
	mounted() { this.sendHeight(); },
	updated() { this.sendHeight(); },
	sendHeight() {
		window.parent.postMessage(
			{ type: "bonfire:iframe-resize", height: document.body.scrollHeight },
			"*"
		);
	}
}

export { IframeResizeHooks };
