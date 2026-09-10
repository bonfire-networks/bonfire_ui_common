import { readFileSync } from "node:fs";

const appSource = readFileSync(new URL("../css/app.css", import.meta.url), "utf8");
const flavourSource = readFileSync(
	new URL("../css/current_flavour_theme.css", import.meta.url),
	"utf8",
);
const builtCss = readFileSync(
	new URL("../../../../priv/static/assets/bonfire_basic.css", import.meta.url),
	"utf8",
);

if (!/@plugin\s+"daisyui"\s*\{[^}]*\bthemes:\s*false\s*;/s.test(appSource)) {
	throw new Error("DaisyUI built-in themes must remain disabled with `themes: false`");
}

const sourceThemeNames = (source) =>
	new Set(
		[...source.matchAll(/@plugin\s+"daisyui\/theme"\s*\{[^}]*\bname:\s*"([^"]+)"/gs)].map(
			([, name]) => name,
		),
	);

const expected = new Set([
	...sourceThemeNames(appSource),
	...sourceThemeNames(flavourSource),
]);
const actual = new Set(
	[...builtCss.matchAll(/\[data-theme\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s\]]+))\s*\]/g)].map(
		([, doubleQuoted, singleQuoted, unquoted]) => doubleQuoted ?? singleQuoted ?? unquoted,
	),
);

const sorted = (values) => [...values].sort();
const missing = sorted([...expected].filter((name) => !actual.has(name)));
const unexpected = sorted([...actual].filter((name) => !expected.has(name)));

if (missing.length > 0 || unexpected.length > 0) {
	throw new Error(
		`Compiled theme mismatch. Missing: ${missing.join(", ") || "none"}. Unexpected: ${unexpected.join(", ") || "none"}.`,
	);
}

console.log(`Theme contract verified: ${sorted(actual).join(", ")}`);
