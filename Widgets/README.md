# GoodDay Year Grid Widget

This widget displays a year-at-a-glance grid showing all 365 days of the current year, with visual indicators for past days, present day, future days, and days with entries.

## Features

- **Year Display**: Shows the current year (e.g., "2025")
- **Progress Percentage**: Displays how much of the year has passed (e.g., "83.8%")
- **365-Day Grid**: Visual representation of every day in the year
  - **Past days**: Filled dots (black/white depending on theme)
  - **Today**: Highlighted with AppPrimary color (orange)
  - **Future days**: Light gray dots at 15% opacity
  - **Days with entries**: Dot with a ring around it (applies to both text and drawing entries)
- **Auto-updates**: Refreshes at midnight each day
- **Size Support**: Medium and Large widget sizes

## Setup Instructions

### 1. Configure App Groups (Required for Data Sharing)

To share entry data between the main app and the widget, you need to set up App Groups:

#### Step 1: Enable App Groups for Main App

1. In Xcode, select the **GoodDay** project
2. Select the **GoodDay** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** and add **App Groups**
5. Click **+** to add a new group
6. Enter: `group.com.yourcompany.GoodDay` (replace `yourcompany` with your actual team/company identifier)
7. Check the checkbox to enable it

#### Step 2: Enable App Groups for Widget

1. Select the **Widgets** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability** and add **App Groups**
4. Select the **same** group identifier: `group.com.yourcompany.GoodDay`
5. Check the checkbox to enable it

#### Step 3: Update App Group Identifier in Code

Update the `appGroupIdentifier` in both files to match your App Group:

**In `Widgets/WidgetDataManager.swift`:**

```swift
private let appGroupIdentifier = "group.com.yourcompany.GoodDay" // Update this
```

**In `GoodDay/Utils/WidgetHelper.swift`:**

```swift
private let appGroupIdentifier = "group.com.yourcompany.GoodDay" // Update this
```

### 2. Integrate Widget Updates in Main App

To sync entry data to the widget, call `WidgetHelper` whenever entries are created, updated, or deleted:

#### Example Integration

Add this code wherever you manage your `DayEntry` data (likely in a view model or data manager):

```swift
import WidgetKit

// After saving/updating entries
func saveEntry(_ entry: DayEntry) {
    // Your existing save logic...

    // Update widget data
    let allEntries = fetchAllEntries() // Get all entries from SwiftData
    WidgetHelper.shared.updateWidgetData(with: allEntries)
}

// After deleting an entry
func deleteEntry(_ entry: DayEntry) {
    // Your existing delete logic...

    // Update widget data
    let allEntries = fetchAllEntries() // Get remaining entries
    WidgetHelper.shared.updateWidgetData(with: allEntries)
}

// When app becomes active (to ensure widget is in sync)
func refreshWidgetData() {
    let allEntries = fetchAllEntries()
    WidgetHelper.shared.updateWidgetData(with: allEntries)
}
```

#### Example: Update on App Launch

In your main app file or root view, add:

```swift
import SwiftUI
import SwiftData

@main
struct GoodDayApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Sync widget data when app launches
                    refreshWidgetData()
                }
        }
    }

    private func refreshWidgetData() {
        // Fetch entries from SwiftData and update widget
        // This is just an example - adjust based on your data access pattern
    }
}
```

### 3. Build and Test

1. **Build the widget**: Select the **Widgets** scheme and run on a device or simulator
2. **Add the widget**: Long-press on the home screen → tap **+** → search for "GoodDay" → add "Year Progress"
3. **Test updates**:
   - Create a text or drawing entry in the main app
   - The widget should update to show a ring around the corresponding day's dot

## Widget Sizes

### Medium Widget

- Compact layout with smaller dots (4.5pt)
- Tighter spacing (3pt)
- Good for quick glance at year progress

### Large Widget

- Larger dots (6pt) for better visibility
- More spacing (4pt)
- Better for detailed view of the year

## Customization

You can customize the widget appearance in `YearGridWidget.swift`:

```swift
// Adjust dot sizes
private var dotSize: CGFloat {
    widgetFamily == .systemMedium ? 4.5 : 6.0  // Change these values
}

// Adjust spacing between dots
private var dotsSpacing: CGFloat {
    widgetFamily == .systemMedium ? 3.0 : 4.0  // Change these values
}

// Adjust dots per row (default is 31 to show ~12 rows for 365 days)
private var dotsPerRow: Int {
    widgetFamily == .systemMedium ? 31 : 31    // Change to adjust layout
}
```

## Troubleshooting

### Widget Shows No Data

**Problem**: Widget displays but shows no entry indicators (rings)

**Solutions**:

1. Verify App Groups are configured correctly in both targets
2. Check that the `appGroupIdentifier` matches in both `WidgetDataManager.swift` and `WidgetHelper.swift`
3. Ensure you're calling `WidgetHelper.shared.updateWidgetData(with: entries)` after creating entries
4. Check the console for error messages about UserDefaults access

### Widget Doesn't Update

**Problem**: Changes in the app don't reflect in the widget

**Solutions**:

1. Ensure `WidgetCenter.shared.reloadAllTimelines()` is called after data changes
2. Check that entries are being saved to the shared UserDefaults container
3. Force refresh the widget: Long-press widget → Edit Widget → Done
4. Check that the timeline policy is set to update at midnight

### Widget Shows Wrong Year Progress

**Problem**: Percentage doesn't match actual year progress

**Solutions**:

1. This auto-calculates based on current date
2. If incorrect, check device date/time settings
3. Widget updates at midnight - wait until then for accurate percentage

### Colors Don't Match App

**Problem**: Widget colors look different from main app

**Solutions**:

1. Ensure `AppPrimary.colorset` is properly copied to `Widgets/Assets.xcassets/`
2. Verify the color set has both light and dark mode variants
3. Check that you're using `Color("AppPrimary")` not hardcoded colors

## Architecture

### Data Flow

```
Main App (GoodDay)
    ↓
WidgetHelper.updateWidgetData()
    ↓
Encode entries → UserDefaults (App Group)
    ↓
WidgetCenter.reloadAllTimelines()
    ↓
Widget (Widgets target)
    ↓
WidgetDataManager.loadEntries()
    ↓
Decode entries ← UserDefaults (App Group)
    ↓
YearGridWidget displays data
```

### Files

- **YearGridWidget.swift**: Main widget implementation
  - `YearGridProvider`: Provides timeline entries
  - `YearGridWidgetView`: Widget UI
  - `WidgetDotView`: Displays individual day dots with ring for entries

- **WidgetDataManager.swift**: Manages data sharing with main app
  - Encodes/decodes entry data
  - Reads/writes to shared UserDefaults

- **WidgetHelper.swift** (in main app): Updates widget from app
  - Converts SwiftData entries to widget format
  - Triggers widget refresh
    </text>

<old_text line=234>

## Performance Notes

- Widget uses simplified rendering for performance
- Drawing entries shown with a ring indicator (not actual canvas rendering)
- Timeline updates only at midnight to conserve battery
- Entry data cached in UserDefaults for fast widget loads

## Memory Optimization (30MB Limit)

Widgets have a strict **30MB memory limit**. The widget has been optimized to stay under this limit:

### Optimizations Applied

1. **No Drawing Data**: Drawing canvas data is NOT loaded into the widget (only the flag `hasDrawing`)
2. **Current Year Only**: Only entries from the current year are loaded
3. **Minimal Data Structure**: Only stores date, hasText, and hasDrawing (no large blobs)
4. **Lazy Rendering**: Uses `LazyVStack` to avoid rendering off-screen rows
5. **Limited Rows**: Maximum 12 rows rendered at once

### If You Still Hit Memory Limits

If the widget crashes with `EXC_RESOURCE` errors:

1. **Reduce entries sent**: In `WidgetHelper.swift`, only send recent entries:

   ```swift
   // Only send last 365 days of entries
   let recentEntries = entries.filter { entry in
       entry.createdAt > Date().addingTimeInterval(-365 * 24 * 60 * 60)
   }
   WidgetHelper.shared.updateWidgetData(with: recentEntries)
   ```

2. **Reduce dot size**: Smaller dots = less memory

   ```swift
   private var dotSize: CGFloat {
       widgetFamily == .systemMedium ? 3.0 : 4.5  // Smaller dots
   }
   ```

3. **Fewer dots per row**: Less dots on screen = less memory
   ```swift
   private var dotsPerRow: Int {
       widgetFamily == .systemMedium ? 20 : 25  // Fewer dots
   }
   ```

## Future Enhancements

Possible improvements:

- Interactive widget (tap dot to open app to that day)
- Configurable widget (choose year, color scheme)
- Different grid layouts (weeks, months)
- Statistics (total entries, streaks)
