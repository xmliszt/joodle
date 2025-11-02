# Widget Integration Example

This file shows how to integrate the Year Grid Widget into your GoodDay app to keep it synchronized with your entries.

## Step 1: Update App Group Identifier

First, replace `"group.com.yourcompany.GoodDay"` with your actual App Group identifier in both files:

- `Widgets/WidgetDataManager.swift`
- `GoodDay/Utils/WidgetHelper.swift`

For example: `"group.com.liyuxuan.GoodDay"`

## Step 2: Add Widget Updates to Your Data Manager

Find where you manage your `DayEntry` SwiftData objects and add widget update calls.

### Example 1: Update Widget After Saving Entry

```swift
import SwiftData
import WidgetKit

// In your view or view model where you save entries
func saveEntry(body: String, date: Date, drawingData: Data?) {
  let entry = DayEntry(body: body, createdAt: date, drawingData: drawingData)
  modelContext.insert(entry)

  do {
    try modelContext.save()

    // Update widget with all entries
    updateWidget()
  } catch {
    print("Failed to save entry: \(error)")
  }
}

private func updateWidget() {
  // Fetch all entries from SwiftData
  let descriptor = FetchDescriptor<DayEntry>(
    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
  )

  do {
    let allEntries = try modelContext.fetch(descriptor)
    WidgetHelper.shared.updateWidgetData(with: allEntries)
  } catch {
    print("Failed to fetch entries for widget: \(error)")
  }
}
```

### Example 2: Update Widget After Deleting Entry

```swift
func deleteEntry(_ entry: DayEntry) {
  modelContext.delete(entry)

  do {
    try modelContext.save()

    // Update widget with remaining entries
    updateWidget()
  } catch {
    print("Failed to delete entry: \(error)")
  }
}
```

### Example 3: Refresh Widget When App Becomes Active

Add this to your main app file (`GoodDayApp.swift`):

```swift
import SwiftUI
import SwiftData

@main
struct GoodDayApp: App {
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      DayEntry.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
    .backgroundTask(.appRefresh("widget-refresh")) { _ in
      // Refresh widget data
      await refreshWidgetData()
    }
  }

  private func refreshWidgetData() async {
    let context = ModelContext(sharedModelContainer)
    let descriptor = FetchDescriptor<DayEntry>()

    do {
      let entries = try context.fetch(descriptor)
      WidgetHelper.shared.updateWidgetData(with: entries)
    } catch {
      print("Failed to refresh widget data: \(error)")
    }
  }
}
```

### Example 4: Update Widget When Scene Becomes Active

Add this to your main content view:

```swift
import SwiftUI
import SwiftData

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    // Your existing view content
    YourMainView()
      .onChange(of: scenePhase) { _, newPhase in
        if newPhase == .active {
          // App became active, refresh widget
          refreshWidget()
        }
      }
  }

  private func refreshWidget() {
    let descriptor = FetchDescriptor<DayEntry>()

    do {
      let entries = try modelContext.fetch(descriptor)
      WidgetHelper.shared.updateWidgetData(with: entries)
    } catch {
      print("Failed to refresh widget: \(error)")
    }
  }
}
```

## Step 3: Enable App Groups in Xcode

### For Main App (GoodDay target):
1. Select GoodDay project → GoodDay target
2. Go to "Signing & Capabilities"
3. Click "+ Capability" → select "App Groups"
4. Click "+" and add: `group.com.yourcompany.GoodDay`
5. Check the checkbox

### For Widget (Widgets target):
1. Select GoodDay project → Widgets target
2. Go to "Signing & Capabilities"
3. Click "+ Capability" → select "App Groups"
4. Select the SAME group: `group.com.yourcompany.GoodDay`
5. Check the checkbox

## Step 4: Test the Integration

1. Run the main app on a device/simulator
2. Create a new entry with text
3. Go to home screen and add the "Year Progress" widget
4. The widget should show a ring around today's dot
5. Create another entry with a drawing
6. Widget should update to show a rounded rectangle

## Complete Example: Entry Editing View

Here's a complete example of how to integrate widget updates in an entry editing view:

```swift
import SwiftUI
import SwiftData
import WidgetKit

struct EntryEditingView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  @State private var textContent: String = ""
  @State private var drawingData: Data? = nil
  let date: Date

  var body: some View {
    VStack {
      TextEditor(text: $textContent)
        .padding()

      Button("Save") {
        saveEntry()
      }
    }
  }

  private func saveEntry() {
    let entry = DayEntry(
      body: textContent,
      createdAt: date,
      drawingData: drawingData
    )

    modelContext.insert(entry)

    do {
      try modelContext.save()

      // Update widget with all entries
      let descriptor = FetchDescriptor<DayEntry>()
      let allEntries = try modelContext.fetch(descriptor)
      WidgetHelper.shared.updateWidgetData(with: allEntries)

      dismiss()
    } catch {
      print("Failed to save entry: \(error)")
    }
  }
}
```

## Troubleshooting

### Widget doesn't update after creating entry
- Check console for "Failed to access shared UserDefaults" messages
- Verify App Group identifiers match in both targets
- Ensure you're calling `updateWidgetData()` after saving

### "Failed to access shared UserDefaults" error
- App Group not enabled in both targets
- App Group identifier mismatch between code and capabilities
- App Group identifier typo in code

### Widget shows empty even though entries exist
- WidgetHelper might not be called on app launch
- Add widget refresh in `onAppear` or `scenePhase` change
- Force refresh: `WidgetHelper.shared.reloadWidget()`

## Performance Tips

1. **Batch updates**: Don't update widget after every single entry change
2. **Background updates**: Use `.backgroundTask` for periodic updates
3. **Limit data**: Only send essential entry data (date, hasText, hasDrawing)
4. **Debounce**: If user is rapidly creating/deleting entries, debounce widget updates

```swift
// Debounced widget update
@State private var updateTimer: Timer?

func scheduleWidgetUpdate() {
  updateTimer?.invalidate()
  updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
    updateWidget()
  }
}
```
