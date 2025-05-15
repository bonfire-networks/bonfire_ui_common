import { decodeBlurHash } from "fast-blurhash";

export default {
	mounted() {
		const canvas = this.el.getElementsByTagName("canvas")[0];
		const img = this.el.querySelector("img");

		// Set initial dimensions that work well with blurhash
		let width = 32;
		let height = 32;

		// If image has dimensions in data attributes, use its aspect ratio
		if (img && img.dataset.width && img.dataset.height) {
			const aspectRatio = parseInt(img.dataset.width) / parseInt(img.dataset.height);
			if (!isNaN(aspectRatio)) {
				height = Math.round(width / aspectRatio);
			}
		}

		// Apply dimensions to canvas
		canvas.width = width;
		canvas.height = height;

		// Let CSS handle scaling to match container
		canvas.style.width = "100%";
		canvas.style.height = "auto";

		// Use consistent fallback hash with server value
		const default_hash = "L6Pj0^jE.AyE_3t7t7R**0o#DgR4";
		const hash = this.el.dataset.hash;

		// decode blurHash image
		const pixels = decodeBlurHash(hash || default_hash, width, height);

		// draw it on canvas
		const ctx = canvas.getContext("2d");
		const imageData = ctx.createImageData(width, height);

		imageData.data.set(pixels);
		ctx.putImageData(imageData, 0, 0);
	},
};
