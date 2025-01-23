import "../../../../deps/phoenix_html";

// lightweight JS toolkit
import Alpine from "alpinejs";
import intersect from "@alpinejs/intersect";
import collapse from "@alpinejs/collapse";
import SVGInject from "@iconfu/svg-inject";

console.log('Setting up Alpine.js plugins and initialization')

Alpine.plugin(intersect);
Alpine.plugin(collapse);

// Make sure Alpine and SVGInject are available globally
window.Alpine = Alpine
window.SVGInject = SVGInject

Alpine.start();

const winnerDimension = () => {
	// set the viewport inner height in a custom property on the root of the document
	document.documentElement.style.setProperty(
		"--inner-window-height",
		`${window.innerHeight}px`,
	);
};

winnerDimension();
window.addEventListener("resize", winnerDimension);

// CSS
// import * as tagifycss from "../node_modules/@yaireo/tagify/dist/tagify.css";
// import * as css from "../css/app.css"

import "./../../../../deps/phoenix_live_head";
