# Widget Update Implementation

## Overview

The GoodDay app keeps its home screen widget synchronized with the main app's data using a centralized, reactive approach. Widget updates are triggered automatically whenever entry data changes, ensuring the widget always displays current information.

## Architecture

### Core Components

1. **WidgetHelper** (`Utils/WidgetHelper.swift`)
   - Singleton class that manages widget data synchronization
   - Converts `DayEntry` objects to `WidgetEntryData` (lightweight, widget-friendly format)
   - Stores data in shared UserDefaults (App Group: `group.dev.liyuxuan.GoodDay`)
   - Triggers widget timeline reloads via `WidgetCenter.shared.reloadAllTimelines()`

2. **ContentView** (`Views/ContentView.swift`)
   - Central coordinator for all widget updates
   - Uses `@Query private var entries: [DayEntry]` to reactively observe data changes
   - Implements `@Environment(\.scenePhase)` to track app lifecycle

### Data Flow

```
User Action (Edit/Draw/Delete)
    ↓
SwiftData Model Update (modelContext.save())
    ↓
@Query Detects Change in ContentView
    ↓
onChange Handler Fires
    ↓
WidgetHelper.updateWidgetData(with: entries)
    ↓
Widget Timeline Reloads
```

## Update Triggers

Widget updates occur automatically in the following scenarios:

### 1. Data Changes (Reactive)
- **When entries are added or removed**: `onChange(of: entries.count)`
- **When entry content is modified**: `onChange(of: entries)`
- Covers: text edits, drawing updates, deletions from any view

### 2. App Lifecycle (Explicit)
- **App comes to foreground**: `scenePhase == .active`
- **App goes to background**: `scenePhase == .background`
- Ensures widget shows latest data when user returns to home screen

### 3. App Launch
- **On app appear**: `onAppear` handler in ContentView
- Initial sync when app starts

## Implementation Details

### Why Centralized Updates?

Instead of calling `WidgetHelper` from every view that modifies data, we use SwiftUI's reactive `@Query` system:

**Benefits:**
- ✅ Single source of truth (ContentView)
- ✅ No duplicate update calls
- ✅ Guaranteed to catch all data changes
- ✅ Simpler, more maintainable code
- ✅ Follows SwiftUI's reactive patterns

**Alternative (Not Used):**
- ❌ Manual calls in every view that edits data
- ❌ Risk of missing update calls
- ❌ Redundant updates when @Query also fires

### Views That Modify Entries

These views save changes to SwiftData but **do not** directly call widget update:

1. **EntryEditingView** - Text entry editing and deletion
2. **DrawingCanvasView** - Drawing creation and updates
3. **ContentView** - Entry creation on date selection

All changes are automatically detected by ContentView's `@Query` and trigger widget updates.

### Widget Data Structure

```swift
struct WidgetEntryData: Codable {
  let date: Date
  let hasText: Bool
  let hasDrawing: Bool
}
```

**Note:** Actual drawing data (`drawingData: Data?`) is excluded to keep widget memory under the 30MB limit. The widget only needs to know *whether* a drawing exists, not the drawing itself.

## Code Examples

### ContentView Widget Update Handlers

```swift
struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Query private var entries: [DayEntry]

  var body: some View {
    // ... view content ...
    .onAppear {
      // Initial sync on app launch
      WidgetHelper.shared.updateWidgetData(with: entries)
    }
    .onChange(of: entries.count) { _, _ in
      // Sync when entries added/removed
      WidgetHelper.shared.updateWidgetData(with: entries)
    }
    .onChange(of: entries) { _, newEntries in
      // Sync when entry content changes
      WidgetHelper.shared.updateWidgetData(with: newEntries)
    }
    .onChange(of: scenePhase) { _, newPhase in
      switch newPhase {
      case .active, .background:
        // Sync on foreground/background
        WidgetHelper.shared.updateWidgetData(with: entries)
      default:
        break
      }
    }
  }
}
```

### Entry Modification (No Widget Call Needed)

```swift
// EntryEditingView.swift
private func saveNote(text: String, for date: Date) {
  if let entry {
    entry.body = text
  } else {
    let newEntry = DayEntry(body: text, createdAt: date)
    modelContext.insert(newEntry)
  }

  try? modelContext.save()

  // Widget will be updated automatically by ContentView's @Query onChange handler
}
```

## Testing Widget Updates

To verify widget updates are working:

1. **Make a change in the app** (add text, draw, delete entry)
2. **Press home button** to background the app
3. **Check the widget** - it should show the updated data
4. **Return to app** and make another change
5. **Background again** - widget should update again

## Performance Considerations

- Updates are debounced naturally by SwiftUI's onChange batching
- Only lightweight metadata is sent to widget (no large drawing data)
- Shared UserDefaults is fast and efficient for small data
- Widget timeline reload is handled by system efficiently

## Future Improvements

Potential optimizations:

1. **Debouncing**: Add explicit debouncing for rapid changes (e.g., during typing)
2. **Selective Updates**: Only update if data actually changed (compare old vs new)
3. **Background Task**: Use BGTaskScheduler for periodic updates when app is terminated
4. **Delta Updates**: Only send changed entries instead of full array

## Troubleshooting

**Widget not updating:**
1. Check App Group identifier matches in both app and widget targets
2. Verify widget extension has proper entitlements
3. Ensure `WidgetCenter.shared.reloadAllTimelines()` is being called
4. Check console for encoding/UserDefaults errors

**Widget showing stale data:**
1. Verify `onChange` handlers are firing (add debug print statements)
2. Check that `modelContext.save()` is called after changes
3. Ensure widget is reading from correct UserDefaults suite

**Performance issues:**
1. Monitor frequency of `updateWidgetData` calls
2. Check size of data being saved to UserDefaults
3. Consider adding debouncing for high-frequency updates
