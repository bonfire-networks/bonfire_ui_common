let CopyHooks = {};

CopyHooks.Copy = {
	mounted() {
		let { to, clipboardText } = this.el.dataset;

		this.el.addEventListener("click", (ev) => {
			ev.preventDefault();
			let el;
			let text;
			
			// Check for explicit clipboard text first
			if (clipboardText) {
				text = clipboardText;
			} else if (to) {
				el = document.getElementById(to);
			} else {
				el = this.el;
			}
			
			// If we don't have text yet, try to get it from the element
			if (!text && el) {
				let link = el.getAttribute("href");
				console.log(link);

				if (link) {
					text = link;
				} else {
					text = el.value || el.textContent;
				}
			}

			if (text !== undefined) {
				navigator.clipboard.writeText(text).then(() => {
					let msg = "Copied! 👀";
					console.log(msg);
					if (this.flash) {
						this.flash("success", msg);
					} else {
						let label = el && el.querySelector('[data-role="label"]');
						if (label) {
							let originalText = label.innerHTML;
							label.innerHTML = msg;
							setTimeout(() => {
								label.innerHTML = originalText;
							}, 2000);
						} else {
							console.log("No flash or label to show copy message");
							// add a tooltip next the element that says "copied!" and disappear after 3 seconds
							this.el.setAttribute("data-tip", msg);
							this.el.classList.add("tooltip", "tooltip-open");

							setTimeout(() => {
								this.el.removeAttribute("data-tip");
								this.el.classList.remove("tooltip", "tooltip-open");
							}, 2000);
						}
					}
				});
			}
		});
	},
};

export { CopyHooks };
