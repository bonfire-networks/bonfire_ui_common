// Check if running on ARM32 platform based on OS or environment variable
// We specifically target ARM32 platforms, not ARM64 
const isArmLegacy = process.arch === 'arm' || 
                   process.env.PLATFORM === 'arm' || 
                   process.env.PLATFORM === 'arm32' || 
                   process.env.PLATFORM === 'arm32v7';

// Safely check if a module exists before including it
function moduleExists(name) {
  try {
    require.resolve(name);
    return true;
  } catch (e) {
    return false;
  }
}

// Create the plugins configuration
const tailwindPlugin = isArmLegacy ? 
  // On ARM32, use regular tailwindcss
  { 'tailwindcss': {} } : 
  // On other platforms, use @tailwindcss/postcss with lightningcss
  { '@tailwindcss/postcss': { spacing: true } };

// Only add autoprefixer if it's available and in production
// const autoprefixerPlugin = (process.env.NODE_ENV === 'production' && moduleExists('autoprefixer')) ? 
//   { 'autoprefixer': {} } : 
//   {};

export default {
  plugins: {
    ...tailwindPlugin,
    // ...autoprefixerPlugin
  }
}