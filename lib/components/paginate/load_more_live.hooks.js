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
		const target = entries[0];
		if (target.isIntersecting && this.pending == this.page() && !this.loading) {
			let items = document.getElementsByClassName("infinite_scroll_hidden");
			if (items.length == 0) {
				let event = this.el.getAttribute("phx-scroll");
				if (event) {
					// Set loading flag to prevent concurrent requests
					this.loading = true;
					// add the disabled attribute to this.el
					this.el.disabled = true;
					this.el.classList.add("btn-disabled");
					
					// Store original pending value for error recovery
					this.originalPending = this.pending;
					this.pending = this.page() + 1;
					
					// Add loading reference to track this specific request
					const loadingRef = this.pending;
					const values = this.getPhxValues(this.el);
					values._loading_ref = loadingRef;
					
					this.pushEventTo(
						this.el.getAttribute("phx-target"),
						event,
						values,
					);
				} else {
					console.log("skip loading more because no phx-scroll event");
				}
			} else {
				console.log("skip loading more because there are hidden items to show first");
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
			if (undefined != entryCount || entryCount != "0") {
				let items = document.getElementsByClassName("infinite_scroll_hidden");
				if (items.length != 0) {
					for (let element of items) {
						element.style.display = "block";
					}
					e.preventDefault();
				} else {
					console.log("no infinite_scroll_hidden");
				}
				const span = this.el.getElementsByTagName("span")[0];
				if (span) {
					console.warn("resetting span textContent");
					span.textContent = "Load more"; // Safer than innerHTML
				}
				this.el.dataset.entryCount = 0;
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
		// Restore state on error
		if (this.originalPending !== undefined) {
			this.pending = this.originalPending;
		}
		this.loading = false;
		this.el.disabled = false;
		this.el.classList.remove("btn-disabled");
		console.log("Pagination request failed, state restored");
	},
	updated() {
		this.pending = this.page();
		this.loading = false;
		// Reset button state when component is updated
		this.el.disabled = false;
		this.el.classList.remove("btn-disabled");
		// Reset loading state
		this.pushEvent("set_loading_state", { loading: false });
	},
};

export { LoadMore, Ignore };
