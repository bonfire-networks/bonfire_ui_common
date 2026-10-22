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

ScrollHooks.ScrollRow = {
	mounted() {
		const el = this.el
		this.onScroll = () => this.markEdges()
		this.onWheel = (e) => {
			if (Math.abs(e.deltaY) <= Math.abs(e.deltaX)) return
			const max = el.scrollWidth - el.clientWidth
			if (max <= 0) return
			if ((e.deltaY < 0 && el.scrollLeft <= 0) || (e.deltaY > 0 && el.scrollLeft >= max - 1)) return
			e.preventDefault()
			el.scrollLeft += e.deltaY
		}
		el.addEventListener("scroll", this.onScroll, { passive: true })
		el.addEventListener("wheel", this.onWheel, { passive: false })
		this.resizeObserver = new ResizeObserver(this.onScroll)
		this.resizeObserver.observe(el)
		this.reveal("auto")
		this.markEdges()
	},
	updated() {
		this.reveal(scrollBehavior())
		this.markEdges()
	},
	destroyed() {
		this.el.removeEventListener("scroll", this.onScroll)
		this.el.removeEventListener("wheel", this.onWheel)
		this.resizeObserver.disconnect()
	},
	reveal(behavior) {
		const el = this.el
		const current = el.querySelector('[aria-current="page"]')
		if (!current || el.scrollWidth <= el.clientWidth) return
		const row = el.getBoundingClientRect()
		const chip = current.getBoundingClientRect()
		const left = el.scrollLeft + chip.left - row.left - (row.width - chip.width) / 2
		el.scrollTo({ left, behavior })
	},
	markEdges() {
		const el = this.el
		const max = el.scrollWidth - el.clientWidth
		el.toggleAttribute("data-fade-start", el.scrollLeft > 1)
		el.toggleAttribute("data-fade-end", el.scrollLeft < max - 1)
	}
}

ScrollHooks.CarouselScroll = {
	mounted() {
		const el = this.el

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
			this._dotsObserver?.disconnect()
			this._clampObserver?.disconnect()
		}

		this.watchDots()
		this.watchClamped()
	},
	// re-observed on every patch: the server renders the dots without a current one, so a patch clears what we marked, and the observer's first callback marks it again
	updated() {
		this.watchDots()
		this.watchClamped()
	},
	// `CarouselLive expandable`: marks the cards whose tile (first child) is clipped, so CSS shows their toggle. Its content is observed too, as a clipped tile keeps its size while an image in it loads. Marked via `this.js()` so the mark survives patches inside the card, which don't call `updated()` here.
	watchClamped() {
		if (!this.el.hasAttribute("data-expandable")) return
		this._clampObserver ??= new ResizeObserver((entries) => {
			const cards = new Set(entries.map((entry) => entry.target.closest("[data-carousel-card]")))
			// an expanded card isn't clipped, but keeps its toggle to collapse it
			const clipped = [...cards]
				.filter((card) => card && !card.hasAttribute("data-expanded"))
				.map((card) => [card, card.firstElementChild.scrollHeight > card.firstElementChild.clientHeight + 1])
			for (const [card, isClipped] of clipped) {
				if (isClipped === card.hasAttribute("data-clamped")) continue
				if (isClipped) this.js().setAttribute(card, "data-clamped", "")
				else this.js().removeAttribute(card, "data-clamped")
			}
		})
		this._observedTiles ??= new WeakSet()
		for (const card of this.el.children) {
			for (const target of [card.firstElementChild, card.firstElementChild?.firstElementChild]) {
				if (!target || this._observedTiles.has(target)) continue
				this._observedTiles.add(target)
				this._clampObserver.observe(target)
			}
		}
	},
	// A carousel with dots (`data-carousel-dots` naming it) marks the dot of the card mostly in view, so scrolling or swiping shows where you are.
	watchDots() {
		this._dotsObserver?.disconnect()
		const dots = document.querySelectorAll(`[data-carousel-dots="${this.el.id}"] [data-role=carousel_dot]`)
		if (!dots.length) return
		const cards = [...this.el.children]
		this._dotsObserver = new IntersectionObserver(
			(entries) => {
				for (const entry of entries) {
					if (entry.intersectionRatio < 0.6) continue
					const current = cards.indexOf(entry.target)
					dots.forEach((dot, i) => dot.toggleAttribute("data-on", i === current))
				}
			},
			{ root: this.el, threshold: 0.6 }
		)
		cards.forEach((card) => this._dotsObserver.observe(card))
	},
	destroyed() {
		if (this._carouselCleanup) this._carouselCleanup()
	}
}

// Carousel prev/next buttons (`data-carousel-scroll` + `aria-controls`), for
// every `.carousel-scroll`: one delegated listener instead of per-button
// `JS.dispatch`, so the arrows also work on static guest pages (no LiveView
// socket, where `JS.dispatch` would be misrouted) and survive re-renders.
// Steps by one card so a partially visible next card becomes the current one.
function scrollCarouselStep(button) {
	const carousel = document.getElementById(button.getAttribute("aria-controls"))
	if (!carousel) return
	const card = carousel.firstElementChild
	const gap = parseFloat(getComputedStyle(carousel).columnGap) || 0
	const step = card ? card.getBoundingClientRect().width + gap : 300
	const direction = button.dataset.carouselScroll === "previous" ? -1 : 1
	carousel.scrollBy({ left: direction * step, behavior: scrollBehavior() })
}

// module scope runs once per bundle, and each page loads a single bundle
document.addEventListener("click", (event) => {
	const button = event.target.closest("[data-carousel-scroll][aria-controls]")
	if (button) scrollCarouselStep(button)
})

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
