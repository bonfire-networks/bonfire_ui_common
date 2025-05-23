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
		if (target.isIntersecting && this.pending == this.page()) {
			let items = document.getElementsByClassName("infinite_scroll_hidden");
			if (items.length == 0) {
				let event = this.el.getAttribute("phx-scroll");
				if (event) {
					// add the disabled attribute to this.el
					this.el.disabled = true;
					this.el.classList.add("btn-disabled");
					
					this.pending = this.page() + 1;
					this.pushEventTo(
						this.el.getAttribute("phx-target"),
						event,
						this.getPhxValues(this.el),
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
		this.pending = this.page();
		this.observer = new IntersectionObserver(
			(entries) => this.loadMore(entries),
			{
				root: null, // window by default
				rootMargin: "400px",
				threshold: 0.1,
			},
		);
		this.observer.observe(this.el);

		this.el.addEventListener("click", (e) => {
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
				this.el.getElementsByTagName("span")[0].innerHTML = "Load more";
				this.el.dataset.entryCount = 0;
			} else {
				console.log("no entryCount");
			}
		});
	},
	destroyed() {
		this.observer.unobserve(this.el);
	},
	updated() {
		this.pending = this.page();
		// Reset button state when component is updated
		this.el.disabled = false;
		this.el.classList.remove("btn-disabled");
		// Reset loading state
		this.pushEvent("set_loading_state", { loading: false });
	},
};

export { LoadMore, Ignore };
