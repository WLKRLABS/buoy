---
version: alpha
name: Buoy Design System
description: Native macOS operator-utility design system for the Buoy CLI-backed dashboard.
colors:
  primary: "#4F6D58"
  on-primary: "#FFFFFF"
  secondary: "#66706C"
  on-secondary: "#FFFFFF"
  tertiary: "#A46E27"
  on-tertiary: "#000000"
  neutral: "#EEF1EF"
  surface: "#F9FBFA"
  surface-elevated: "#F4F7F5"
  table-surface: "#FCFDFC"
  on-surface: "#1C2325"
  outline: "#CAD2CE"
  accent-fill: "#DCE7DC"
  warning: "#6F4A16"
  warning-fill: "#F0E2C6"
  error: "#7D3832"
  on-error: "#FFFFFF"
  error-fill: "#F0D6D2"
  dark-primary: "#A5C191"
  dark-neutral: "#111416"
  dark-surface: "#1B2022"
  dark-surface-elevated: "#202629"
  dark-table-surface: "#15191B"
  dark-on-surface: "#E8ECE9"
  dark-outline: "#2F373A"
typography:
  headline-display:
    fontFamily: "SF Pro Display, -apple-system, BlinkMacSystemFont, system-ui, sans-serif"
    fontSize: 28px
    fontWeight: 700
    lineHeight: 1.16
    letterSpacing: 0em
  headline-section:
    fontFamily: "SF Pro Display, -apple-system, BlinkMacSystemFont, system-ui, sans-serif"
    fontSize: 22px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: 0em
  body-md:
    fontFamily: "SF Pro Text, -apple-system, BlinkMacSystemFont, system-ui, sans-serif"
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: 0em
  body-sm:
    fontFamily: "SF Pro Text, -apple-system, BlinkMacSystemFont, system-ui, sans-serif"
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: 0em
  label-md:
    fontFamily: "SF Pro Text, -apple-system, BlinkMacSystemFont, system-ui, sans-serif"
    fontSize: 13px
    fontWeight: 500
    lineHeight: 18px
    letterSpacing: 0em
  label-mono:
    fontFamily: "SF Mono, ui-monospace, Menlo, monospace"
    fontSize: 11px
    fontWeight: 600
    lineHeight: 14px
    letterSpacing: 0em
  value-mono:
    fontFamily: "SF Mono, ui-monospace, Menlo, monospace"
    fontSize: 24px
    fontWeight: 600
    lineHeight: 30px
    letterSpacing: 0em
  readout-mono:
    fontFamily: "SF Mono, ui-monospace, Menlo, monospace"
    fontSize: 12px
    fontWeight: 400
    lineHeight: 18px
    letterSpacing: 0em
rounded:
  none: 0px
  sm: 4px
  md: 8px
  lg: 12px
  xl: 16px
  full: 9999px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  xxl: 32px
components:
  page-shell:
    backgroundColor: "{colors.neutral}"
    textColor: "{colors.on-surface}"
  page-shell-dark:
    backgroundColor: "{colors.dark-neutral}"
    textColor: "{colors.dark-on-surface}"
  sidebar-shell:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.on-surface}"
    padding: "{spacing.lg}"
  panel-surface:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body-md}"
    rounded: "{rounded.xl}"
    padding: "{spacing.xl}"
  panel-surface-dark:
    backgroundColor: "{colors.dark-surface}"
    textColor: "{colors.dark-on-surface}"
    rounded: "{rounded.xl}"
    padding: "{spacing.xl}"
  card-surface:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.lg}"
    padding: "{spacing.lg}"
  card-surface-dark:
    backgroundColor: "{colors.dark-surface-elevated}"
    textColor: "{colors.dark-on-surface}"
    rounded: "{rounded.lg}"
    padding: "{spacing.lg}"
  table-surface:
    backgroundColor: "{colors.table-surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.readout-mono}"
    rounded: "{rounded.md}"
    padding: "{spacing.sm}"
  table-surface-dark:
    backgroundColor: "{colors.dark-table-surface}"
    textColor: "{colors.dark-on-surface}"
    typography: "{typography.readout-mono}"
    rounded: "{rounded.md}"
    padding: "{spacing.sm}"
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label-md}"
    rounded: "{rounded.md}"
    padding: "8px 14px"
    height: 32px
  button-primary-hover:
    backgroundColor: "{colors.dark-primary}"
    textColor: "{colors.dark-neutral}"
  button-neutral:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.on-surface}"
    typography: "{typography.label-md}"
    rounded: "{rounded.md}"
    padding: "8px 14px"
    height: 32px
  button-restorative:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.error}"
    typography: "{typography.label-md}"
    rounded: "{rounded.md}"
    padding: "8px 14px"
    height: 32px
  status-badge:
    backgroundColor: "{colors.accent-fill}"
    textColor: "{colors.primary}"
    typography: "{typography.label-mono}"
    rounded: "{rounded.full}"
    padding: "4px 8px"
  warning-badge:
    backgroundColor: "{colors.warning-fill}"
    textColor: "{colors.warning}"
    typography: "{typography.label-mono}"
    rounded: "{rounded.full}"
    padding: "4px 8px"
  critical-badge:
    backgroundColor: "{colors.error-fill}"
    textColor: "{colors.error}"
    typography: "{typography.label-mono}"
    rounded: "{rounded.full}"
    padding: "4px 8px"
  metric-value:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.on-surface}"
    typography: "{typography.value-mono}"
    rounded: "{rounded.lg}"
    padding: "{spacing.lg}"
  focus-state:
    backgroundColor: "{colors.accent-fill}"
    textColor: "{colors.on-surface}"
  secondary-chip:
    backgroundColor: "{colors.secondary}"
    textColor: "{colors.on-secondary}"
    typography: "{typography.label-mono}"
    rounded: "{rounded.full}"
    padding: "4px 8px"
  tertiary-chip:
    backgroundColor: "{colors.tertiary}"
    textColor: "{colors.on-tertiary}"
    typography: "{typography.label-mono}"
    rounded: "{rounded.full}"
    padding: "4px 8px"
  error-filled:
    backgroundColor: "{colors.error}"
    textColor: "{colors.on-error}"
    typography: "{typography.label-md}"
    rounded: "{rounded.md}"
    padding: "8px 14px"
  outline-swatch:
    backgroundColor: "{colors.outline}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.sm}"
    size: 12px
  dark-outline-swatch:
    backgroundColor: "{colors.dark-outline}"
    textColor: "{colors.dark-on-surface}"
    rounded: "{rounded.sm}"
    size: 12px
---

## Overview

Buoy is a native macOS operator utility for technical Mac users who need a dependable machine, not a decorative dashboard. The interface should feel calm, exact, and natural to a Mac user while supporting dense inspection tasks.

The product promise is quiet confidence and reversibility. `Overview` is the home screen because daily use starts with "is this Mac okay?" `Power` is the deliberate configuration surface because privileged changes must be staged, reviewed, and applied explicitly. Every section should follow the same hierarchy: status summary first, actions second, exact evidence third.

Buoy should use Apple's Human Interface Guidelines as a design constraint. Native controls, sidebar navigation, split-view behavior, menu commands, keyboard shortcuts, SF Symbols, system typography, accessibility behavior, and standard window conventions are part of the design language rather than incidental implementation details. See `docs/apple-hig-reference.md` for the local HIG source index.

## Colors

The color system is muted green-gray utility chrome with restrained semantic accents. `primary` is a steady operational green used for active state, selected navigation, and safe primary emphasis. `neutral`, `surface`, `surface-elevated`, and `table-surface` separate the window, panels, cards, and dense inspection surfaces without visual drama.

`warning` is amber and should mean elevated attention. `error` is reserved for critical risk or serious restore/destructive affordance text; it should not become a large filled red default for ordinary restoration. Status colors must never be the only meaning. Pair every color state with text such as `Live`, `Cached`, `Partial`, `Warning`, or `Critical`.

Dark mode is a first-class surface with paired dark tokens. Do not invert the palette mechanically; keep surfaces layered, text high contrast, and the operational green legible against dark neutrals.

## Typography

Use Apple system typography only. `headline-display` and `headline-section` use SF Pro Display-style system stacks for section headers. `body-md` and `body-sm` use SF Pro Text-style system stacks for labels, summaries, and operational copy.

Monospaced typography is a product signal, not decoration. Use `label-mono` for section labels, timestamps, compact status chips, and version-like metadata. Use `value-mono` for metric values and `readout-mono` for CLI or raw machine readouts. The app should feel CLI-backed without forcing raw text to dominate the first scan.

## Layout & Spacing

The top-level layout is a fixed native window with a non-collapsing sidebar and a scrollable content region. Keep all seven sections as sidebar peers: `Overview`, `Power`, `System`, `Processes`, `Services`, `Network`, and `Storage`. Do not rename them with branded or clever language.

The content order in every section is summary, action, evidence. Summary cards answer the immediate state question. Controls and filters follow when the user can act. Tables, raw readouts, and exact CLI evidence sit lower so technical users can inspect without making the whole app feel like a log viewer.

Use the existing spacing rhythm as the baseline: 4, 8, 12, 16, 24, and 32 px. Main content should preserve generous outer insets and compact internal spacing. Dense tables are allowed, but only after headings, filters, and summary cards make the page understandable.

## Elevation & Depth

Buoy uses tonal depth and borders more than heavy shadows. Panels, cards, and tables should be separated through surface color, 1 px outlines, dividers, and spacing. This keeps the app close to macOS utility conventions and avoids a web-app card pile.

Use blur and sidebar material only where native AppKit provides it. Do not add decorative glass, glow, gradient blobs, or animated depth. The depth model should help the user understand grouping, not create atmosphere.

## Shapes

Use restrained radii. Tables and compact controls use `rounded.md`; cards and panels use `rounded.lg` or `rounded.xl`; badges and status pills use `rounded.full`. Avoid overusing pill shapes for normal buttons or navigation rows.

Icons should come from SF Symbols when available and align with nearby text weight. The app icon can remain more dimensional and branded, but in-app elements should stay flatter and more utilitarian.

## Components

Primary buttons should indicate the safest forward action in the current view, such as applying an intentional configuration after review. Neutral buttons handle refresh, reveal, and secondary actions. Restorative actions can use error-colored text or tint, but should not look like data-destruction warnings unless they are truly dangerous.

Metric cards lead with a short uppercase label, a large monospaced value, and a plain-language detail line. Status badges use text plus semantic color. Tables need stable row height, useful columns, sorting or filters when the dataset is large, and readable empty/unavailable states.

Storage is an inspection surface, not cleanup automation. It may surface large items and cleanup targets, but it must not pressure deletion or hide permission boundaries. Protected folders and custom scan locations stay opt-in, explicit, and reversible.

Power controls stage intent. Sliders and toggles should not apply privileged changes until the user presses `Apply`. `Turn Off` should make restoration obvious and calm. CLI readouts remain available as the lower inspection layer because the CLI is the source of truth.

## Do's and Don'ts

Do keep Buoy native, calm, precise, and keyboard-friendly.

Do lead each section with a clear state summary before controls or tables.

Do use exact labels, explicit uncertainty, and source-backed status copy.

Do keep light and dark appearances equally designed.

Do use HIG-aligned macOS controls before inventing custom controls.

Don't turn Buoy into a marketing surface inside the app.

Don't hide CLI truth to make the interface look simpler.

Don't use color without text to communicate state.

Don't collapse technical sections into vague buckets.

Don't add decorative motion, gradients, or novelty styling that competes with machine state.
