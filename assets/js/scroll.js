import { scrollBehavior } from "./motion.js";

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
		if (el) el.scrollIntoView({ behavior: scrollBehavior(), block: "center" })
	}
}

ScrollHooks.CarouselScroll = {
	mounted() {
		const el = this.el

		el.addEventListener("scroll-left", () => {
			el.scrollBy({ left: -300, behavior: scrollBehavior() });
		});
		el.addEventListener("scroll-right", () => {
			el.scrollBy({ left: 300, behavior: scrollBehavior() });
		});

		// Mouse-only drag-to-scroll: lets the whole carousel be dragged even when
		// the cursor lands on nested interactive or scrollable card content. Touch
		// is deliberately left alone — `overflow-x-auto` already pans natively
		// there, and taking over the gesture would steal vertical page scrolling
		// from the (naturally arced) thumb swipes that start on a carousel.
		let startX = 0
		let startScroll = 0
		let dragging = false
		let pointer = null

		const onMove = (e) => {
			if (pointer !== e.pointerId) return
			// the button can come up somewhere we never hear about (another frame,
			// a native drag, devtools); a moving pointer with nothing held is our
			// cue that the gesture is over
			if (e.buttons === 0) return endDrag()
			const dx = e.clientX - startX

			if (!dragging) {
				// a few pixels of slack, so a click doesn't read as a drag
				if (Math.abs(dx) < 6) return
				dragging = true
				el.style.scrollSnapType = "none"
				el.style.scrollBehavior = "auto"
				// keep receiving moves once the cursor leaves the carousel
				el.setPointerCapture(e.pointerId)
			}

			e.preventDefault()
			el.scrollLeft = startScroll - dx
		}

		const onUp = (e) => {
			if (pointer !== e.pointerId) return
			endDrag()
		}

		// Listeners live only for the duration of a gesture, so a carousel sitting
		// under the cursor doesn't dispatch a pointermove into JS on every frame.
		// They sit on `window`, not `el`: below the drag threshold there is no
		// pointer capture yet, so a press that travels off the carousel before
		// being released would otherwise never see its own pointerup.
		const endDrag = () => {
			pointer = null
			window.removeEventListener("pointermove", onMove)
			window.removeEventListener("pointerup", onUp)
			window.removeEventListener("pointercancel", onUp)
			if (dragging) {
				dragging = false
				// hand scroll-snap back so it settles to the nearest card
				el.style.scrollSnapType = ""
				el.style.scrollBehavior = ""
			}
		}

		const onDown = (e) => {
			if (e.pointerType !== "mouse" || e.button !== 0) return
			pointer = e.pointerId
			startX = e.clientX
			startScroll = el.scrollLeft
			dragging = false
			window.addEventListener("pointermove", onMove)
			window.addEventListener("pointerup", onUp)
			window.addEventListener("pointercancel", onUp)
		}

		el.addEventListener("pointerdown", onDown)

		this._carouselCleanup = () => {
			el.removeEventListener("pointerdown", onDown)
			endDrag()
		}
	},
	destroyed() {
		if (this._carouselCleanup) this._carouselCleanup()
	}
}

// True if an ancestor between target and stopAt (exclusive) is genuinely
// scrollable — shared touch arbiter for the composer scroll lock and pull-to-refresh.
export function hasScrollableAncestor(target, stopAt) {
	// iOS WebKit can report a Text node as a touch target
	let el = target instanceof Element ? target : (target && target.parentElement) || null
	while (el && el !== stopAt) {
		if (el.scrollHeight > el.clientHeight) {
			const oy = getComputedStyle(el).overflowY
			if (oy === "auto" || oy === "scroll") return true
		}
		el = el.parentElement
	}
	return false
}

export { ScrollHooks };
