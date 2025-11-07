import Observation
import SwiftUI

struct SettingsView: View {
  @Environment(UserPreferences.self) private var userPreferences: UserPreferences
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme
  
  var body: some View {
    Form {
      
      // MARK: - View Mode Preferences
      Section("Default View Mode") {
        if #available(iOS 26.0, *) {
          Picker(
            "View Mode",
            selection: Binding(
              get: { userPreferences.defaultViewMode },
              set: { userPreferences.defaultViewMode = $0 }
            )
          ) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
              Text(mode.displayName).tag(mode)
            }
          }
          .pickerStyle(.palette)
          .glassEffect(.regular.interactive())
        } else {
          // Fallback on earlier versions
          Picker(
            "View Mode",
            selection: Binding(
              get: { userPreferences.defaultViewMode },
              set: { userPreferences.defaultViewMode = $0 }
            )
          ) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
              Text(mode.displayName).tag(mode)
            }
          }
          .pickerStyle(.palette)
        }
      }
      
      // MARK: - Appearance Preferences
      Section("Appearance") {
        if #available(iOS 26.0, *) {
          Picker(
            "Color Scheme",
            selection: Binding(
              get: { userPreferences.preferredColorScheme },
              set: {
                userPreferences.preferredColorScheme = $0
                // Force UI update immediately
                NotificationCenter.default.post(name: .didChangeColorScheme, object: nil)
              }
            )
          ) {
            Text("System").tag(nil as ColorScheme?)
            Text("Light").tag(ColorScheme.light as ColorScheme?)
            Text("Dark").tag(ColorScheme.dark as ColorScheme?)
          }
          .pickerStyle(.palette)
          .glassEffect(.regular.interactive())
        } else {
          // Fallback on earlier versions
          Picker(
            "Color Scheme",
            selection: Binding(
              get: { userPreferences.preferredColorScheme },
              set: {
                userPreferences.preferredColorScheme = $0
                // Force UI update immediately
                NotificationCenter.default.post(name: .didChangeColorScheme, object: nil)
              }
            )
          ) {
            Text("System").tag(nil as ColorScheme?)
            Text("Light").tag(ColorScheme.light as ColorScheme?)
            Text("Dark").tag(ColorScheme.dark as ColorScheme?)
          }
          .pickerStyle(.palette)
        }
      }
      
      // MARK: - Interaction Preferences
      Section("Interactions") {
        Toggle(
          "Enable haptic feedback",
          isOn: Binding(
            get: { userPreferences.enableHaptic },
            set: { userPreferences.enableHaptic = $0 }
          ))
      }
      
      // MARK: - Reset Section
      Section {
        Button("Reset to Defaults", role: .destructive) {
          withAnimation {
            userPreferences.resetToDefaults()
          }
        }
      } footer: {
        Text("This will reset all preferences to their default values.")
          .font(.caption)
          .foregroundColor(.appTextSecondary)
      }
    }
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden()
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button("dismiss", systemImage: "smallcircle.filled.circle.fill") {
          dismiss()
        }.tint(Color.appPrimary)
      }
    }
    .preferredColorScheme(userPreferences.preferredColorScheme)
    .onChange(of: userPreferences.preferredColorScheme) { _, _ in
      // Force view refresh when color scheme changes
      NotificationCenter.default.post(name: .didChangeColorScheme, object: nil)
    }
  }
}

#Preview {
  NavigationStack {
    SettingsView()
      .environment(UserPreferences.shared)
  }
}
