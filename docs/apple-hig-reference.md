# Apple HIG reference for Buoy design

Fetched: 2026-05-26

This is a local working index for applying Apple's Human Interface Guidelines to Buoy. It is not a copy of Apple's guidelines. Use the linked Apple Developer pages as the authority and keep Buoy-specific decisions in `DESIGN.md`.

## Official sources

- Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines
- Designing for macOS: https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
- Windows: https://developer.apple.com/design/human-interface-guidelines/windows
- Sidebars: https://developer.apple.com/design/human-interface-guidelines/sidebars
- Split views: https://developer.apple.com/design/human-interface-guidelines/split-views
- Toolbars: https://developer.apple.com/design/human-interface-guidelines/toolbars
- Buttons: https://developer.apple.com/design/human-interface-guidelines/buttons
- Typography: https://developer.apple.com/design/human-interface-guidelines/typography
- Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Offering help: https://developer.apple.com/design/human-interface-guidelines/offering-help
- SF Symbols: https://developer.apple.com/design/human-interface-guidelines/sf-symbols

## Buoy application notes

- Keep the app recognizably macOS-native: standard window behavior, AppKit controls, system typography, SF Symbols, menu commands, keyboard shortcuts, and normal resize behavior.
- Treat the sidebar as top-level navigation for peer sections. Keep labels short, use familiar symbols, and avoid burying critical actions at the bottom of the sidebar.
- Use split-view behavior and responsive collapse rules to keep the dashboard usable at narrower window sizes without making the main content feel cramped.
- Reserve visually prominent button treatment for the primary safe action in a view. Do not make destructive or restorative actions look like the default just because they are important.
- Preserve information density through hierarchy, not clutter: summary first, exact tables and monospaced readouts lower in the view.
- Use help sparingly. If a control needs a long explanation, simplify the control or its label before adding explanatory copy.
- Respect accessibility as a design input: keyboard paths, visible focus, readable contrast in light and dark modes, VoiceOver labels, and larger text behavior need explicit review.
- Use color as semantic support, not the only source of meaning. Buoy status states need text labels plus color.
- Use SF Symbols for interface glyphs and align their weight with nearby text.
- Keep design language calm and operational. Buoy can be dense and technical, but it should still feel obvious, stable, and natural to a Mac user.
