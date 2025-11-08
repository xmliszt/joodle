# Font Debugging Guide

## Problem
The custom font "Mansalva-Regular.ttf" is not displaying in the app. Instead, a default fallback font is being used.

## Most Common Cause
The font name used in code (`"Mansalva-Regular"`) might not match the **PostScript name** inside the font file. iOS requires the exact PostScript name, not the filename.

## How to Find the Correct Font Name

### Method 1: Run the Debug Utility (Recommended)

1. Open Xcode and run the app
2. The `FontDebugView` will automatically print to console on app launch
3. Check the Xcode console output for:
   - `✓ Found Font Family: [Name]` - This is what you need!
   - `PostScript Name: [Name]` - Use this exact name in FontExtension.swift

### Method 2: Use Font Book (macOS)

1. Double-click `Fonts/Mansalva-Regular.ttf` to open it in Font Book
2. In Font Book, select the font
3. Go to **Preview** > **Show Font Info** (Cmd+I)
4. Look for "PostScript name" - this is the exact name you need

### Method 3: Quick Preview

1. Double-click the font file to open it
2. Look at the very top - the name shown might be the family name
3. The actual PostScript name might be different (e.g., "Mansalva" instead of "Mansalva-Regular")

## How to Fix

Once you find the correct font name, update it in:

**`GoodDay/GoodDay/Extensions/FontExtension.swift`** (Line 12):
```swift
private static let customFontName = "CORRECT_NAME_HERE"
```

**`GoodDay/Fonts/FontExtension.swift`** (Line 12):
```swift
private static let customFontName = "CORRECT_NAME_HERE"
```

## Common Font Name Examples

- Filename: `Mansalva-Regular.ttf`
- Possible PostScript names:
  - `Mansalva-Regular` ✓ (what we're currently using)
  - `Mansalva` ✓ (more likely)
  - `MansalvaRegular` ✓ (also possible)

## Verify Font is Loaded

After updating the font name, verify it's working:

1. Run the app
2. Check console for: `✓ Font 'YourFontName' loaded successfully`
3. If you see: `✗ Font 'YourFontName' failed to load` - the name is still wrong

## Checklist

- [x] Font file added to both targets (GoodDay & WidgetsExtension)
- [x] Font registered in `GoodDay/GoodDay/Info.plist`
- [x] Font registered in `GoodDay/Widgets/Info.plist`
- [ ] Font PostScript name verified and updated in FontExtension.swift
- [ ] App rebuilt and tested

## Next Steps

1. Run the app and check Xcode console
2. Look for the font name in the debug output
3. Update `FontExtension.swift` with the correct name
4. Clean build folder (Cmd+Shift+K)
5. Rebuild and run

## If Still Not Working

1. Make sure the font file is actually in the project navigator
2. Select the font file in Xcode
3. Check "Target Membership" in File Inspector (right panel)
4. Both "GoodDay" and "WidgetsExtension" should be checked
5. Clean build folder and rebuild
