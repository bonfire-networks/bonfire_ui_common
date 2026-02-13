import "../../../../deps/phoenix_html";

// lightweight JS toolkit
import Alpine from "alpinejs";
import intersect from "@alpinejs/intersect";
import collapse from "@alpinejs/collapse";

console.log('Setting up Alpine.js plugins and initialization')

Alpine.plugin(intersect);
Alpine.plugin(collapse);

window.Alpine = Alpine

// Function to detect mobile devices and add appropriate class
const detectMobileDevice = () => {
  // Check if device is mobile using media query
  const isMobile = window.matchMedia("(max-width: 768px), (pointer: coarse) and (max-width: 1024px)").matches;
  const hasMobileClass = document.body.classList.contains("is-container-mobile");

  // Only modify if state needs to change to prevent unnecessary DOM mutations
  if (isMobile && !hasMobileClass) {
    document.body.classList.add("is-container-mobile");
    console.log("Mobile device detected, added is-mobile class to body");
  } else if (!isMobile && hasMobileClass) {
    document.body.classList.remove("is-container-mobile");
    console.log("Desktop device detected, removed is-mobile class from body");
  }
};

// Run detection on load and resize (debounced)
detectMobileDevice();
window.addEventListener("resize", () => {
  // Debounce mobile detection to prevent excessive class changes
  if (window.requestIdleCallback) {
    requestIdleCallback(detectMobileDevice, { timeout: 200 });
  } else {
    setTimeout(detectMobileDevice, 100);
  }
});

Alpine.start();

// Cache for dimensions to prevent forced reflows
let lastWidth = 0;
let lastHeight = 0;
let dimensionUpdateTimeout = null;

const winnerDimension = () => {
  // Cache height check - only update if changed
  const currentHeight = window.innerHeight;
  if (currentHeight !== lastHeight) {
    lastHeight = currentHeight;
    document.documentElement.style.setProperty(
      "--inner-window-height",
      `${currentHeight}px`
    );
  }

  // Cache width check - only update if changed
  const inner = document.querySelector("[data-id='layout']");
  if (!inner) {
    console.log("Layout element not found");
    return;
  }
  
  const currentWidth = inner.offsetWidth;
  if (currentWidth !== lastWidth) {
    lastWidth = currentWidth;
    document.documentElement.style.setProperty(
      "--inner-main-width",
      `${currentWidth}px`
    );
  }
};

// Debounced version for resize events to prevent excessive style recalculation
const debouncedWinnerDimension = () => {
  // Cancel any pending update
  if (dimensionUpdateTimeout) {
    clearTimeout(dimensionUpdateTimeout);
  }
  
  // Use idle callback to avoid blocking navigation
  if (window.requestIdleCallback) {
    requestIdleCallback(() => {
      winnerDimension();
    }, { timeout: 200 });
  } else {
    // Fallback with debounced timeout
    dimensionUpdateTimeout = setTimeout(winnerDimension, 100);
  }
};

winnerDimension();
window.addEventListener("resize", debouncedWinnerDimension);


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
