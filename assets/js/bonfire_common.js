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

// Handle expandable content detection
window.addEventListener("bonfire:check-expandable", (event) => {
  console.log("Checking expandable:", event.detail);
  
  // The container element that dispatched the event
  const containerEl = event.detail.dispatcher;
  if (!containerEl) {
    console.log("Container element not found in event.detail");
    return;
  }
  
  // Extract ID from the container's ID
  const idMatch = containerEl.id.match(/note_container_(.+)/);
  if (!idMatch) {
    console.log("Could not extract ID from container:", containerEl.id);
    return;
  }
  
  const noteId = idMatch[1];
  console.log("Note ID:", noteId);
  
  // Find related elements
  const expandableEl = document.getElementById(`expandable_note_${noteId}`);
  const controlsEl = document.getElementById(`expandable_controls_${noteId}`);
  
  if (!expandableEl) {
    console.log("Expandable element not found:", `expandable_note_${noteId}`);
    return;
  }
  
  if (!controlsEl) {
    console.log("Controls element not found:", `expandable_controls_${noteId}`);
    return;
  }
  
  if (!expandableEl) {
    console.log("Expandable element not found:", `expandable_note_${noteId}`);
    return;
  }
  
  // Check if content is larger than its container (truncated)
  // We need to temporarily remove line-clamp to get accurate scrollHeight
  const originalClass = expandableEl.className;
  expandableEl.classList.remove('previewable_truncate');
  
  // Force a reflow to ensure the browser recalculates dimensions
  void expandableEl.offsetHeight;
  
  const contentHeight = expandableEl.scrollHeight;
  const containerHeight = 180;
  const isExpandable = contentHeight > containerHeight;
  
  console.log("Content height:", contentHeight, "Container height:", containerHeight, "Is expandable:", isExpandable);
  
  // Restore original class
  expandableEl.className = originalClass;
  
  if (isExpandable) {
    controlsEl.classList.remove('hidden');
  } else {
    controlsEl.classList.add('hidden');
  }
});

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
