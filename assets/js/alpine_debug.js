// Enable Alpine.js debug mode
window.Alpine = window.Alpine || {}
Alpine.debug = true

console.log('Alpine debug file loaded, Alpine object:', window.Alpine)

// Add global error handler for Alpine.js
document.addEventListener('alpine:init', () => {
  console.log('Alpine:init event fired')
  
  // Track all refs
  Alpine.magic('debug', (el) => {
    return {
      refs() {
        const root = el.closest('[x-data]')
        console.log('Component element:', root)
        console.log('Component _x_refs:', root?._x_refs)
        console.log('Available $refs:', Alpine.$refs)
        return root?._x_refs
      },
      data() {
        const root = el.closest('[x-data]')
        console.log('Component data:', root?._x_dataStack?.[0])
        return root?._x_dataStack?.[0]
      },
      element: el
    }
  })
})

// Track Alpine component lifecycle
document.addEventListener('alpine:initialized', () => {
  console.group('Alpine components initialized')
  // Get all Alpine components
  const components = document.querySelectorAll('[x-data]')
  components.forEach(component => {
    console.log('Component:', {
      element: component,
      data: component.getAttribute('x-data'),
      refs: component._x_refs
    })
  })
  console.groupEnd()
})

// Log all Alpine errors with more context
window.addEventListener('error', (event) => {
  if (event.error?.stack?.includes('alpine')) {
    console.group('Alpine.js Error')
    console.log('Error in element:', event.target)
    if (event.target.outerHTML) {
      console.log('Element HTML:', event.target.outerHTML)
      const xDataContainer = event.target.closest('[x-data]')
      if (xDataContainer) {
        console.log('Closest x-data container:', xDataContainer.outerHTML)
      }
    }
    console.log('Error:', event.error)
    console.log('Error stack:', event.error.stack)
    console.groupEnd()
  }
})

// Monitor DOM mutations for Alpine attributes
const observer = new MutationObserver((mutations) => {
  mutations.forEach((mutation) => {
    if (mutation.type === 'attributes' && 
        mutation.attributeName && 
        mutation.attributeName.startsWith('x-') &&
        mutation.target instanceof Element) {
      console.log('Alpine attribute changed:', {
        element: mutation.target,
        attribute: mutation.attributeName,
        value: mutation.target.getAttribute(mutation.attributeName)
      })
    }
  })
})

// Start observing once DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  observer.observe(document.body, {
    attributes: true,
    subtree: true,
    attributeFilter: ['x-data', 'x-ref', 'x-init']
  })
})
