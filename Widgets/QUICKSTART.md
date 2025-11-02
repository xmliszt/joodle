# Year Grid Widget - Quick Start Guide

## What You'll Get

A beautiful iOS widget showing all 365 days of the year in a grid format, with visual indicators for:
- **Past days**: Filled black/white dots
- **Today**: Orange highlighted dot
- **Future days**: Light gray dots
- **Days with text entries**: Dots with rings around them
- **Days with drawings**: Rounded rectangles instead of circles
- **Year progress**: Shows current year and percentage complete (e.g., "2025  83.8%")

## 5-Minute Setup

### 1. Configure App Groups (3 minutes)

#### Main App Target
1. In Xcode, select **GoodDay** project → **GoodDay** target
2. **Signing & Capabilities** tab → **+ Capability** → **App Groups**
3. Click **+** and enter: `group.com.YOURTEAM.GoodDay`
   - Replace `YOURTEAM` with your actual team identifier
4. ✅ Check the checkbox to enable it

#### Widget Target
1. Select **GoodDay** project → **Widgets** target
2. **Signing & Capabilities** tab → **+ Capability** → **App Groups**
3. Select the **same** group: `group.com.YOURTEAM.GoodDay`
4. ✅ Check the checkbox to enable it

### 2. Update App Group Identifier in Code (1 minute)

Update **TWO** files with your App Group ID:

**File 1: `Widgets/WidgetDataManager.swift` (line 29)**
```swift
private let appGroupIdentifier = "group.com.YOURTEAM.GoodDay"  // ← Update this
```

**File 2: `GoodDay/Utils/WidgetHelper.swift` (line 15)**
```swift
private let appGroupIdentifier = "group.com.YOURTEAM.GoodDay"  // ← Update this
```

### 3. Add One Line of Code (1 minute)

Find where you **save** entries in your app and add this line:

```swift
// After saving an entry to SwiftData
try modelContext.save()

// Add this line:
WidgetHelper.shared.updateWidgetData(with: allYourEntries)
```

**Don't know where to add it?** See the examples below.

## Testing

1. **Build & Run** the app on a device or simulator
2. **Add the widget**:
   - Long-press home screen
   - Tap **+** button
   - Search "GoodDay"
   - Add "Year Progress" widget (Medium or Large)
3. **Test it**:
   - Create an entry in the app
   - Widget should show a ring around today's dot
   - Create a drawing
   - Dot should become a rounded rectangle

## Integration Examples

### Example A: If You Have a Save Function

```swift
func saveEntry(body: String, date: Date, drawingData: Data?) {
  let entry = DayEntry(body: body, createdAt: date, drawingData: drawingData)
  modelContext.insert(entry)
  try? modelContext.save()

  // Add these 2 lines:
  let allEntries = try? modelContext.fetch(FetchDescriptor<DayEntry>())
  WidgetHelper.shared.updateWidgetData(with: allEntries ?? [])
}
```

### Example B: Update When App Opens

Add to your `ContentView` or main view:

```swift
struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    YourMainView()
      .onChange(of: scenePhase) { _, newPhase in
        if newPhase == .active {
          refreshWidget()
        }
      }
  }

  private func refreshWidget() {
    let entries = try? modelContext.fetch(FetchDescriptor<DayEntry>())
    WidgetHelper.shared.updateWidgetData(with: entries ?? [])
  }
}
```

### Example C: Update After Delete

```swift
func deleteEntry(_ entry: DayEntry) {
  modelContext.delete(entry)
  try? modelContext.save()

  // Add these 2 lines:
  let remainingEntries = try? modelContext.fetch(FetchDescriptor<DayEntry>())
  WidgetHelper.shared.updateWidgetData(with: remainingEntries ?? [])
}
```

## Common Issues

### ❌ Widget shows no entry indicators (no rings/drawings)
**Fix**: App Group identifiers don't match
- Check both targets have the same group ID
- Check code has the same group ID string

### ❌ Widget doesn't update when I create entries
**Fix**: Not calling `WidgetHelper.shared.updateWidgetData()`
- Add the update call after saving entries
- See examples above

### ❌ "Failed to access shared UserDefaults" in console
**Fix**: App Groups not configured
- Make sure you added App Groups capability to BOTH targets
- The group identifier must be identical in both

## Customization

Want different dot sizes or spacing? Edit `YearGridWidget.swift`:

```swift
// Around line 104-115
private var dotSize: CGFloat {
  widgetFamily == .systemMedium ? 4.5 : 6.0  // ← Change these
}

private var dotsSpacing: CGFloat {
  widgetFamily == .systemMedium ? 3.0 : 4.0  // ← Change these
}

private var dotsPerRow: Int {
  widgetFamily == .systemMedium ? 31 : 31    // ← Change layout
}
```

## Widget Sizes

- **Medium**: Compact, smaller dots (4.5pt), tight spacing
- **Large**: Roomier, bigger dots (6pt), more spacing

## Need Help?

See detailed documentation in:
- `Widgets/README.md` - Full documentation
- `Widgets/INTEGRATION_EXAMPLE.md` - Code examples

## That's It! 🎉

Your widget should now be working and syncing with your entries!
