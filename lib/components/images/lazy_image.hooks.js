import { decodeBlurHash } from "fast-blurhash";

export default {
	mounted() {
		// Set up lazy loading with IntersectionObserver for all paths
		this.setupLazyLoading();

		// Only proceed with blurhash logic if canvas exists (Path A)
		const canvas = this.el.querySelector('canvas');
		if (!canvas) return;

		const img = this.el.querySelector('img');

		// Get container dimensions for better canvas sizing
		const rect = this.el.getBoundingClientRect();
		let width = Math.max(rect.width, 32);
		let height = Math.max(rect.height, 32);

		// Cap dimensions for blurhash to prevent memory issues
		const maxBlurHashDimension = 96;

		// If image has dimensions in data attributes, use its aspect ratio
		if (img && img.dataset.width && img.dataset.height) {
			const imgWidth = parseInt(img.dataset.width);
			const imgHeight = parseInt(img.dataset.height);
			const aspectRatio = imgWidth / imgHeight;

			if (!isNaN(aspectRatio) && aspectRatio > 0) {
				// Calculate height based on width and image aspect ratio
				height = Math.round(width / aspectRatio);
			}
		}

		// Apply dimension limits
		width = Math.min(width, maxBlurHashDimension);
		height = Math.min(height, maxBlurHashDimension);

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
		const img = this.el.querySelector('img[data-role="image"]');
		const placeholder = this.el.querySelector('[data-role="placeholder"]');
		const src = this.el.dataset.src;

		if (!img || !src) return;

		// Skip if image already has correct src (template fallback handled it)
		if (img.src === src) return;

		// Check if image is already loaded from a previous render
		if (img.src && img.src !== window.location.href && img.complete && img.naturalHeight > 0) {
			this.showImage(img, placeholder);
			return;
		}

		// Create IntersectionObserver for lazy loading
		this.observer = new IntersectionObserver(
			(entries) => {
				entries.forEach((entry) => {
					if (entry.isIntersecting) {
						// Load the image
						img.src = src;
						// Set up load event listeners
						img.addEventListener('load', () => this.showImage(img, placeholder), { once: true });
						img.addEventListener('error', () => this.handleImageError(img, placeholder), { once: true });
						// Disconnect observer after loading
						this.observer.disconnect();
					}
				});
			},
			{
				rootMargin: '300px',
				threshold: 0.01
			}
		);

		// Start observing
		this.observedElement = this.el;
		this.observer.observe(this.observedElement);
	},

	showImage(img, placeholder) {
		// Hide placeholder if it exists
		if (placeholder) {
			placeholder.style.display = 'none';
		}
		// Show image with smooth transition
		img.style.display = 'block';
		img.style.opacity = '0';
		// Use requestAnimationFrame for smoother transition
		requestAnimationFrame(() => {
			img.style.opacity = '1';
		});
	},

	handleImageError(img, placeholder) {
		// Keep placeholder visible on error
		// Could show a fallback icon here if needed
	},
	
	renderBlurHash(canvas, width, height) {
		try {
			const hash = this.el.dataset.hash || "L6Pj0^jE.AyE_3t7t7R**0o#DgR4";

			// Basic validation
			if (!hash || hash.length < 6 || width <= 0 || height <= 0 || width > 96 || height > 96) {
				this.renderFallback(canvas, width, height);
				return;
			}

			const pixels = decodeBlurHash(hash, width, height);
			const ctx = canvas.getContext("2d");
			if (!ctx) return;

			const imageData = ctx.createImageData(width, height);
			imageData.data.set(pixels);
			ctx.putImageData(imageData, 0, 0);
		} catch (error) {
			console.warn('BlurHash decode failed:', error);
			this.renderFallback(canvas, width, height);
		}
	},

	renderFallback(canvas, width, height) {
		const ctx = canvas.getContext("2d");
		if (ctx) {
			// Fill with a subtle gray placeholder on error
			ctx.fillStyle = "#e5e7eb"; // Neutral gray fallback
			ctx.fillRect(0, 0, width, height);
		}
	}
};