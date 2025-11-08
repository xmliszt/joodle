import Observation
import SwiftUI

// MARK: - Navigation Coordinator for Swipe Back Gesture
struct NavigationGestureEnabler: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> UIViewController {
    let controller = UIViewController()
    return controller
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    DispatchQueue.main.async {
      if let navigationController = uiViewController.navigationController {
        navigationController.interactivePopGestureRecognizer?.isEnabled = true
        navigationController.interactivePopGestureRecognizer?.delegate = context.coordinator
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
      return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      return false
    }
  }
}

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
    .background(NavigationGestureEnabler())
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
