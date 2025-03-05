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
