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

// Function to detect mobile devices and add appropriate class
const detectMobileDevice = () => {
  // Check if device is mobile using media query
  const isMobile = window.matchMedia("(max-width: 768px), (pointer: coarse) and (max-width: 1024px)").matches;
  
  if (isMobile) {
    document.body.classList.add("is-container-mobile");
    console.log("Mobile device detected, added is-mobile class to body");
  } else {
    document.body.classList.remove("is-container-mobile");
    console.log("Desktop device detected, removed is-mobile class from body");
  }
};

// Run detection on load and resize
detectMobileDevice();
window.addEventListener("resize", detectMobileDevice);

Alpine.start();

const winnerDimension = () => {
	// set the viewport inner height in a custom property on the root of the document
	document.documentElement.style.setProperty(
		"--inner-window-height",
		`${window.innerHeight}px`,
	);
  // fidn the element with data-id="layout"
  const inner = document.querySelector("[data-id='layout']");
  if (!inner) {
    console.log("Layout element not found");
    return;
  }
  console.log(inner)
  // set the main section inner width in a custom property on the root of the document
  document.documentElement.style.setProperty(
    "--inner-main-width",
    `${inner.offsetWidth}px`,
  );
};

winnerDimension();
window.addEventListener("resize", winnerDimension);


// CSS
// import * as tagifycss from "../node_modules/@yaireo/tagify/dist/tagify.css";
// import * as css from "../css/app.css"

import "./../../../../deps/phoenix_live_head";

// Initialize PWA features 
import { registerServiceWorker } from './pwa/register.js';

// Only register service worker, nothing else
if (typeof window !== 'undefined') {
  registerServiceWorker();
}
