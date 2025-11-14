let Ignore = {
	mounted() {
		// nothing
	},
};
let LoadMore = {
	page() {
		return this.el.dataset.page;
	},
	getPhxValues(el) {
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
	},
	loadMore(entries) {
		// Guard against empty entries array
		if (!entries || entries.length === 0) {
			console.warn("[LoadMore] IntersectionObserver called with empty entries");
			return;
		}

		const target = entries[0];
		console.log("[LoadMore] IntersectionObserver triggered", {
			isIntersecting: target.isIntersecting,
			pending: this.pending,
			page: this.page(),
			loading: this.loading,
			conditionMet: target.isIntersecting && this.pending == this.page() && !this.loading
		});

		if (target.isIntersecting && this.pending == this.page() && !this.loading) {
			// Find the feed container (parent element) to scope the search
			const feedContainer = this.el.closest('[data-feed]') || this.el.closest('[role="feed"]') || this.el.parentElement;
			let items = feedContainer ? feedContainer.getElementsByClassName("infinite_scroll_hidden") : [];
			console.log("[LoadMore] Checking hidden items", { hiddenItemsCount: items.length });

			if (items.length == 0) {
				let event = this.el.getAttribute("phx-scroll");
				console.log("[LoadMore] No hidden items, checking event", { event });

				if (event) {
					// Set loading flag to prevent concurrent requests
					this.loading = true;
					// add the disabled attribute to this.el
					this.el.disabled = true;
					this.el.classList.add("btn-disabled");
					// Add phx-scroll-loading class to show spinner and hide text
					this.el.classList.add("phx-scroll-loading");

					// Store original pending value for error recovery
					this.originalPending = this.pending;
					// Use sentinel value to block concurrent requests (works with cursor strings)
					this.pending = "__loading__";

					// Add loading reference to track this specific request
					const loadingRef = this.pending;
					const values = this.getPhxValues(this.el);
					values._loading_ref = loadingRef;

					console.log("[LoadMore] Triggering server event", {
						event,
						target: this.el.getAttribute("phx-target"),
						values
					});

					this.pushEventTo(
						this.el.getAttribute("phx-target"),
						event,
						values,
					);
				} else {
					console.log("skip loading more because no phx-scroll event");
				}
			} else {
				// Auto-reveal hidden items in preload mode
				console.log("[LoadMore] Auto-revealing hidden items", { count: items.length });
				for (let element of items) {
					element.style.display = "block";
					element.classList.remove("infinite_scroll_hidden");
				}
				// Reset entryCount so future clicks work normally
				if (this.el.dataset.entryCount) {
					this.el.dataset.entryCount = "0";
				}
			}
		}
	},
	mounted() {
		// Clean up any existing observer first (in case of remount)
		if (this.observer) {
			this.observer.disconnect();
		}

		this.pending = this.page();
		this.loading = false;

		console.log("[LoadMore] Hook mounted", {
			elementId: this.el.id,
			initialPage: this.page(),
			phxScroll: this.el.getAttribute("phx-scroll"),
			phxTarget: this.el.getAttribute("phx-target"),
			dataPage: this.el.dataset.page
		});

		this.observer = new IntersectionObserver(
			(entries) => this.loadMore(entries),
			{
				root: null, // window by default
				rootMargin: "400px",
				threshold: 0.1,
			},
		);
		this.observer.observe(this.el);

		// Store click handler reference so we can remove it later
		this.clickHandler = (e) => {
			let entryCount = this.el.dataset.entryCount;
			if (entryCount !== undefined && entryCount !== "0") {
				// Scope search to feed container
				const feedContainer = this.el.closest('[data-feed]') || this.el.closest('[role="feed"]') || this.el.parentElement;
				let items = feedContainer ? feedContainer.getElementsByClassName("infinite_scroll_hidden") : [];
				if (items.length != 0) {
					console.log("[LoadMore] Click revealing hidden items", { count: items.length });
					for (let element of items) {
						element.style.display = "block";
						element.classList.remove("infinite_scroll_hidden");
					}
					// Prevent the default click action (don't trigger server request)
					e.preventDefault();
					// Reset entryCount - server will set it again if there are more preloaded items
					this.el.dataset.entryCount = "0";
				} else {
					console.log("no infinite_scroll_hidden items found");
				}
			} else {
				console.log("no entryCount");
			}
		};
		
		this.el.addEventListener("click", this.clickHandler);
	},
	destroyed() {
		if (this.observer) {
			this.observer.unobserve(this.el);
			this.observer.disconnect();
			this.observer = null;
		}
		if (this.clickHandler) {
			this.el.removeEventListener("click", this.clickHandler);
			this.clickHandler = null;
		}
	},
	handleError() {
		// NOTE: This method is not currently wired up.
		// To use it, add this in mounted(): this.handleEvent("pagination_error", () => this.handleError());
		// And push the event from the server on error: push_event(socket, "pagination_error", %{})

		// Restore state on error
		if (this.originalPending !== undefined) {
			this.pending = this.originalPending;
		}
		this.loading = false;
		this.el.disabled = false;
		this.el.classList.remove("btn-disabled");
		this.el.classList.remove("phx-scroll-loading");
		console.log("Pagination request failed, state restored");
	},
	updated() {
		const newPage = this.page();
		console.log("[LoadMore] Hook updated", {
			oldPending: this.pending,
			newPage: newPage,
			wasLoading: this.loading
		});

		this.pending = newPage;
		this.loading = false;
		// Reset button state when component is updated
		this.el.disabled = false;
		this.el.classList.remove("btn-disabled");
		// Remove loading class to hide spinner
		this.el.classList.remove("phx-scroll-loading");
	},
};

export { LoadMore, Ignore };
