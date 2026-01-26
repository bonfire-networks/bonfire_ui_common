import {
	flip,
	shift,
	offset,
	autoUpdate,
	computePosition,
} from "@floating-ui/dom";

// Check for user's reduced motion preference for accessibility
const prefersReducedMotion = () =>
	window.matchMedia('(prefers-reduced-motion: reduce)').matches;

let TooltipHooks = {};

TooltipHooks.Tooltip = {
	mounted() {
		const tooltipWrapper = this.el;
		const position = tooltipWrapper.getAttribute("data-position");
		const trigger = tooltipWrapper.getAttribute("data-trigger");
		const button = this.el.querySelector(".tooltip-button");
		const tooltip = this.el.querySelector(".tooltip");
		let showTimeout;
		let hideTimeout;
		let isHoveringButton = false;
		let isHoveringTooltip = false;

		// Instance state for lifecycle methods
		this.isUpdating = false;
		this.pendingUpdate = false;
		this.cleanup = null;

		const updatePosition = () => {
			if (this.isUpdating) {
				this.pendingUpdate = true;
				return;
			}

			if (!button || !tooltip) {
				return;
			}

			computePosition(button, tooltip, {
				placement: position || "top",
				middleware: [offset(6), flip({ padding: 5 }), shift({ padding: 5 })],
			}).then(({ x, y, placement }) => {
				if (!this.isUpdating && tooltip) {
					Object.assign(tooltip.style, {
						left: `${x}px`,
						top: `${y}px`,
					});
					// Set placement for CSS directional animations
					tooltip.setAttribute('data-placement', placement);
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
				// For regular tooltips, use autoUpdate without elementResize
				this.cleanup = autoUpdate(button, tooltip, updatePosition, {
					elementResize: false,
					ancestorScroll: true,
					ancestorResize: true
				});
			}
		};
		
		// Store function on instance for lifecycle methods
		this.startPositionUpdate = startPositionUpdate;

		// Display tooltip and start entrance animation
		const displayTooltip = () => {
			tooltip.style.display = 'block';
			tooltip.style.pointerEvents = 'auto';
			startPositionUpdate();
			if (!prefersReducedMotion()) {
				tooltip.classList.add('tooltip-animated');
				tooltip.offsetHeight; // Force reflow for animation
				tooltip.classList.add('tooltip-visible');
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

		const hideTooltip = () => {
			const shouldHide = trigger === "hover" ?
				!isHoveringButton && !isHoveringTooltip :
				true;

			if (shouldHide) {
				// Remove visible class first for exit animation
				tooltip.classList.remove('tooltip-visible');

				const delay = prefersReducedMotion() ? 0 : (trigger === "hover" ? 150 : 100);
				hideTimeout = setTimeout(() => {
					clearTimeout(showTimeout);
					tooltip.style.display = '';
					tooltip.style.pointerEvents = '';
					tooltip.classList.remove('tooltip-animated');
					if (this.cleanup) {
						this.cleanup();
						this.cleanup = null;
					}
				}, delay);
			}
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
					if (tooltip.style.display === 'block') {
						event.stopImmediatePropagation();
						event.preventDefault();
					}
					hideTooltip();
				}
			}
		};

		// Attach event listeners
		if (trigger === "hover") {
			button.addEventListener('mouseenter', handlers.buttonMouseEnter);
			button.addEventListener('mouseleave', handlers.buttonMouseLeave);
			button.addEventListener('focus', showTooltip);
			button.addEventListener('blur', hideTooltip);
			tooltip.addEventListener('mouseenter', handlers.tooltipMouseEnter);
			tooltip.addEventListener('mouseleave', handlers.tooltipMouseLeave);
		} else {
			button.addEventListener('click', handlers.buttonClick);
			document.addEventListener('click', handlers.clickOutside, true);
		}

		// Cleanup function
		this.eventCleanup = () => {
			this.cleanup?.();
			clearTimeout(showTimeout);
			clearTimeout(hideTimeout);
			
			if (trigger === "hover") {
				button.removeEventListener('mouseenter', handlers.buttonMouseEnter);
				button.removeEventListener('mouseleave', handlers.buttonMouseLeave);
				button.removeEventListener('focus', showTooltip);
				button.removeEventListener('blur', hideTooltip);
				tooltip.removeEventListener('mouseenter', handlers.tooltipMouseEnter);
				tooltip.removeEventListener('mouseleave', handlers.tooltipMouseLeave);
			} else {
				button.removeEventListener('click', handlers.buttonClick);
				document.removeEventListener('click', handlers.clickOutside, true);
			}
		};
	},

	destroyed() {
		this.eventCleanup?.();
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
		// Resume positioning after DOM updates
		this.isUpdating = false;
		if (this.pendingUpdate) {
			setTimeout(() => {
				if (this.startPositionUpdate) {
					this.startPositionUpdate();
				}
				this.pendingUpdate = false;
			}, 50);
		}
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
