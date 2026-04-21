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

- VoiceOver behavior is not covered by an automated suite and should be treated as unverified beyond standard AppKit control semantics.
- Full keyboard focus-order validation is still a manual release check, especially in `Power` and `Storage`.
- Color contrast is not measured in CI and this document does not claim WCAG ratio certification.
- Large-text and zoom behavior are not formally certified across the densest tables and cards.
- Reduced-transparency and increased-contrast behavior are not explicitly tuned beyond inherited AppKit behavior in the current repo.

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
