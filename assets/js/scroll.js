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

export { ScrollHooks };
