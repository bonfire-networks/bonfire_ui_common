// import { themeChange } from "theme-change"
import "vanilla-colorful/hex-color-picker.js";
import "vanilla-colorful/hex-input.js";

let ColourPicker = {
  mounted() {
    const id = this.el.id;
    const picker = this.el.querySelector("hex-color-picker");
    const input = this.el.querySelector("hex-input");
    const preview = this.el.querySelector(".colour_preview");
    const scope = this.el.dataset.scope;
    let debounceTimer;
    
    // Make sure we have valid elements
    if (!picker || !input) {
      console.error("Required elements not found for ColorPicker", this.el);
      return;
    }
    
    // Initialize with current value
    let currentColor = typeof input.color === 'string' ? input.color : "#000000";
    
    // Ensure it has a # prefix for consistency
    if (currentColor && !currentColor.startsWith('#')) {
      currentColor = '#' + currentColor;
    }
    
    // Update all UI elements with the initial color
    picker.color = currentColor;
    input.color = currentColor;
    if (preview) {
      preview.style.backgroundColor = currentColor;
    }

    // Debounced function to send the color to the backend
    const updateThemeColor = (newColor) => {
      // Safety check: ensure newColor is a string
      if (typeof newColor !== 'string') {
        console.error("Invalid color value:", newColor);
        return;
      }
      
      // Ensure it has a # prefix for consistency
      if (!newColor.startsWith('#')) {
        newColor = '#' + newColor;
      }
      
      // Update UI elements
      picker.color = newColor;
      input.color = newColor;
      if (preview) {
        preview.style.backgroundColor = newColor;
      }
      
      // Clear previous timer
      clearTimeout(debounceTimer);
      
      // Set new timer
      debounceTimer = setTimeout(() => {
        console.log(`Updating theme color ${id} to ${newColor}`);
        
        // Send the event to the backend with hex color
        this.pushEvent("Bonfire.Common.Settings:put", {
          keys: "ui:theme:custom:" + id,
          values: newColor,
          scope: scope,
        });
        
        // Update the theme immediately for preview
        this.updateCustomTheme(id, newColor);
      }, 500);
    };

    // Helper function to update CSS variables for live preview
    this.updateCustomTheme = (colorKey, colorValue) => {
      // Get the CSS variable name that corresponds to the color key
      let cssVariable = "--color-" + colorKey;
      if (colorKey.includes("color-")) {
        cssVariable = "--" + colorKey;
      }
      
      // Update the CSS variable on the root element
      document.documentElement.style.setProperty(cssVariable, colorValue);
      
      console.log(`Updated CSS variable ${cssVariable} to ${colorValue}`);
    };

    // Event listener for the color picker
    picker.addEventListener("color-changed", (event) => {
      const newColor = event.detail.value;
      if (typeof newColor === 'string') {
        updateThemeColor(newColor);
      } else {
        console.error("Invalid color from picker event:", event.detail);
      }
    });

    // Event listener for the input field
    input.addEventListener("color-changed", (event) => {
      const newColor = event.detail.value;
      if (typeof newColor === 'string') {
        updateThemeColor(newColor);
      } else {
        console.error("Invalid color from input event:", event.detail);
      }
    });

    // Log initial state for debugging
    console.log("ColourPicker initialized", {
      id,
      initialColor: currentColor,
      pickerColor: picker.color,
      inputColor: input.color
    });
  },
};

export { ColourPicker };