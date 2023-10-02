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
  content: [
    '../lib/**/*{.leex,.heex,.sface,_live.ex}',
    // '../assets/js/**/*.js',
    // '../(extensions|forks|deps)/*/lib/**/*{.leex,.heex,.sface,_live.ex}',
    // '../{extensions,forks,deps}/*/assets/js/**/*.js',
    '../../../lib/**/*{.leex,.heex,.sface,_live.ex}',
    // '../../../assets/js/**/*.js', 
    '../../../(extensions|forks|deps)/*/lib/**/*{.leex,.heex,.sface,_live.ex}',
    // '../../../{extensions,forks,deps}/*/assets/js/**/*.js',
    // '../../../deps/live_select/lib/live_select/component.*ex', // what should this point to?
    // './js/*.js'
  ],
  theme: {
    extend: {
      fontFamily: {
        'sans': ['OpenDyslexic', 'Inter', 'Noto Sans', 'Roboto', 'system-ui', 'sans-serif']
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
          ...require("daisyui/src/theming/themes")["[data-theme=light]"],
          "primary": "#1B74E4",
          "primary-content": "#fff",
          "--rounded-box": "1rem", // border radius rounded-box utility class, used in card and other large boxes
          "--rounded-btn": "0.5rem", // border radius rounded-btn utility class, used in buttons and similar element
          "--rounded-badge": "1.9rem", // border radius rounded-badge utility class, used in badges and similar
          "--animation-btn": "0.25s", // duration of animation when you click on button
          "--animation-input": "0.2s", // duration of animation for inputs like checkbox, toggle, radio, etc
          "--btn-text-case": "uppercase", // set default text transform for buttons
          "--btn-focus-scale": "0.95", // scale transform of button when you focus on it
          "--border-btn": "1px", // border width of buttons
          "--tab-border": "1px", // border width of tabs
          "--tab-radius": "0.5rem", // border radius of tabs
        },
        bonfire: {
          ...require("daisyui/src/theming/themes")["[data-theme=forest]"],
          "primary": "#fde047",
          "--rounded-box": "1rem", // border radius rounded-box utility class, used in card and other large boxes
          "--rounded-btn": "0.5rem", // border radius rounded-btn utility class, used in buttons and similar element
          "--rounded-badge": "1.9rem", // border radius rounded-badge utility class, used in badges and similar
          "--animation-btn": "0.25s", // duration of animation when you click on button
          "--animation-input": "0.2s", // duration of animation for inputs like checkbox, toggle, radio, etc
          "--btn-text-case": "uppercase", // set default text transform for buttons
          "--btn-focus-scale": "0.95", // scale transform of button when you focus on it
          "--border-btn": "1px", // border width of buttons
          "--tab-border": "1px", // border width of tabs
          "--tab-radius": "0.5rem", // border radius of tabs
        }
      },
      "cupcake", "bumblebee", "emerald", "corporate", "synthwave", "retro", "cyberpunk", "valentine", "halloween", "garden", "forest", "aqua", "lofi", "pastel", "fantasy", "wireframe", "black", "luxury", "dracula", "cmyk", "autumn", "business", "acid", "lemonade", "night", "coffee", "winter"
    ]
  },
  variants: {
    extend: {
     ringWidth:['hover'],
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
