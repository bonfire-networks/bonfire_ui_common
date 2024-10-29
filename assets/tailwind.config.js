const colors = require("tailwindcss/colors");

// debug path resolution
// const fg = require('fast-glob');
// const entries = fg.sync(['../../../(extensions|forks|deps)/*/lib/**/*{.leex,.heex,.sface,_live.ex}'], { dot: true });
// console.log(entries)

module.exports = {
	mode: "jit",
	future: {
		removeDeprecatedGapUtilities: true,
		purgeLayersByDefault: true,
	},
	// presets: [
	//   require('../../../data/current_flavour/config/flavour_assets/variants.js') // TODO?
	// ],
	content: [
		"../lib/**/*{.leex,.heex,.sface,_live.ex,_view.ex}",
		// '../assets/js/**/*.js',
		// '../(extensions|forks|deps)/*/lib/**/*{.leex,.heex,.sface,_live.ex,_view.ex}',
		// '../{extensions,forks,deps}/*/assets/js/**/*.js',
		"../../../lib/**/*{.leex,.heex,.sface,_live.ex,_view.ex}",
		// '../../../assets/js/**/*.js',
		"../../../(extensions|forks|deps)/*/lib/**/*{.leex,.heex,.sface,_live.ex,_view.ex}",
		"../../../data/current_flavour/config/flavour_assets/components.css",
		// '../../../{extensions,forks,deps}/*/assets/js/**/*.js',
		// '../../../deps/live_select/lib/live_select/component.*ex', // what should this point to?
		// './js/*.js'
	],
	theme: {
		extend: {
			transitionTimingFunction: {
				"ease-in-quad": "cubic-bezier(.55, .085, .68, .53)",
				"ease-in-cubic": "cubic-bezier(.550, .055, .675, .19)",
				"ease-in-quart": "cubic-bezier(.895, .03, .685, .22)",
				"ease-in-quint": "cubic-bezier(.755, .05, .855, .06)",
				"ease-in-expo": "cubic-bezier(.95, .05, .795, .035)",
				"ease-in-circ": "cubic-bezier(.6, .04, .98, .335)",
				"ease-out-quad": "cubic-bezier(.25, .46, .45, .94)",
				"ease-out-cubic": "cubic-bezier(.215, .61, .355, 1)",
				"ease-out-quart": "cubic-bezier(.165, .84, .44, 1)",
				"ease-out-quint": "cubic-bezier(.23, 1, .32, 1)",
				"ease-out-expo": "cubic-bezier(.19, 1, .22, 1)",
				"ease-out-circ": "cubic-bezier(.075, .82, .165, 1)",
				"ease-in-out-quad": "cubic-bezier(.455, .03, .515, .955)",
				"ease-in-out-cubic": "cubic-bezier(.645, .045, .355, 1)",
				"ease-in-out-quart": "cubic-bezier(.77, 0, .175, 1)",
				"ease-in-out-quint": "cubic-bezier(.86, 0, .07, 1)",
				"ease-in-out-expo": "cubic-bezier(1, 0, 0, 1)",
				"ease-in-out-circ": "cubic-bezier(.785, .135, .15, .86)",
			},
			fontFamily: {
				sans: [
					"OpenDyslexic",
					"Luciole",
					"Inter",
					"Noto Sans",
					"Roboto",
					"system-ui",
					"sans-serif",
				],
			},
			screens: {
				sm: "600px",
				tablet: "920px",
				"tablet-lg": "1200px",
				"desktop-lg": "1448px",
				wide: "1920px",
				"can-hover": { raw: "(hover: hover)" },
				"cannot-hover": { raw: "(hover: none)" },
			},
			maxWidth: {
				600: "600px",
			},
			colors: {
				gray: colors.gray,
				blueGray: colors.slate,
				amber: colors.amber,
				rose: colors.rose,
				orange: colors.orange,
				teal: colors.teal,
				cyan: colors.cyan,
			},
			spacing: {
				72: "18rem",
				84: "21rem",
				90: "22rem",
				96: "26rem",
			},
			// typography: (theme) => ({
			// 	DEFAULT: {
			// 		css: {
			// 			"blockquote p:first-of-type::before": { content: "none" },
			// 			"blockquote p:first-of-type::after": { content: "none" },
			// 			css: {
			// 				h1: {
			// 					margin: 0,
			// 				},
			// 				h2: {
			// 					margin: 0,
			// 				},
			// 				h3: {
			// 					margin: 0,
			// 				},
			// 			},
			// 		},
			// 	},
			// 	sm: {
			// 		css: {
			// 			fontSize: "15px",
			// 			h1: {
			// 				margin: 0,
			// 			},
			// 			h2: {
			// 				margin: 0,
			// 			},
			// 			h3: {
			// 				margin: 0,
			// 			},
			// 			p: {
			// 				margin: 0,
			// 				lineHeight: "20px",
			// 			},
			// 			li: {
			// 				lineHeight: "20px",
			// 			},
			// 		},
			// 	},
			// 	lg: {
			// 		css: {
			// 			h1: {
			// 				margin: 0,
			// 			},
			// 			h2: {
			// 				margin: 0,
			// 			},
			// 			h3: {
			// 				margin: 0,
			// 			},
			// 			p: {
			// 				margin: 0,
			// 				lineHeight: "20px",
			// 			},
			// 			li: {
			// 				lineHeight: "20px",
			// 			},
			// 		},
			// 	},
			// }),
		},
	},
	daisyui: {
		darkTheme: "bonfire",
		themes: true,
		themes: [
			{
				bonfire: {
					...require("daisyui/src/theming/themes")["dracula"],
					primary: "#fde047",
					success: "#00a96e",
					info: "#00b6ff",
					warning: "#ffbe00",
					error: "#ff5861",
					"--rounded-btn": "0.25rem",
				},
				light: {
					...require("daisyui/src/theming/themes")["light"],
					"base-100": "#FAFAFA",
					"--rounded-btn": "0.75rem",
					"primary": "#3B51BB",
				},
			},
			"cupcake",
			"dark",
			"light",
			"bumblebee",
			"emerald",
			"corporate",
			"synthwave",
			"retro",
			"cyberpunk",
			"valentine",
			"halloween",
			"garden",
			"forest",
			"aqua",
			"lofi",
			"pastel",
			"fantasy",
			"wireframe",
			"black",
			"luxury",
			"dracula",
			"cmyk",
			"autumn",
			"business",
			"acid",
			"lemonade",
			"night",
			"coffee",
			"winter",
			"dim",
			"nord",
			"sunset",
		],
	},
	variants: {
		extend: {
			ringWidth: ["hover"],
			divideColor: ["dark"],
			ringColor: ["group-hover", "hover"],
			fontWeight: ["group-hover"],
			borderWidth: ["hover", "focus"],
			typography: ["dark"],
		},
	},
	plugins: [
		// require('@tailwindcss/line-clamp'),
		require("@tailwindcss/typography"),
		require("daisyui"),
		// require('tailwindcss-debug-screens')
	],
};
