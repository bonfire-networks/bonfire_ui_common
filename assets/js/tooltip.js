import {
	flip,
	shift,
	offset,
	autoUpdate,
	computePosition,
} from "@floating-ui/dom";

let TooltipHooks = {};

TooltipHooks.Tooltip = {
	mounted() {
		const tooltipWrapper = this.el;
		const position = tooltipWrapper.getAttribute("data-position");
		const trigger = tooltipWrapper.getAttribute("data-trigger");
		const closeOnInsideClick = tooltipWrapper.getAttribute("data-close-on-inside-click") === "true";
		const button = this.el.querySelector(".tooltip-button");
		const tooltip = this.el.querySelector(".tooltip");
		let showTimeout;
		let hideTimeout;
		let isHoveringButton = false;
		let isHoveringTooltip = false;
		let cleanup = null;
		
		// Store state on hook instance for access from lifecycle methods
		this.isUpdating = false;
		this.pendingUpdate = false;
		
		// Store cleanup function for lifecycle methods
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
			}).then(({ x, y }) => {
				if (!this.isUpdating && tooltip) {
					Object.assign(tooltip.style, {
						left: `${x}px`,
						top: `${y}px`,
					});
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

		const showTooltip = () => {
			clearTimeout(hideTimeout);
			if (trigger === "hover") {
				clearTimeout(showTimeout);
				showTimeout = setTimeout(() => {
					tooltip.style.display = 'block';
					tooltip.style.pointerEvents = 'auto';
					startPositionUpdate();
				}, 200);
			} else {
				tooltip.style.display = 'block';
				tooltip.style.pointerEvents = 'auto';
				startPositionUpdate();
			}
		};

		const hideTooltip = () => {
			const shouldHide = trigger === "hover" ? 
				!isHoveringButton && !isHoveringTooltip : 
				true;

			if (shouldHide) {
				const delay = trigger === "hover" ? 50 : 0;
				hideTimeout = setTimeout(() => {
					clearTimeout(showTimeout);
					tooltip.style.display = '';
					tooltip.style.pointerEvents = '';
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
				// Only check for clicks outside both tooltip and button
				if (!tooltip.contains(event.target) && !button.contains(event.target)) {
					hideTooltip();
				}
			},
			// tooltipClick: (event) => {
			// 	// This handler is specifically for clicks inside the tooltip
			// 	if (closeOnInsideClick) {
			// 		hideTooltip();
			// 	}
			// }
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
			document.addEventListener('click', handlers.clickOutside);
			
			// If closeOnInsideClick is enabled, add a click handler to the tooltip
			// if (closeOnInsideClick) {
			// 	tooltip.addEventListener('click', handlers.tooltipClick);
			// }
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
				document.removeEventListener('click', handlers.clickOutside);
				
				// if (closeOnInsideClick) {
				// 	tooltip.removeEventListener('click', handlers.tooltipClick);
				// }
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
