// Shared motion-preference helpers.
//
// One MediaQueryList for the whole bundle — `.matches` is a cached read, so
// callers can ask per interaction rather than caching a boolean that goes
// stale when the user flips the OS setting mid-session.
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")

const prefersReducedMotion = () => reducedMotion.matches

// An explicit `behavior` passed to scrollTo/scrollBy/scrollIntoView overrides
// the CSS `scroll-behavior` property outright, so the stylesheet's
// reduced-motion reset cannot reach those call sites — they have to ask.
const scrollBehavior = () => (prefersReducedMotion() ? "auto" : "smooth")

export { prefersReducedMotion, scrollBehavior }
