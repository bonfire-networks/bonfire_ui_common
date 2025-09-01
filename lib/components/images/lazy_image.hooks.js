import { decodeBlurHash } from "fast-blurhash";

export default {
	mounted() {
		const canvas = this.el.getElementsByTagName("canvas")[0];
		const img = this.el.querySelector("img");

		if (!canvas) return;

		// Set initial dimensions that work well with blurhash
		let width = 32;
		let height = 32;

		// If image has dimensions in data attributes, use its aspect ratio
		setTimeout(() => {
			if (img && img.dataset.width && img.dataset.height) {
				const imgWidth = parseInt(img.dataset.width);
				const imgHeight = parseInt(img.dataset.height);
				const aspectRatio = imgWidth / imgHeight;
				
				if (!isNaN(aspectRatio) && aspectRatio > 0) {
					// Maintain aspect ratio with a base size that renders well
					if (aspectRatio > 1) {
						// Landscape
						width = 40;
						height = Math.round(width / aspectRatio);
					} else {
						// Portrait or square
						height = 40;
						width = Math.round(height * aspectRatio);
					}
					
					// Apply updated dimensions to canvas
					canvas.width = width;
					canvas.height = height;
					
					// Render blurhash with correct dimensions
					this.renderBlurHash(canvas, width, height);
					return;
				}
			}
			
			// Render blurhash with default dimensions if no valid aspect ratio
			this.renderBlurHash(canvas, width, height);
		}, 0);

		// Apply initial dimensions to canvas
		canvas.width = width;
		canvas.height = height;
	},
	
	renderBlurHash(canvas, width, height) {
		try {
			// Use consistent fallback hash with server value
			const default_hash = "L6Pj0^jE.AyE_3t7t7R**0o#DgR4";
			const hash = this.el.dataset.hash;

			// decode blurHash image
			const pixels = decodeBlurHash(hash || default_hash, width, height);

			// draw it on canvas with null check
			const ctx = canvas.getContext("2d");
			if (!ctx) return;
			
			const imageData = ctx.createImageData(width, height);
			imageData.data.set(pixels);
			ctx.putImageData(imageData, 0, 0);
		} catch (error) {
			// Fallback: fill with a neutral color
			const ctx = canvas.getContext("2d");
			if (ctx) {
				ctx.fillStyle = "#f0f0f0";
				ctx.fillRect(0, 0, width, height);
			}
		}
	},
	
	destroyed() {
		// Clean up canvas to prevent memory leaks
		const canvas = this.el?.getElementsByTagName("canvas")[0];
		if (canvas) {
			const ctx = canvas.getContext("2d");
			if (ctx) {
				ctx.clearRect(0, 0, canvas.width, canvas.height);
			}
		}
	},
};