let IframeResizeHooks = {}

// On mount/patch, nudge the single coalesced resize sender in the iframe layout
// (window.__bonfireEmbedResize). We don't measure/postMessage here so there's
// one de-duplicated sender, avoiding mid-patch height flip-flop.
IframeResizeHooks.IframeResize = {
	mounted() { this.ping(); },
	updated() { this.ping(); },
	ping() { if (window.__bonfireEmbedResize) window.__bonfireEmbedResize(); }
}

export { IframeResizeHooks };
