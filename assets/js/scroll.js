let ScrollHooks = {}

ScrollHooks.ScrollTo = {
	mounted() {
		const id = this.el.dataset.scrollToId
		let el
		if (id) {
			el = document.getElementById(id)
		} else {
			el = this.el
		}
		if (el) el.scrollIntoView({ behavior: "smooth", block: "center" })
	}
}

ScrollHooks.CarouselScroll = {
	mounted() {
		this.el.addEventListener("scroll-left", () => {
			this.el.scrollBy({ left: -300, behavior: "smooth" });
		});
		this.el.addEventListener("scroll-right", () => {
			this.el.scrollBy({ left: 300, behavior: "smooth" });
		});
	}
}

export { ScrollHooks };
