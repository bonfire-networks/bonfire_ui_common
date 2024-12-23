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
		const buttons = this.el.querySelectorAll(".tooltip-button");
		// console.log(buttons);
		const button = buttons[0];
		const tooltip = this.el.querySelector(".tooltip");
		let showTimeout;
		let hideTimeout;
		let isHoveringButton = false;
		let isHoveringTooltip = false;

		function update() {
			autoUpdate(button, tooltip, () => {
				computePosition(button, tooltip, {
					placement: position || "top",
					middleware: [offset(6), flip({ padding: 5 }), shift({ padding: 5 })],
				}).then(({ x, y }) => {
					Object.assign(tooltip.style, {
						left: `${x}px`,
						top: `${y}px`,
					});
				});
			});
		}

		function showTooltip() {
			clearTimeout(hideTimeout);
			if (trigger === "hover") {
				clearTimeout(showTimeout);
				showTimeout = setTimeout(() => {
					tooltip.style.display = 'block';
					tooltip.style.pointerEvents = 'auto';
					update();
				}, 200);
			} else {
				tooltip.style.display = 'block';
				tooltip.style.pointerEvents = 'auto';
				update();
			}
		}

		function hideTooltip() {
			// Only hide if both button and tooltip are not being hovered
			if (!isHoveringButton && !isHoveringTooltip && trigger === "hover") {
				hideTimeout = setTimeout(() => {
					clearTimeout(showTimeout);
					tooltip.style.display = '';
					tooltip.style.pointerEvents = '';
				}, 50); // Small delay to allow movement between elements
			} else if (trigger !== "hover") {
				clearTimeout(showTimeout);
				tooltip.style.display = '';
				tooltip.style.pointerEvents = '';
			}
		}

		if (trigger === "hover") {
			// Button hover handlers
			buttons.forEach((button) => {
				button.addEventListener('mouseenter', () => {
					isHoveringButton = true;
					showTooltip();
				})
			});

			buttons.forEach((button) => {
				button.addEventListener('mouseleave', () => {
					isHoveringButton = false;
					hideTooltip();
				})
			});

			// Tooltip hover handlers
			tooltip.addEventListener('mouseenter', () => {
				isHoveringTooltip = true;
				clearTimeout(hideTimeout);
				tooltip.style.display = 'block';
				tooltip.style.pointerEvents = 'auto';
			});

			tooltip.addEventListener('mouseleave', () => {
				isHoveringTooltip = false;
				hideTooltip();
			});

			// Focus handlers for accessibility
			buttons.forEach((button) => {
				button.addEventListener('focus', showTooltip)
			});
			buttons.forEach((button) => {
				button.addEventListener('blur', hideTooltip)
			});

		} else {
			// Click behavior
			buttons.forEach((button) => {
				button.addEventListener('click', () => {
					if (tooltip.style.display === 'block') {
						hideTooltip();
					} else {
						showTooltip();
					}
				})
			});

			// Handle clicks outside
			document.addEventListener("click", (event) => {
				const isClickInsideTooltip = tooltip.contains(event.target);
				const isClickOnButton = button.contains(event.target);
				if (!isClickInsideTooltip && !isClickOnButton) {
					hideTooltip();
				}
			});
		}
	},
};

export { TooltipHooks };