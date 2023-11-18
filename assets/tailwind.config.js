const colors = require('tailwindcss/colors')

// debug path resolution
// const fg = require('fast-glob');
// const entries = fg.sync(['../../../(extensions|forks|deps)/*/lib/**/*{.leex,.heex,.sface,_live.ex}'], { dot: true });
// console.log(entries)

module.exports = {
  mode: 'jit',
  future: {
    removeDeprecatedGapUtilities: true,
    purgeLayersByDefault: true,
  },
  presets: [
    require('./css/variants.js')
  ],
  content: [
    '../lib/**/*{.leex,.heex,.sface,_live.ex}',
    // '../assets/js/**/*.js',
    // '../(extensions|forks|deps)/*/lib/**/*{.leex,.heex,.sface,_live.ex}',
    // '../{extensions,forks,deps}/*/assets/js/**/*.js',
    '../../../lib/**/*{.leex,.heex,.sface,_live.ex}',
    // '../../../assets/js/**/*.js',
    '../../../(extensions|forks|deps)/*/lib/**/*{.leex,.heex,.sface,_live.ex}',
    '../../../data/current_flavour/config/flavour_assets/components.css'
    // '../../../{extensions,forks,deps}/*/assets/js/**/*.js',
    // '../../../deps/live_select/lib/live_select/component.*ex', // what should this point to?
    // './js/*.js'
  ],
  theme: {
    extend: {
      fontFamily: {
        'sans': ['OpenDyslexic', 'Luciole', 'Inter', 'Noto Sans', 'Roboto', 'system-ui', 'sans-serif']
      },
      screens: {
        'tablet': '920px',
        'tablet-lg': '1200px',
        'desktop-lg': '1448px',
        'wide': '1920px'
      },
      maxWidth: {
        '600': '600px'
      },
      colors: {
        gray: colors.gray,
        blueGray: colors.slate,
        amber: colors.amber,
        rose: colors.rose,
        orange: colors.orange,
        teal: colors.teal,
        cyan: colors.cyan
      },
      spacing: {
        '72': '18rem',
        '84': '21rem',
        '90': '22rem',
        '96': '26rem',
      },
      typography: (theme) => ({
        sm: {
          css: {
            fontSize: '15px',
            h1: {
              margin: 0
            },
            h2: {
              margin: 0
            },
            h3: {
              margin: 0
            },
            p: {
              margin: 0,
              lineHeight: '20px'
            },
            li: {
              lineHeight: '20px'
            }
          }
        },
        lg: {
          css: {
            h1: {
              margin: 0
            },
            h2: {
              margin: 0
            },
            h3: {
              margin: 0
            },
            p: {
              margin: 0,
              lineHeight: '20px'
            },
            li: {
              lineHeight: '20px'
            }
          }
        }
      }),
    }
  },
  daisyui: {
    darkTheme: "bonfire",
    themes: true,
    themes: [
      {
        light: {
          ...require("daisyui/src/theming/themes")["nord"]
        },
        bonfire: {
          ...require("daisyui/src/theming/themes")["dracula"],
          "primary": "#fde047"
        }
      },
      "cupcake", "dark", "bumblebee", "emerald", "corporate", "synthwave", "retro", "cyberpunk", "valentine", "halloween", "garden", "forest", "aqua", "lofi", "pastel", "fantasy", "wireframe", "black", "luxury", "dracula", "cmyk", "autumn", "business", "acid", "lemonade", "night", "coffee", "winter", "dim", "nord", "sunset"
    ]
  },
  variants: {
    extend: {
      ringWidth: ['hover'],
      divideColor: ['dark'],
      ringColor: ['group-hover', 'hover'],
      fontWeight: ['group-hover'],
      borderWidth: ['hover', 'focus'],
      typography: ['dark']
    }
  },
  plugins: [
    require('@tailwindcss/line-clamp'),
    require('@tailwindcss/typography'),
    require('daisyui')
    // require('tailwindcss-debug-screens')
  ],
}
