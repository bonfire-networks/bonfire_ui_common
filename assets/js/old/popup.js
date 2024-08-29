let PopupHooks = {};
import tippy from "tippy.js";

// run to load previously chosen theme when first loading any page (note: not need if using data-theme param on HTML wrapper instead)
// themeChange()

PopupHooks.Popup = {
	mounted() {
		// Instanciate tippy
		const template = this.el.querySelector(".tippy_template");
		tippy(this.el.querySelector(".tippy"), {
			content: template.innerHTML,
			arrow: true,
			interactive: true,
			animation: "shift-away",
			delay: [500, 200],
			allowHTML: true,
		});
	},
};

export { PopupHooks };
