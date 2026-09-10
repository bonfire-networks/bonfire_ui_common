# Bonfire UI styling notes

## Interface presets

Stream is the built-in interface default. It also renders when `data-ui-preset` is absent or a saved preset is invalid. User and account preferences still take precedence over instance settings; an explicit instance or flavour setting such as Jacobin's `ui_preset: "typographic"` remains in effect.

- Templates own straightforward default layout and appearance through Tailwind classes. Reusable components accept class props when their callers need different layouts.
- `assets/css/app.css` owns shared tokens, reusable component behaviour, and cross-component rules such as connector geometry.
- `assets/css/interface.css` owns the default component presentation. Its root selector excludes explicit Typographic while preserving the former Stream selector's specificity.
- `assets/css/ui_presets/typographic.css` owns client layout differences, including card bleed, toolbar overlap, widget user frames, profile borders and banner proportions, thread frames and comment insets, and nested reply gutters and connectors.

The remaining interface rules deliberately opt out for Typographic: they still build on shared component utilities. When refactoring a component, put straightforward default styling in its template and keep only the alternative presentation in Typographic. Keep presentation overrides unlayered so they take precedence over Tailwind's utilities without `!important`. Do not add preset checks or client-specific border-overlap utilities to templates.

Word wrapping and tabular timestamps are shared improvements. Compact customization rows apply only to mouse devices without a coarse pointer; touch and hybrid devices retain the shared 44px minimum.

In development, use `?ui_preset=stream` or `?ui_preset=typographic` to preview either layout without saving a preference. Preview parameters are ignored outside development.

Themes control button shape through `--radius-button`. The default interface supplies a 4px fallback; Typographic retains the shared 10px fallback. A theme can set `--radius-button: 9999px` for pill-shaped text buttons. Circular and square icon controls retain their own geometry.
