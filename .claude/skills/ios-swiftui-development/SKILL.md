# iOS SwiftUI Development Skill

## Stack
- Language: Swift (latest)
- UI framework: SwiftUI (prefer over UIKit unless UIKit is explicitly required)
- Target: iOS (check the project's minimum deployment target before using new APIs)
- Build tool: Xcode (`xcodebuild` CLI or Swift Package Manager `swift build`)

## Key commands
```bash
xcodebuild -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild test -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 16'
swift build        # for SPM packages
swift test         # for SPM packages
```

## SwiftUI conventions
- Prefer value types (`struct`) for views; use `@State`, `@Binding`, `@ObservableObject` / `@Observable` appropriately
- Keep views small and composable — extract sub-views aggressively
- Animations: use `.animation(_:value:)` (explicit) over implicit `.animation(_:)`; prefer `withAnimation` for state-driven transitions
- Gestures: use `DragGesture`, `MagnifyGesture`, `RotateGesture` etc. from SwiftUI; fall back to `UIGestureRecognizer` wrapped in `UIViewRepresentable` only when SwiftUI can't cover the case
- Canvas API: use `Canvas { context, size in ... }` for custom 2D drawing; `GraphicsContext` is the drawing primitive

## Drawing / stroke APIs (relevant for doodle/paint features)
- `Path` for vector shapes; `Path.addCurve`, `addQuadCurve` for smooth curves
- `Canvas` + `GraphicsContext.stroke(_:with:lineWidth:)` for real-time drawing
- For smooth input: collect `CGPoint` samples from `DragGesture.Value`, apply Catmull-Rom or Chaikin curve smoothing before rendering
- Metal / SpriteKit are options for high-performance drawing but add complexity — prefer Canvas unless frame-rate benchmarks demand otherwise

## Testing
- Unit tests: XCTest (`import XCTest`)
- UI tests: XCUITest (Xcode UI Testing target)
- Snapshot tests: consider swift-snapshot-testing if already a dependency
- Do NOT use Playwright — it is a web browser automation tool and has no role in iOS testing

## Code style
- Follow Swift API Design Guidelines (https://swift.org/documentation/api-design-guidelines/)
- `camelCase` for variables/functions, `PascalCase` for types
- Prefer `let` over `var`; avoid force-unwrap (`!`) — use `guard let` or `if let`
- No commented-out code; no `// TODO` left behind in shipped code

## What NOT to do
- Do not use Playwright MCP — it controls a web browser, not an iOS simulator
- Do not add Swift packages without operator approval
- Do not target macOS/tvOS/watchOS unless explicitly in scope