# Handoff Prompt

Use this prompt to start the next implementation session.

```text
You are working in /Users/shanewalker/Desktop/dev/buoy.

Goal: redesign Buoy.app's native AppKit dashboard to follow the new Buoy design system without changing CLI behavior, power-state logic, release versioning, or product scope.

Read first:
- AGENTS.md repo instructions from the conversation or workspace context.
- DESIGN.md
- DESIGN.html
- docs/apple-hig-reference.md
- docs/handoff-buoy-design-redesign.md
- docs/interface-tour.md
- docs/accessibility.md
- docs/developer/build-and-run.md

Current design contract:
- Buoy is a native macOS operator utility for technical Mac users.
- The UX must feel common-sense, Apple-adjacent, calm, exact, and reversible.
- Overview is the home screen.
- Power is the deliberate configuration surface.
- Every section should follow summary first, actions second, exact evidence third.
- Keep sidebar sections as top-level peers: Overview, Power, System, Processes, Services, Network, Storage.
- Use SF system typography, SF Symbols, muted green-gray chrome, amber warning, red critical accents, text plus color for status, and monospaced readouts for machine truth.
- Storage is inspection/review, not cleanup automation.
- Use Apple HIG as a constraint, via docs/apple-hig-reference.md.

Implementation constraints:
- Do not alter BuoyCore or CLI command behavior unless a UI issue proves it necessary.
- Do not bump VERSION.
- Preserve unrelated dirty changes, especially pre-existing README.md and CHANGELOG.md edits.
- Use repo scripts for validation, not ad hoc swiftc commands.
- Update CHANGELOG.md under Unreleased only after actual user-visible app changes are implemented.

Recommended first slice:
1. Audit Sources/BuoyApp/Dashboard/DashboardUIComponents.swift, Sources/BuoyApp/Dashboard/BuoyMainViewController.swift, and Sources/BuoyApp/main.swift against DESIGN.md.
2. Refactor shared chrome/tokens first so sections inherit the redesign consistently.
3. Then improve sidebar, section header, cards, tables, buttons, status badges, and exact readout areas.
4. Keep section content order and behavior intact unless the design contract requires a small hierarchy adjustment.
5. Build with ./scripts/build-app.sh.
6. Run safe smoke validation and open the built app for light/dark, resize, navigation, and dense table checks.

Do not claim pixel-perfect approval or final accessibility certification. Report what was implemented, what was verified, and what remains open.
```
