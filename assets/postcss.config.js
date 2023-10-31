// NOTE: parcel uses .postcssrc instead
module.exports = {
  plugins: {
    'postcss-import': {},
    'tailwindcss': {},
    autoprefixer: {},
    ...(process.env.NODE_ENV === 'production' ? { cssnano: {} } : {})
  }
};
