export default {
  mounted() {
    this.checkTruncation()
    this.setupClickHandlers()

    // Content inside a collapsed parent (eg. a reply in a collapsed thread branch) mounts with display:none and measures 0x0; expanding it is a client-side JS.show, so updated() never fires. Re-check on resize.
    if (window.ResizeObserver) {
      this.resizeObserver = new ResizeObserver(() => this.checkTruncation())
      this.resizeObserver.observe(this.el)
    }

    // an expandable carousel card around this content was expanded or collapsed (by its Show more pill): show or clamp the text with it
    this.onCardToggle = (e) => {
      if (!e.target.contains(this.el)) return
      const contentEl = this.contentEl()
      // a card can clip for its image alone: text that fits stays as it is
      const clipped = contentEl && contentEl.scrollHeight > contentEl.clientHeight
      if (!e.detail.expanded || clipped) this.toggleContent(e.detail.expanded)
    }
    document.addEventListener('bonfire:carousel:card-toggle', this.onCardToggle)
  },

  updated() {
    this.checkTruncation()
  },

  destroyed() {
    this.resizeObserver?.disconnect()
    document.removeEventListener('bonfire:carousel:card-toggle', this.onCardToggle)
  },

  // the body to clamp, which its component marks; nested content may hold others, so the first one is this component's own
  contentEl() {
    return this.el.querySelector('[data-truncatable]')
  },

  checkTruncation() {
    const contentEl = this.contentEl()
    if (!contentEl) return this.hideControls()

    // a body shown whole (eg. a post on its own page) has no clamp class, so it gets no controls
    const hasTruncateClass = contentEl.classList.contains('previewable_truncate')
    const isExpanded = contentEl.classList.contains('previewable_expanded')
    const isOverflowing = contentEl.scrollHeight > contentEl.clientHeight

    // Show controls if content is truncated and overflowing OR already expanded
    const needsControls = (hasTruncateClass && isOverflowing) || isExpanded

    const controls = this.el.querySelector('.read-more-controls')
    if (controls) {
      controls.style.display = needsControls ? 'block' : 'none'
    }
  },

  hideControls() {
    const controls = this.el.querySelector('.read-more-controls')
    if (controls) {
      controls.style.display = 'none'
    }
  },

  setupClickHandlers() {
    const readMoreBtn = this.el.querySelector('.read-more-btn')
    const readLessBtn = this.el.querySelector('.read-less-btn')

    if (readMoreBtn) {
      readMoreBtn.addEventListener('click', () => this.toggleContent(true))
    }

    if (readLessBtn) {
      readLessBtn.addEventListener('click', () => this.toggleContent(false))
    }
  },

  toggleContent(expand) {
    const contentEl = this.contentEl()
    const readMoreBtn = this.el.querySelector('.read-more-btn')
    const readLessBtn = this.el.querySelector('.read-less-btn')

    // already so: also ends the round trip with the carousel card (Read more expands the card, which tells this content to expand). Kept here rather than read from the classes, which `this.js()` only changes on the next frame.
    if (!!this.expanded === expand) return
    this.expanded = expand

    // via `this.js()` so a re-render (a like, an async load) keeps it as the user left it, instead of restoring the server's clamped markup
    if (contentEl) {
      if (expand) {
        this.js().removeClass(contentEl, 'previewable_truncate')
        this.js().addClass(contentEl, 'previewable_expanded')
      } else {
        this.js().removeClass(contentEl, 'previewable_expanded')
        this.js().addClass(contentEl, 'previewable_truncate')
      }
    }

    if (readMoreBtn) {
      this.js().setAttribute(readMoreBtn, 'style', `display: ${expand ? 'none' : 'block'}`)
    }

    if (readLessBtn) {
      this.js().setAttribute(readLessBtn, 'style', `display: ${expand ? 'block' : 'none'}`)
    }

    // an expandable carousel card around this content expands or collapses with it
    this.el.dispatchEvent(
      new CustomEvent('bonfire:content:toggle', { bubbles: true, detail: { expanded: expand } })
    )
  }
}
