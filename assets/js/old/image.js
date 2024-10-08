import { Hook, makeHook } from "phoenix_typed_hook";
let ImageHooks = {};

// import exifr from 'exifr'
// async function imageParseMeta(image) {
//   let options = {
//     // setting false on these blocks does not read them at all, except for IFD0 which is necessary
//     // because it contains pointer to GPS IFD. Though no tag values are read and once GPS pointer
//     // is found the IFD0 search-through ends.
//     ifd0: false, // image
//     ifd1: false, // thumbnail
//     exif: true, // ['ISO', 'FNumber']
//     iptc: ['Caption', 'Sublocation', 'City', 'State', 'CountryCode', 'Country', 'LocalCaption', 'DocumentNotes', 'Contact', 'Headline', 'Credit', 'Source', 'CopyrightNotice', 'Keywords'],
//     jfif: false, // (jpeg only)
//     ihdr: false, // (png only)
//     tiff: ['UserComment', 'OwnerName', 'SerialNumber'],
//     xmp: true, // ['author', 'description'],
//     icc: ['DeviceManufacturer', 'DeviceModel', 'DeviceModelDesc', 'MakeAndModel'],
//     userComment: true,
//     // Instead of `true` you can use array of tags to read. All other tags are not read at all.
//     // You can use string tag names as well as their numeric code. In this example 0x0004 = GPSLongitude
//     gps: ['GPSLatitudeRef', 'GPSLatitude', 'GPSLongitudeRef', 'GPSLongitude', 'GPSAltitudeRef', 'GPSAltitude', 0x0003, 0x0004],
//     interop: false,
//     translateKeys: true,
//     translateValues: true,
//     reviveValues: true,
//     sanitize: true,
//     mergeOutput: true,
//     silentErrors: true
//   }
//   // let data = await exifr.parse(image, options)
//   let data = await exifr.parse(image)
//   console.log(data)
//   // raw values
//   return data;
// }

// class imageMetadata extends Hook {
//   mounted() {
// let img = document.getElementById(this.el.dataset.img)
// if (img) img.addEventListener("load", async e => {
//   let file = e.target.currentSrc || e.target.src;
//   console.log(file)
//   imageParseMeta(file).then(ret => console.log('Ret:', ret))
// })
//   }
// }

// import avatar from 'animal-avatar-generator'
// class randomAnimalAvatar extends Hook {
//   mounted() {
//     console.log("avatar!")
//     if (this.el.innerHTML.length < 1) {
//       const svg = avatar((this.el.dataset.seed || this.el.id), {
//         size: this.el.dataset.size,
//         blackout: false,
//         round: false,
//         avatarColors: ['#801100', '#B62203', '#D73502', '#FC6400', '#FF7500', '#FAC000'],
//         backgroundColors: ['none']
//       })
//       this.el.innerHTML = svg
//     }
//   }
// }

import { decodeBlurHash } from "fast-blurhash";

class blurHash extends Hook {
	mounted() {
		// const canvas = this.el.getElementsByTagName('canvas')[0];
		// const w = canvas.width || 40
		// const h = canvas.height || 40
		// // decode blurHash image
		// const pixels = decodeBlurHash(this.el.dataset.hash || 'LEHV6nWB2yk8pyo0adR*.7kCMdnj', w, h);
		// // draw it on canvas
		// // const canvas = document.createElement('canvas');
		// const ctx = canvas.getContext('2d');
		// const imageData = ctx.createImageData(w, h);
		// imageData.data.set(pixels);
		// ctx.putImageData(imageData, 0, 0);
		// document.body.append(canvas);
	}
}

// ImageHooks.imageMetadata = makeHook(imageMetadata);
// ImageHooks.randomAnimalAvatar = makeHook(randomAnimalAvatar);
ImageHooks.blurHash = makeHook(blurHash);

export { ImageHooks };
