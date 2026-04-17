# Accessibility

## Audience

Users and maintainers reviewing the current accessibility posture of the app.

## Purpose

Record what the source proves today and separate that from work that still needs explicit validation.

## Scope Of This Document

This is not a completed accessibility audit.

It is a source-based accessibility reference that notes:

- what the current implementation already does
- what still needs direct product testing

## What The Current Source Proves

### Keyboard Access

The app exposes keyboard shortcuts for section navigation:

- `Cmd+1` through `Cmd+7`
- `Cmd+[`
- `Cmd+]`
- `Cmd+W`
- `Cmd+Q`

The interface also uses standard AppKit controls such as:

- checkboxes
- sliders
- popup buttons
- tables
- buttons

### Text Labels Instead Of Color Only

The app uses explicit text for:

- mode state
- power source
- battery state
- storage state labels such as `Cached`, `Live`, `Partial Scan`, and `Deep Scan Running`

### Appearance Support

The app exposes:

- `System`
- `Light`
- `Dark`

This helps users stay aligned with their system appearance preference.

### Readable Dense Views

The app uses monospaced text in places where scanability matters:

- CLI readout in `Power`
- raw machine readout in `System`
- timestamps and summary labels in several sections

## What Still Needs Explicit Testing

- `[TBD — requires product/source confirmation]` VoiceOver behavior across all sections
- `[TBD — requires product/source confirmation]` keyboard focus order audit across the whole window
- `[TBD — requires product/source confirmation]` measured contrast audit against WCAG targets
- `[TBD — requires product/source confirmation]` large-text and zoom behavior review
- `[TBD — requires product/source confirmation]` reduced-transparency and increased-contrast behavior review

## Known Accessibility Risks

- the app is dense, especially in `System`, `Processes`, `Services`, `Network`, and `Storage`
- the Storage section relies on wide tables and dense filtering controls
- some values can be unavailable, which makes clear fallback copy important

## Recommendations

High-value next checks:

1. Run a full VoiceOver pass across every sidebar section.
2. Validate keyboard-only operation for the Power and Storage flows.
3. Measure color contrast in both Light and Dark appearance modes.
4. Test larger text settings against the densest tables and cards.

## See Also

- [Interface Tour](interface-tour.md)
- [Privacy And Permissions](privacy-and-permissions.md)
- [Developer Architecture](developer/architecture.md)
