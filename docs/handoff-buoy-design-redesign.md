# Handoff

## Goal

Redesign `Buoy.app` so the native AppKit dashboard follows the newly agreed Buoy design system while preserving the CLI-first power contract and existing product scope.

## State

- `DESIGN.md` now exists and is the normative design-system source of truth.
- `DESIGN.html` now exists as the required static visual audit artifact.
- `docs/apple-hig-reference.md` now exists as a local Apple Human Interface Guidelines source index and Buoy-specific application note.
- `npx @google/design.md lint DESIGN.md` passed with 0 errors and 0 warnings after token contrast cleanup.
- `DESIGN.html` was opened with Playwright screenshots for desktop light, desktop dark, and mobile light.
- Existing dirty files before this handoff/design pass: `README.md` and `CHANGELOG.md`. Do not assume those changes belong to the redesign work.

## Decisions

- Buoy is a native macOS operator utility for technical Mac users, not a branded web dashboard or consumer toy.
- Great UX still matters: the app should feel obvious, natural, and Apple-adjacent despite being dense.
- The app promise is quiet confidence and reversibility.
- `Overview` is the home screen and daily-use entry point.
- `Power` is the deliberate configuration surface for staged privileged changes.
- Every section should follow summary first, actions second, exact evidence third.
- Keep all seven sidebar sections as top-level peers: `Overview`, `Power`, `System`, `Processes`, `Services`, `Network`, `Storage`.
- Use plain system-domain section names, not clever branded navigation labels.
- Use SF system typography and SF Symbols; keep monospaced readouts for CLI and machine truth.
- Use muted green-gray utility chrome with amber warning and red critical accents.
- Storage must remain inspection/review oriented, not cleanup automation.
- Color must support text state, not replace it.

## References

- `DESIGN.md` - token source of truth and design rationale.
- `DESIGN.html` - static visual audit for colors, type, surfaces, radius, and light/dark behavior.
- `docs/apple-hig-reference.md` - Apple HIG links and Buoy-specific application notes.
- `Sources/BuoyApp/Dashboard/DashboardUIComponents.swift` - current shared AppKit colors, spacing, cards, tables, and layout primitives.
- `Sources/BuoyApp/Dashboard/BuoyMainViewController.swift` - current sidebar, split-view, section host, and top-level navigation.
- `Sources/BuoyApp/main.swift` - window setup and Power section controls.
- `docs/interface-tour.md` - current app section structure and user-facing controls.
- `docs/accessibility.md` - current source-backed accessibility posture and known risks.
- `docs/developer/build-and-run.md` - build/run commands and local validation path.

## Blockers / Unknowns

- The actual native app has not been redesigned yet; only the design source files and handoff are prepared.
- No final visual sign-off has been given for the redesign.
- A live `Buoy.app` screenshot capture attempt with `screencapture` failed earlier with `could not create image from display`; use another runtime verification path if needed.
- VoiceOver, keyboard focus order, large text, and measured contrast inside the actual AppKit UI still need explicit testing after implementation.
- `README.md` and `CHANGELOG.md` are dirty from pre-existing work; preserve or isolate them unless the user explicitly says otherwise.

## Next Actions

1. Read `DESIGN.md`, `docs/apple-hig-reference.md`, and `docs/interface-tour.md`.
2. Audit current AppKit UI tokens in `DashboardUIComponents.swift`, `BuoyMainViewController.swift`, and `main.swift` against `DESIGN.md`.
3. Implement the smallest coherent redesign slice first: shared chrome, sidebar, section header, cards, tables, buttons, and status badges.
4. Preserve CLI behavior and power-state logic; do not change `BuoyCore` or CLI command behavior unless a UI issue proves it necessary.
5. Validate with repo scripts, at minimum `./scripts/build-app.sh`, `./scripts/smoke-test.sh` if safe for the current machine, and `npx @google/design.md lint DESIGN.md` if design tokens change.
6. Open the built app and verify light/dark appearance, sidebar navigation, resize behavior, and dense table readability.
7. Update `CHANGELOG.md` under `## [Unreleased]` only when user-visible app redesign changes are actually implemented.

## Suggested Skills

- `design-refine` - use only if design decisions need to be reopened or `DESIGN.md` / `DESIGN.html` must change.
- `agency-frontend-developer` - useful for a focused UI implementation pass.
- `agency-accessibility-auditor` - useful after implementation for keyboard, VoiceOver, focus, contrast, and large-text review.
