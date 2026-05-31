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
		const el = this.el

		el.addEventListener("scroll-left", () => {
			el.scrollBy({ left: -300, behavior: "smooth" });
		});
		el.addEventListener("scroll-right", () => {
			el.scrollBy({ left: 300, behavior: "smooth" });
		});

		// Drag/swipe-to-scroll: lets the whole carousel be dragged horizontally even
		// when the finger lands on nested interactive or scrollable card content.
		// The template sets `touch-action: pan-y` so the browser hands us horizontal
		// gestures (we drive scrollLeft) while keeping vertical page scroll native.
		let startX = 0
		let startY = 0
		let startScroll = 0
		let dragging = false
		let decided = false
		this._pointer = null

		const onDown = (e) => {
			if (e.pointerType === "mouse" && e.button !== 0) return
			this._pointer = e.pointerId
			startX = e.clientX
			startY = e.clientY
			startScroll = el.scrollLeft
			dragging = false
			decided = false
		}

		const onMove = (e) => {
			if (this._pointer !== e.pointerId) return
			const dx = e.clientX - startX
			const dy = e.clientY - startY

			if (!decided) {
				if (Math.abs(dx) < 6 && Math.abs(dy) < 6) return
				decided = true
				if (Math.abs(dx) > Math.abs(dy)) {
					// horizontal intent: take over and scroll the carousel
					dragging = true
					el.style.scrollSnapType = "none"
					el.style.scrollBehavior = "auto"
					el.setPointerCapture(e.pointerId)
				} else {
					// vertical intent: bail out and let the page scroll
					this._pointer = null
					return
				}
			}

			if (dragging) {
				e.preventDefault()
				el.scrollLeft = startScroll - dx
			}
		}

		const onUp = (e) => {
			if (this._pointer !== e.pointerId) return
			this._pointer = null
			if (dragging) {
				dragging = false
				// restore CSS scroll-snap so it settles to the nearest card
				el.style.scrollSnapType = ""
				el.style.scrollBehavior = ""
			}
		}

		el.addEventListener("pointerdown", onDown)
		el.addEventListener("pointermove", onMove, { passive: false })
		el.addEventListener("pointerup", onUp)
		el.addEventListener("pointercancel", onUp)

		this._carouselCleanup = () => {
			el.removeEventListener("pointerdown", onDown)
			el.removeEventListener("pointermove", onMove)
			el.removeEventListener("pointerup", onUp)
			el.removeEventListener("pointercancel", onUp)
		}
	},
	destroyed() {
		if (this._carouselCleanup) this._carouselCleanup()
	}
}

export { ScrollHooks };
