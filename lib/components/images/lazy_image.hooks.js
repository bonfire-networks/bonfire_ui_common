import { decodeBlurHash } from "fast-blurhash";

export default {
	mounted() {
		// Set up lazy loading with IntersectionObserver for all paths
		this.setupLazyLoading();

		// Only proceed with blurhash logic if canvas exists (Path A)
		const canvas = this.el.getElementsByTagName("canvas")[0];
		if (!canvas) return;

		const img = this.el.querySelector("img");

		// Get container dimensions for better canvas sizing
		const rect = this.el.getBoundingClientRect();
		let width = Math.max(rect.width, 32);
		let height = Math.max(rect.height, 32);

		// Cap dimensions for blurhash to prevent memory issues
		// Blurhash is meant for small placeholder images
		const maxBlurHashDimension = 128;
		width = Math.min(width, maxBlurHashDimension);
		height = Math.min(height, maxBlurHashDimension);

		// If image has dimensions in data attributes, use its aspect ratio
		if (img && img.dataset.width && img.dataset.height) {
			const imgWidth = parseInt(img.dataset.width);
			const imgHeight = parseInt(img.dataset.height);
			const aspectRatio = imgWidth / imgHeight;

			if (!isNaN(aspectRatio) && aspectRatio > 0) {
				// Calculate height based on capped width and image aspect ratio
				height = Math.round(width / aspectRatio);
				// Ensure height doesn't exceed max
				if (height > maxBlurHashDimension) {
					height = maxBlurHashDimension;
					width = Math.round(height * aspectRatio);
				}
			}
		}

		// Set canvas dimensions
		canvas.width = width;
		canvas.height = height;
		canvas.style.width = '100%';
		canvas.style.height = '100%';

		this.renderBlurHash(canvas, width, height);
	},

	destroyed() {
		// Clean up observer when component is destroyed
		if (this.observer) {
			if (this.observedElement) {
				this.observer.unobserve(this.observedElement);
			}
			this.observer.disconnect();
			this.observer = null;
		}
	},

	setupLazyLoading() {
		const img = this.el.querySelector("img");
		const src = this.el.dataset.src;

		if (!img || !src) return;

		// Create IntersectionObserver with 300px margin for preloading
		this.observer = new IntersectionObserver(
			(entries) => {
				entries.forEach((entry) => {
					if (entry.isIntersecting) {
						// Load the image
						img.src = src;
						// Disconnect observer after loading (once behavior)
						this.observer.disconnect();
					}
				});
			},
			{
				rootMargin: '300px', // 300px margin on all sides for preloading
				threshold: 0.01 // Trigger as soon as any part enters the margin
			}
		);

		// Start observing the element and store reference for cleanup
		this.observedElement = this.el;
		this.observer.observe(this.observedElement);
	},
	
	renderBlurHash(canvas, width, height) {
		try {
			const hash = this.el.dataset.hash || "L6Pj0^jE.AyE_3t7t7R**0o#DgR4";

			// Validate dimensions before decoding
			if (width <= 0 || height <= 0 || width > 256 || height > 256) {
				console.warn('BlurHash: Invalid dimensions', { width, height });
				return;
			}

			const pixels = decodeBlurHash(hash, width, height);

			const ctx = canvas.getContext("2d");
			if (!ctx) return;

			const imageData = ctx.createImageData(width, height);
			imageData.data.set(pixels);
			ctx.putImageData(imageData, 0, 0);
		} catch (error) {
			console.warn('BlurHash decode failed:', error, { width, height });
			const ctx = canvas.getContext("2d");
			if (ctx) {
				// Fill with a subtle gray placeholder on error
				ctx.fillStyle = "var(--color-base-200)";
				ctx.fillRect(0, 0, width, height);
			}
		}
	}
};