Self-hosted fonts. Ship woff2 only (every supported browser has it since 2016),
and only the weights Bonfire uses: 400, 500 and 700 (see the type scale in
`assets/css/app.css`). Variable fonts cover all weights in one file.

To add a font:
- put the woff2 files (and the licence) in `assets/static/fonts`
- create `assets/static/fonts/<slug>.css` with its `@font-face` rules; the slug comes from
  the setting label, e.g. "Inter (Latin Languages)" → `inter-latin.css`
- add the label to `font_families` in `config/bonfire_ui_common.exs`
- add its critical (regular, Latin) file to `@critical_font_files` in
  `lib/themes/font_helper.ex` so it is preloaded
