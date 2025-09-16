import { decodeBlurHash } from "fast-blurhash";

export default {
	mounted() {
		const canvas = this.el.getElementsByTagName("canvas")[0];
		if (!canvas) return;

		// Get container dimensions
		const rect = this.el.getBoundingClientRect();
		const width = Math.max(rect.width, 32);
		const height = Math.max(rect.height, 32);

		// Set canvas to match container size exactly to prevent stretching
		canvas.width = width;
		canvas.height = height;
		canvas.style.width = width + 'px';
		canvas.style.height = height + 'px';

		this.renderBlurHash(canvas, width, height);
	},
	
	renderBlurHash(canvas, width, height) {
		try {
			const hash = this.el.dataset.hash || "L6Pj0^jE.AyE_3t7t7R**0o#DgR4";
			const pixels = decodeBlurHash(hash, width, height);

			const ctx = canvas.getContext("2d");
			if (!ctx) return;
			
			const imageData = ctx.createImageData(width, height);
			imageData.data.set(pixels);
			ctx.putImageData(imageData, 0, 0);
		} catch (error) {
			const ctx = canvas.getContext("2d");
			if (ctx) {
				ctx.fillStyle = "#f0f0f0";
				ctx.fillRect(0, 0, width, height);
			}
		}
	}
};