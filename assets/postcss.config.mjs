
// Safely check if a module exists before including it
// function moduleExists(name) {
//   try {
//     require.resolve(name);
//     return true;
//   } catch (e) {
//     return false;
//   }
// }

// Only add autoprefixer if it's available and in production
// const autoprefixerPlugin = (process.env.NODE_ENV === 'production' && moduleExists('autoprefixer')) ? 
//   { 'autoprefixer': {} } : 
//   {};

export default {
  plugins: {
    '@tailwindcss/postcss': {
      spacing: true
    }
    // ...autoprefixerPlugin
  }
}