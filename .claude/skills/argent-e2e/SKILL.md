# Argent — SwiftUI simulator E2E testing

Argent (@swmansion/argent) is wired into your session as the `argent` MCP server
(`mcp__argent__*` tools). It drives the iOS Simulator for end-to-end verification of
SwiftUI apps: build/install/launch the app, interact with the UI (tap, type, scroll),
and capture screenshots.

## When to use
- After implementing a UI change in a SwiftUI project, when a simulator runtime is
  available on this machine: launch the app and verify the change visually.
- Persist proof screenshots to `.orchestrator/artefacts/screenshots/` in your worktree —
  they surface in the dashboard's ARTEFACTS pane for the operator.

## How
- Discover the available tools first (they are versioned): list your `mcp__argent__*`
  tools, or run `argent tools` in the shell for descriptions.
- Prefer one clean end-to-end pass (launch → navigate → assert/screenshot) over many
  partial runs; simulator boots are slow.

## Caveats
- Simulator availability depends on the host having an Xcode/simulator runtime. If boot
  or build tools are missing, note it in the scratchpad and fall back to the project's
  syntax gate + code-level reasoning — do NOT spin retrying.
