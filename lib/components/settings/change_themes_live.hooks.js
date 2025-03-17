// import { themeChange } from "theme-change"
import "vanilla-colorful/hex-color-picker.js";
import "vanilla-colorful/hex-input.js";

// run to load previously chosen theme when first loading any page (note: not need if using data-theme param on HTML wrapper instead)
// themeChange()

// let Themeable = {

//     mounted() {
//         // run on a view/component with theme-changing controls (wrapper should have phx-hook="Themeable")
//         themeChange(false)
//     },

// }

let ColourPicker = {
	mounted() {
		const id = this.el.id;
		const picker = this.el.querySelector("hex-color-picker");
		const input = this.el.querySelector("hex-input");
		const preview = this.el.querySelector(".colour_preview");
		const applyButton = this.el.querySelector("[data-role='apply_custom_color']");
		const scope = this.el.dataset.scope;
		// var count = 0;
		// var debounceCount = 0;
		// var debounce;

		let value = input.color.replace("#", "");
		picker.color = value;
		
		// Initialize preview
		if (preview) {
			preview.style.backgroundColor = "#" + value;
		}

		// const maybe_set = function (hook) {
		// 	console.log("maybe_set");
		// 	// Alpine.debounce(() => this.set(), 500)
		// 	// Alpine.throttle(() => this.set(), 500)

		// 	// Update the count by 1
		// 	// count++;

		// 	// Clear any existing debounce event
		// 	// clearTimeout(debounce);

		// 	// Update and log the counts after 3 seconds
		// 	// debounce = setTimeout(function () {
		// 	// 	// Update the debounceCount
		// 	// 	debounceCount++;
		// 	// 	console.log(id)
		// 	// 	console.log(value)
		// 	// 	console.log(scope)
		// 	// 	// we're not applying the color here anymore, just storing the value
		// 	// }, 1000);
		// };

		picker.addEventListener("color-changed", (event) => {
			value = event.detail.value;
			console.log(value);
			if (preview) {
				preview.style.backgroundColor = value;
			}
			console.log(preview);
			input.color = value;
			// Don't push the event here - only update UI preview
		});

		input.addEventListener("color-changed", (event) => {
			value = event.detail.value;
			picker.color = value;
			if (preview) {
				preview.style.backgroundColor = value;
			}
			// maybe_set(this);
			// Don't push the event here - only update UI preview
		});

		// Add event listener for the apply button
		if (applyButton) {
			applyButton.addEventListener("click", (event) => {
				console.log("Applying color:", value);
				console.log("ID:", id);
				console.log("Scope:", scope);
				
				this.pushEvent("Bonfire.Common.Settings:put", {
					keys: "ui:theme:custom:" + id,
					values: value,
					scope: scope,
				});
			});
		}
	},
};

export { ColourPicker };
