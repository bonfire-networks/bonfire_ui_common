import {
	flip,
	shift,
	size,
	offset,
	autoUpdate,
	computePosition,
} from "@floating-ui/dom";

import { prefersReducedMotion } from "./motion.js";

let TooltipHooks = {};

// Below `lg` (as the dock, `--mobile-dock-offset` in app.css and the `lg:` utilities) `sheet_on_mobile`
// dropdowns open as sheets. One query for the whole bundle, made on first use; `.matches` is a cached read.
let sheetQuery;
const sheetMatches = () => (sheetQuery ??= window.matchMedia("(max-width: 1023px)")).matches;

TooltipHooks.Tooltip = {
	mounted() {
		const tooltipWrapper = this.el;
		const position = tooltipWrapper.getAttribute("data-position");
		const boundarySelector = tooltipWrapper.getAttribute("data-boundary");
		const boundary = boundarySelector ? tooltipWrapper.closest(boundarySelector) : null;
		const overflowOptions = boundary ? { boundary, padding: 8 } : { padding: 5 };
		const trigger = tooltipWrapper.getAttribute("data-trigger");
		const noFlip = tooltipWrapper.getAttribute("data-no-flip") === "true";
		const closeOnInsideClick =
			tooltipWrapper.getAttribute("data-close-on-inside-click") === "true";
		const matchTriggerWidth =
			tooltipWrapper.getAttribute("data-match-trigger-width") === "true";
		const focusOnOpen = tooltipWrapper.getAttribute("data-focus-on-open");
		// DropdownLive `sheet_on_mobile`: below lg the panel opens as a bottom sheet. It goes to the
		// top layer as a popover, so no ancestor's transform, containment or stacking context can trap
		// it (the drawer, feed cards), and its ::backdrop dims the page.
		const sheetOnMobile = tooltipWrapper.getAttribute("data-sheet-on-mobile") === "true";
		const strategy =
			tooltipWrapper.getAttribute("data-strategy") === "fixed"
				? "fixed"
				: "absolute";
		const button = this.el.querySelector(".tooltip-button");
		const tooltip = this.el.querySelector(".tooltip:not(.tooltip-button)");
		let showTimeout;
		let hideTimeout;
		let isHoveringButton = false;
		let isHoveringTooltip = false;
		let isButtonFocused = false;
		let pendingRevealOptions = null;
		let revealPositionedTooltip = () => {};
		let sheetOpen = false;
		const asSheet = () =>
			sheetOnMobile && typeof tooltip?.showPopover === "function" && sheetMatches();
		// the page's own overflow, put back when the sheet closes
		let pageOverflow = null;

		// Instance state for lifecycle methods
		this.isUpdating = false;
		this.isOpen = false;
		this.cleanup = null;

		// embed only: nudge the parent iframe to re-measure on panel show/hide
		const framed = window.parent && window.parent !== window;
		const notifyParentResize = () => {
			if (!framed) return;
			let height = Math.max(
				document.body.scrollHeight,
				document.documentElement.scrollHeight,
			);
			// a fixed panel doesn't extend scrollHeight
			if (tooltip && tooltip.style.display === "block") {
				const rect = tooltip.getBoundingClientRect();
				const panelBottom = rect.bottom + window.scrollY;
				height = Math.max(height, Math.ceil(panelBottom) + 8);
			}
			window.parent.postMessage(
				{ type: "bonfire:iframe-resize", height },
				"*",
			);
		};

		// embed only
		this.panelResizeObserver =
			framed && typeof ResizeObserver !== "undefined"
				? new ResizeObserver(notifyParentResize)
				: null;

		const updatePosition = () => {
			if (this.isUpdating) {
				return;
			}

			if (!button || !tooltip) {
				return;
			}

			if (matchTriggerWidth) {
				tooltip.style.width = `${button.getBoundingClientRect().width}px`;
			}

			computePosition(button, tooltip, {
				placement: position || "top",
				strategy,
				middleware: [
					offset(6),
					...(!noFlip ? [flip(overflowOptions)] : []),
					shift(overflowOptions),
					...(boundary ? [size({
						...overflowOptions,
						apply({ availableHeight, availableWidth, elements }) {
							const height = `${Math.max(0, availableHeight)}px`;
							elements.floating.style.maxHeight = height;
							elements.floating.style.maxWidth = `${Math.max(0, availableWidth)}px`;
							elements.floating.style.overflowY = "auto";
							elements.floating.style.setProperty("--dropdown-available-height", height);
						},
					})] : []),
				],
			}).then(({ x, y, placement }) => {
				if (this.isUpdating) {
					// The updated hook repositions an open panel after the patch.
					return;
				}

				if (tooltip) {
					Object.assign(tooltip.style, {
						// keep the floating element's CSS position in sync with the
						// computed strategy: "fixed" lets the panel escape ancestor
						// stacking contexts / overflow (e.g. feed cards' `relative z-10`),
						// "absolute" matches the default `.dropdown-panel` rule.
						position: strategy,
						left: `${x}px`,
						top: `${y}px`,
					});
					// Set placement for CSS directional animations
					tooltip.setAttribute('data-placement', placement);
					revealPositionedTooltip();
				}
			});
		};

		// Store updatePosition on the tooltip element so external code can trigger recalculation
		// This is needed for lazy-loaded content like emoji pickers
		if (tooltip) {
			tooltip._updatePosition = updatePosition;
		}

		const startPositionUpdate = () => {
			const hasEmojiPicker = tooltip.querySelector('emoji-picker');
			if (hasEmojiPicker) {
				// For emoji picker, just do a one-time position update
				updatePosition();
			} else if (!this.cleanup) {
				// For regular tooltips, also reposition when the panel resizes, so content
				// loaded after opening (e.g. the user menu's profile switcher) can't push it off-screen
				const stopAutoUpdate = autoUpdate(button, tooltip, updatePosition, {
					elementResize: true,
					ancestorScroll: true,
					ancestorResize: true
				});
				const boundaryObserver = boundary ? new ResizeObserver(updatePosition) : null;
				boundaryObserver?.observe(boundary);
				this.cleanup = () => {
					stopAutoUpdate();
					boundaryObserver?.disconnect();
				};
			}
		};
		
		// Store function on instance for lifecycle methods
		this.startPositionUpdate = startPositionUpdate;

		// Sync aria-expanded on the trigger when it opts in (has the attribute)
		const syncExpanded = (value) => {
			if (button && button.hasAttribute('aria-expanded')) {
				button.setAttribute('aria-expanded', value ? 'true' : 'false');
			}
		};

		// entrance: the hidden state first, a reflow, then the visible state, so the transition runs
		const animateIn = () => {
			if (prefersReducedMotion()) return;
			tooltip.classList.add('tooltip-animated');
			tooltip.offsetHeight; // Force reflow for animation
			tooltip.classList.add('tooltip-visible');
		};

		revealPositionedTooltip = () => {
			if (!pendingRevealOptions || tooltip.style.display !== 'block') {
				return;
			}

			const { animate, focus } = pendingRevealOptions;
			pendingRevealOptions = null;
			tooltip.style.visibility = '';

			if (focus && focusOnOpen) {
				tooltip.querySelector(focusOnOpen)?.focus({ preventScroll: true });
			}
			if (animate) animateIn();
		};

		// No positioning: the sheet's place comes from `.dropdown-sheet` in app.css.
		const openSheet = ({ animate, focus }) => {
			sheetOpen = true;
			pendingRevealOptions = null;
			tooltip.classList.add("dropdown-sheet");
			// placement-specific entrance transforms don't apply to a sheet
			tooltip.removeAttribute("data-placement");
			tooltip.setAttribute("popover", "manual");
			// drop what a desktop open (Floating UI, match_trigger_width) left inline
			Object.assign(tooltip.style, {
				position: "", left: "", top: "", width: "", visibility: "",
				display: "block", pointerEvents: "auto",
			});
			if (!tooltip.matches(":popover-open")) tooltip.showPopover();
			// a sheet is modal: the page behind doesn't scroll
			if (pageOverflow === null) {
				pageOverflow = document.documentElement.style.overflow;
				document.documentElement.style.overflow = "hidden";
			}
			syncExpanded(true);
			// the trigger sits under the backdrop, so focus moves into the sheet
			if (focus) {
				const target = (focusOnOpen && tooltip.querySelector(focusOnOpen)) ||
					tooltip.querySelector("a[href], button:not([disabled]), summary, [tabindex]:not([tabindex='-1'])");
				target?.focus({ preventScroll: true });
			}
			if (animate) animateIn();
		};

		const closeSheet = () => {
			if (!sheetOpen) return;
			sheetOpen = false;
			if (tooltip.matches(":popover-open")) tooltip.hidePopover();
			tooltip.removeAttribute("popover");
			tooltip.classList.remove("dropdown-sheet");
			if (pageOverflow !== null) {
				document.documentElement.style.overflow = pageOverflow;
				pageOverflow = null;
			}
		};

		// Measure while invisible so a newly opened floating panel never paints
		// at the CSS fallback position before Floating UI has anchored it.
		const displayTooltip = ({ animate = true, focus = true } = {}) => {
			this.isOpen = true;
			if (asSheet()) return openSheet({ animate, focus });
			// the viewport may have crossed the breakpoint since the sheet opened
			closeSheet();
			pendingRevealOptions = { animate, focus };
			tooltip.style.visibility = 'hidden';
			// before measuring: Floating UI measures from the panel's current offsetParent, so a
			// `fixed` panel still `absolute` from `.dropdown-panel` gets wrapper-relative coords on first open
			tooltip.style.position = strategy;
			tooltip.style.display = 'block';
			tooltip.style.pointerEvents = 'auto';
			syncExpanded(true);
			startPositionUpdate();
			this.panelResizeObserver?.observe(tooltip);
		};

		// LiveView patches replace client-owned styles and aria-expanded while filtering.
		this.restoreTooltip = () => {
			if (this.isOpen) {
				displayTooltip({ animate: false, focus: false });
			} else {
				syncExpanded(false);
			}
		};

		const showTooltip = () => {
			clearTimeout(hideTimeout);
			if (trigger === "hover") {
				clearTimeout(showTimeout);
				const delay = prefersReducedMotion() ? 0 : 200;
				showTimeout = setTimeout(displayTooltip, delay);
			} else {
				displayTooltip();
			}
		};

		const finishHidingTooltip = () => {
			clearTimeout(showTimeout);
			tooltip.style.display = '';
			tooltip.style.visibility = '';
			tooltip.style.pointerEvents = '';
			tooltip.classList.remove('tooltip-animated');
			closeSheet();
			if (this.cleanup) {
				this.cleanup();
				this.cleanup = null;
			}
			// disconnect before display:none, then let the iframe shrink back
			this.panelResizeObserver?.disconnect();
			notifyParentResize();
		};

		const hideTooltip = ({ animate = true } = {}) => {
			const shouldHide = trigger === "hover" ?
				!isHoveringButton && !isHoveringTooltip && !isButtonFocused :
				true;

			if (shouldHide) {
				this.isOpen = false;
				pendingRevealOptions = null;
				// Remove visible class first for exit animation
				tooltip.classList.remove('tooltip-visible');
				syncExpanded(false);

				// the sheet slides back down (app.css `.dropdown-sheet`) before it leaves the top layer
				const delay =
					animate && !prefersReducedMotion()
						? (sheetOpen ? 200 : trigger === "hover" ? 150 : 100)
						: 0;

				if (delay === 0) {
					finishHidingTooltip();
				} else {
					hideTimeout = setTimeout(finishHidingTooltip, delay);
				}
			}
		};

		// a menu item, not a control that expands inside the sheet (`<details>`, `aria-expanded`)
		const isSheetAction = (target) => {
			const item = target.closest?.("a[href], button, [phx-click]");
			return !!item && item !== tooltip && tooltip.contains(item) &&
				!item.closest("summary") && !item.hasAttribute("aria-expanded");
		};

		// Event Handlers
		const handlers = {
			buttonMouseEnter: () => {
				isHoveringButton = true;
				showTooltip();
			},
			buttonMouseLeave: () => {
				isHoveringButton = false;
				hideTooltip();
			},
			buttonFocus: () => {
				isButtonFocused = true;
				clearTimeout(showTimeout);
				clearTimeout(hideTimeout);
				displayTooltip({ animate: false });
			},
			buttonBlur: () => {
				isButtonFocused = false;
				hideTooltip({ animate: false });
			},
			tooltipMouseEnter: () => {
				isHoveringTooltip = true;
				clearTimeout(hideTimeout);
				tooltip.style.display = 'block';
				tooltip.style.pointerEvents = 'auto';
				startPositionUpdate();
			},
			tooltipMouseLeave: () => {
				isHoveringTooltip = false;
				hideTooltip();
			},
			buttonClick: () => {
				tooltip.style.display === 'block' ? hideTooltip() : showTooltip();
			},
			clickOutside: (event) => {
				if (!tooltip.contains(event.target) && !button.contains(event.target)) {
					hideTooltip();
				} else if (sheetOpen && event.target === tooltip) {
					// a tap on the sheet's ::backdrop targets the panel itself: tell it apart by position
					const rect = tooltip.getBoundingClientRect();
					if (event.clientY < rect.top) {
						hideTooltip();
						button.focus({ preventScroll: true });
					}
				} else if (sheetOpen && isSheetAction(event.target)) {
					// an item opens a modal or acts in place: a sheet left open in the top layer would
					// cover it, so it goes at once, without the slide
					hideTooltip({ animate: false });
				}
			},
			escapeKey: (event) => {
				if (event.key === "Escape" && tooltip.style.display === "block") {
					event.stopPropagation();
					hideTooltip();
					// return focus to the trigger so keyboard users aren't dropped to <body>
					button.focus();
				}
			},
			// select-style dropdowns: close once an actionable item inside is picked
			insideClick: (event) => {
				if (event.target.closest("button, a, [phx-click], [data-scope], [data-role]")) {
					hideTooltip();
					button.focus({ preventScroll: true });
				}
			}
		};

		// Attach event listeners
		if (trigger === "hover") {
			button.addEventListener('mouseenter', handlers.buttonMouseEnter);
			button.addEventListener('mouseleave', handlers.buttonMouseLeave);
			button.addEventListener('focus', handlers.buttonFocus);
			button.addEventListener('blur', handlers.buttonBlur);
			tooltip.addEventListener('mouseenter', handlers.tooltipMouseEnter);
			tooltip.addEventListener('mouseleave', handlers.tooltipMouseLeave);
		} else {
			button.addEventListener('click', handlers.buttonClick);
			document.addEventListener('click', handlers.clickOutside, true);
			document.addEventListener('keydown', handlers.escapeKey, true);
			if (closeOnInsideClick) {
				tooltip.addEventListener('click', handlers.insideClick);
			}
		}

		// Cleanup function
		this.eventCleanup = () => {
			this.cleanup?.();
			clearTimeout(showTimeout);
			clearTimeout(hideTimeout);
			
			if (trigger === "hover") {
				button.removeEventListener('mouseenter', handlers.buttonMouseEnter);
				button.removeEventListener('mouseleave', handlers.buttonMouseLeave);
				button.removeEventListener('focus', handlers.buttonFocus);
				button.removeEventListener('blur', handlers.buttonBlur);
				tooltip.removeEventListener('mouseenter', handlers.tooltipMouseEnter);
				tooltip.removeEventListener('mouseleave', handlers.tooltipMouseLeave);
			} else {
				button.removeEventListener('click', handlers.buttonClick);
				document.removeEventListener('click', handlers.clickOutside, true);
				document.removeEventListener('keydown', handlers.escapeKey, true);
				if (closeOnInsideClick) {
					tooltip.removeEventListener('click', handlers.insideClick);
				}
			}
		};
	},

	destroyed() {
		this.eventCleanup?.();
		this.panelResizeObserver?.disconnect();
	},

	beforeUpdate() {
		// Pause positioning during DOM updates
		if (this.cleanup) {
			this.cleanup();
			this.cleanup = null;
		}
		this.isUpdating = true;
	},

	updated() {
		this.isUpdating = false;
		this.restoreTooltip();
	},

	disconnected() {
		// Handle connection loss
		if (this.cleanup) {
			this.cleanup();
			this.cleanup = null;
		}
	},

	reconnected() {
		// Handle reconnection - re-initialize if tooltip is visible
		const tooltip = this.el?.querySelector(".tooltip");
		if (tooltip && tooltip.style.display === 'block') {
			if (this.startPositionUpdate) {
				this.startPositionUpdate();
			}
		}
	}
};

export { TooltipHooks };
