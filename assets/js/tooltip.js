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
		const button = this.el.querySelector(".tooltip-button");
		const tooltip = this.el.querySelector(".tooltip");
		let showTimeout;
		let hideTimeout;
		let isHoveringButton = false;
		let isHoveringTooltip = false;
		let cleanup = null;

		const updatePosition = () => {
			computePosition(button, tooltip, {
				placement: position || "top",
				middleware: [offset(6), flip({ padding: 5 }), shift({ padding: 5 })],
			}).then(({ x, y }) => {
				Object.assign(tooltip.style, {
					left: `${x}px`,
					top: `${y}px`,
				});
			});
		};

		const startPositionUpdate = () => {
			const hasEmojiPicker = tooltip.querySelector('emoji-picker');
			if (hasEmojiPicker) {
				// For emoji picker, just do a one-time position update
				updatePosition();
			} else if (!cleanup) {
				// For regular tooltips, use autoUpdate without elementResize
				cleanup = autoUpdate(button, tooltip, updatePosition, {
					elementResize: false,
					ancestorScroll: true,
					ancestorResize: true
				});
			}
		};

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
					if (cleanup) {
						cleanup();
						cleanup = null;
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
			document.addEventListener('click', handlers.clickOutside);
		}

		// Cleanup function
		this.cleanup = () => {
			cleanup?.();
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
			}
		};
	},

	destroyed() {
		this.cleanup?.();
	}
};

export { TooltipHooks };