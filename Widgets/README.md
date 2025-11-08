# GoodDay Widgets

This document covers all available widgets for the GoodDay app.

## Available Widgets

1. **Year Grid Widget** - Year-at-a-glance calendar grid
2. **Random Doodle Widget** - Random doodle from the past year
3. **Anniversary Widget** - Future anniversary countdown (NEW)

---

# Year Grid Widget

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

---

# Anniversary Widget

This widget displays future anniversaries with countdown timers, helping you track upcoming special dates and events.

## Features

- **Future Anniversary Display**: Shows entries with dates in the future
- **Countdown Timer**: Real-time countdown in human-readable format (years, months, days, hours, minutes, seconds)
- **Configurable**: Choose a specific date or use stable random selection
- **Doodle Support**: Displays doodles from anniversary entries
- **Text Support**: Shows text notes from anniversary entries
- **Three Sizes**: systemSmall, systemMedium, and systemLarge
- **Deep Linking**: Tap widget to open the app to that specific date
- **Smart Updates**: Updates frequency adjusts based on time remaining (minute-level for same-day, daily for longer countdowns)

## Widget Sizes

### Small Widget (systemSmall)

**Square layout with:**

- Center: Doodle (if available) OR text note (if no doodle)
- Bottom: Countdown text (e.g., "in 7 days")
- No date display (limited space)

**Behavior:**

- If entry has doodle → shows doodle + countdown
- If entry has text only → shows text + countdown
- Tap widget → opens app to anniversary date

### Medium Widget (systemMedium)

**Horizontal layout with:**

- Top left: Anniversary date (e.g., "Dec 25, 2025")
- Top right: Countdown text
- Left half: Doodle or placeholder
- Right half: Text note or placeholder

**Behavior:**

- Shows both doodle and text sections
- Displays "No doodle" or "No notes" placeholders when missing
- More informative than small widget

### Large Widget (systemLarge)

**Square layout with:**

- Center: Doodle (if available) OR text note (if no doodle)
- Bottom: Countdown text (larger font)
- Similar to small widget but with more space for content

**Behavior:**

- Larger doodle rendering (24pt padding vs 12pt)
- More text lines visible (10 vs 5)
- Larger countdown font (.callout vs .caption)

## Configuration

The widget supports two modes:

### 1. Random Selection (Default)

When no specific date is configured:

- Filters all future entries with text or doodles
- Uses "stable randomness" based on current day
- Same anniversary shown all day (changes at midnight)
- Selection algorithm: `daysSince1970 % futureEntries.count`

### 2. Specific Date Selection

User can configure widget to show a specific anniversary:

1. Long-press widget → **Edit Widget**
2. Tap **Specific Date** parameter
3. Choose a date from the calendar
4. Widget will show that date's anniversary (if it exists)

## Countdown Format

The countdown adapts based on time remaining:

**More than 1 year:**

```
in 2 years, 3 months, 15 days
```

**More than 1 month (less than 1 year):**

```
in 3 months, 15 days
```

**More than 1 day:**

```
in 15 days
```

**Less than 1 day (same day):**

```
in 5h 23m 45s
```

**Imminent:**

```
now
```

## Setup Instructions

### Prerequisites

Anniversary Widget shares the same App Group setup as Year Grid Widget. Ensure App Groups are configured (see Year Grid Widget setup above).

### Integration

The Anniversary Widget automatically works once:

1. App Groups are configured correctly
2. `WidgetHelper.shared.updateWidgetData()` is called (same as Year Grid Widget)
3. You have future entries in your app

**No additional integration needed** - it uses the same data pipeline as other widgets.

## Deep Linking

When user taps the widget, it opens the app to the specific anniversary date:

```
goodday://date/{timestamp}
```

**Important**: Since anniversaries are in the future, your app needs to:

1. Parse the timestamp from the URL
2. Navigate to that date
3. **Switch to the correct year** if the anniversary is in a future year

Example deep link handling:

```swift
.onOpenURL { url in
    if url.scheme == "goodday", url.host == "date",
       let timestamp = url.pathComponents.last,
       let timestampInt = Int(timestamp) {
        let targetDate = Date(timeIntervalSince1970: TimeInterval(timestampInt))

        // Navigate to this date
        // Remember to switch year if needed!
        navigateToDate(targetDate)
    }
}
```

## Data Requirements

For an entry to appear in the Anniversary Widget, it must:

1. **Be in the future**: Entry date > current date (compared at day level)
2. **Have content**: Either text body OR doodle drawing
3. **Be synced**: Entry must be saved and synced via `WidgetHelper.updateWidgetData()`

## Widget Update Frequency

The widget intelligently updates based on countdown time:

- **Same day (< 24 hours)**: Updates every minute for real-time countdown
- **Future days**: Updates at midnight each day
- **After configuration change**: Updates immediately

## No Anniversary View

When no future anniversaries exist:

- Shows calendar icon with clock badge
- Displays "No future anniversaries" message
- Tap opens app to current date
- Encourages user to create future entries

## Customization

You can customize the widget appearance in `AnniversaryWidget.swift`:

### Adjust Padding

```swift
// Small widget
.padding(12)  // Change doodle padding

// Medium widget
.padding(.horizontal, 16)  // Change horizontal padding

// Large widget
.padding(24)  // Change doodle padding
```

### Adjust Fonts

```swift
// Small widget countdown
.font(.caption)  // Change to .caption2, .footnote, etc.

// Medium widget date
.font(.caption)  // Change date font size

// Large widget countdown
.font(.callout)  // Change to .body, .title3, etc.
```

### Adjust Text Line Limits

```swift
// Small widget
.lineLimit(5)  // Show more/fewer lines

// Medium widget
.lineLimit(6)  // Adjust text area lines

// Large widget
.lineLimit(10)  // More space = more lines
```

### Adjust Medium Widget Layout

```swift
// Doodle size
.frame(width: 120, height: 120)  // Make doodle bigger/smaller

// Spacing between doodle and text
HStack(spacing: 12)  // Increase/decrease spacing
```

## Troubleshooting

### Widget Shows "No Future Anniversaries"

**Problem**: You have future entries but widget doesn't show them

**Solutions**:

1. Verify entries have dates in the future (after today)
2. Ensure entries have either text or doodle content
3. Check that `WidgetHelper.updateWidgetData()` is being called
4. Verify the body field is being saved (check `WidgetEntryData.body`)

### Countdown Shows Wrong Time

**Problem**: Countdown doesn't match expected time remaining

**Solutions**:

1. Check device date/time settings
2. Verify entry date is set correctly in the app
3. Widget uses device timezone - ensure it's correct
4. Force refresh: Long-press widget → Edit Widget → Done

### Widget Doesn't Update in Real-Time

**Problem**: Same-day countdown not updating every minute

**Solutions**:

1. This is normal for iOS widgets - they update on a schedule
2. iOS may throttle updates to save battery
3. Widget will update more frequently as the time approaches
4. Background refresh must be enabled for the app

### Configuration Doesn't Show My Date

**Problem**: Selected date in configuration but widget shows different date

**Solutions**:

1. Ensure the selected date has an entry with content
2. Entry must be in the future (not past or today)
3. Entry must have text body or doodle
4. Try removing and re-adding the widget

### Doodle Doesn't Display Correctly

**Problem**: Doodle appears cut off or scaled wrong

**Solutions**:

1. Doodles are scaled from 300x300 canvas to widget size
2. Very detailed doodles may lose clarity in small widget
3. Try using medium or large widget for better doodle display
4. Check that drawing data is being saved correctly

### Deep Link Opens Wrong Date

**Problem**: Tapping widget opens app but goes to wrong date or wrong year

**Solutions**:

1. Verify your app's deep link handler supports year switching
2. Check timestamp parsing in `onOpenURL` handler
3. Ensure calendar navigation can jump to future years
4. Test with dates far in the future (e.g., 2 years ahead)

## Performance Notes

- Widget reuses doodle rendering code from `RandomDoodleWidget`
- Text rendering is lightweight (native SwiftUI Text views)
- Memory footprint is minimal - only loads selected anniversary data
- Timeline updates optimized based on countdown duration
- Drawing data decoded on-demand during rendering

## Future Enhancements

Possible improvements:

- Multiple anniversaries in one widget (scrollable or multi-day view)
- Category filtering (birthdays, holidays, events)
- Custom countdown styles (progress bars, circular indicators)
- Anniversary history (show past anniversaries)
- Recurring anniversaries (birthdays that repeat yearly)
- Notification integration (alert when anniversary approaches)
