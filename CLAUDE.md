# Joodle

SwiftUI iOS app for daily doodling (bundle `dev.liyuxuan.joodle`) plus a Widgets
extension. Schemes: `Production` (main app) and `WidgetsExtension`. Unit tests live in
`JoodleTests/` (XCTest), UI tests in `JoodleUITests/` (legacy class names still say
"GoodDay").

## Building & testing — read this before running xcodebuild

**Never run `xcodebuild` as a blocking foreground command.** Agent turns are hard-killed
(SIGTERM) after 15 minutes, and a cold `xcodebuild build`/`test` regularly exceeds that —
this has burned entire task budgets. Always run it in the background and poll the log:

```bash
xcodebuild -scheme Production \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build > /tmp/joodle-build.log 2>&1 &
# then poll: tail -5 /tmp/joodle-build.log / grep -E "BUILD (SUCCEEDED|FAILED)"
```

(With the Bash tool, prefer `run_in_background: true` over `&`.)

More rules that keep builds inside budget:

- **Scope test runs** with `-only-testing:JoodleTests/<TestClass>` — never run the full
  suite when you only touched one area.
- **Reuse the warm build**: after a successful `build`, prefer installing the app from
  DerivedData (`xcrun simctl install`) over rebuilding; `test` reuses build products too.
- The `Production` scheme's TestAction runs `JoodleTests` (fixed 2026-07-20 — it used to
  be unconfigured and `xcodebuild test -scheme Production` errored with "not currently
  configured for the test action"). `JoodleUITests` is deliberately not in the scheme:
  UI tests are too slow for agent turns; run them only if explicitly asked, via
  `-only-testing:JoodleUITests/...`.
- Cheap first line of defense for pure syntax issues:
  `find . -name '*.swift' -not -path './.git/*' -print0 | xargs -0 swiftc -parse`
  (this is also the LAIOS verify gate).

## Environment

- This machine has Xcode (beta) and an iOS simulator (iPhone 17). Check the booted
  device with `xcrun simctl list devices booted` before hardcoding a destination.
- UI verification: use the argent MCP tools (screenshots, gestures, UI queries) against
  the booted simulator — see `.claude/rules/argent.md` and `.agents/skills/argent-*`.

## Conventions

- Every user-facing string goes through `Localizable.xcstrings` (main app AND
  `Widgets/Localizable.xcstrings`) — see `LOCALIZATION.md`. Never hardcode UI strings.
- SwiftUI-first; no new third-party dependencies.
- Widgets share data with the app via WidgetDataManager / app group — keep model changes
  in sync on both sides.
- Never commit `Secrets.xcconfig` (seeded, gitignored — don't `git add -A` it back in).
