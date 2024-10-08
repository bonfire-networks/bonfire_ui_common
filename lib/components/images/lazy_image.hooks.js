import { decodeBlurHash } from "fast-blurhash";

export default {
	mounted() {
		// const canvas = document.createElement('canvas');
		const canvas = this.el.getElementsByTagName("canvas")[0];
		// console.log(canvas)
		const w = canvas.width || 40;
		const h = canvas.height || 40;
		const default_hash = "LEHV6nWB2yk8pyo0adR*.7kCMdnj";
		const hash = this.el.dataset.hash;
		// console.log(hash)

		// decode blurHash image
		const pixels = decodeBlurHash(hash || default_hash, w, h);
		// console.log(pixels)

		// draw it on canvas
		const ctx = canvas.getContext("2d");
		const imageData = ctx.createImageData(w, h);

		imageData.data.set(pixels);
		// console.log(imageData)
		ctx.putImageData(imageData, 0, 0);
		// document.body.append(canvas);
	},
};
