import "vanilla-colorful/hex-color-picker.js";
import "vanilla-colorful/hex-input.js";

let ColourPicker = {
	// Every swatch shares one page-wide modal (ReusableModalLive), and LiveView may reuse a
	// previously-opened picker node — so the apply handler resolves key/value/scope from the
	// *clicked* button rather than mount-time refs.
	mounted() {
		this.cacheRefs();
		this.syncWidgets();

		this.onPickerChange = (e) => {
			if (this.input) this.input.color = e.detail.value;
			this.setPreview(e.detail.value);
		};
		this.onInputChange = (e) => {
			if (this.picker) this.picker.color = e.detail.value;
			this.setPreview(e.detail.value);
		};
		this.onApply = (event) => {
			const root = event.currentTarget.closest("[data-color-key]");
			const input = root && root.querySelector("hex-input");
			const colorKey = root && root.dataset.colorKey;
			if (!root || !input || !colorKey) return;
			this.pushEvent("Bonfire.Common.Settings:put_custom_theme_token", {
				token: colorKey,
				value: input.color,
				// data-scope is on the picker node, since it's teleported away from the custom theme panel.
				scope: root.dataset.scope,
				close_modal: true,
			});
		};

		this.bindRefs();
	},

	updated() {
		this.unbindRefs();
		this.cacheRefs();
		this.bindRefs();
		this.syncWidgets();
	},

	destroyed() {
		this.unbindRefs();
	},

	bindRefs() {
		if (this.picker) this.picker.addEventListener("color-changed", this.onPickerChange);
		if (this.input) this.input.addEventListener("color-changed", this.onInputChange);
		if (this.applyButton) this.applyButton.addEventListener("click", this.onApply);
	},

	unbindRefs() {
		if (this.picker && this.onPickerChange) {
			this.picker.removeEventListener("color-changed", this.onPickerChange);
		}
		if (this.input && this.onInputChange) {
			this.input.removeEventListener("color-changed", this.onInputChange);
		}
		if (this.applyButton && this.onApply) {
			this.applyButton.removeEventListener("click", this.onApply);
		}
	},

	cacheRefs() {
		this.picker = this.el.querySelector("hex-color-picker");
		this.input = this.el.querySelector("hex-input");
		this.preview = this.el.querySelector(".colour_preview");
		this.applyButton = this.el.querySelector("[data-role='apply_custom_color']");
	},

	setPreview(value) {
		if (this.preview) this.preview.style.backgroundColor = value;
	},

	syncWidgets() {
		if (!this.input) return;
		const colorKey = this.el.dataset.colorKey;
		// The inline style already normalizes configured integers and bare hex values.
		const computedColor = getComputedStyle(this.el)
			.getPropertyValue("--" + colorKey)
			.trim();
		const value = this.toHex(computedColor) || "#000000";

		this.input.color = value;
		if (this.picker) this.picker.color = value;
		this.setPreview(value);
	},

	toHex(value) {
		if (!value || !CSS.supports("color", value)) return null;

		const canvas = document.createElement("canvas");
		canvas.width = 1;
		canvas.height = 1;
		const context = canvas.getContext("2d", { willReadFrequently: true });
		if (!context) return null;

		context.clearRect(0, 0, 1, 1);
		context.fillStyle = value;
		context.fillRect(0, 0, 1, 1);
		const [red, green, blue] = context.getImageData(0, 0, 1, 1).data;

		return `#${[red, green, blue]
			.map((channel) => channel.toString(16).padStart(2, "0"))
			.join("")}`;
	},
};

export { ColourPicker };
