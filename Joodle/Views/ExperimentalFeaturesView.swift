//
//  ExperimentalFeaturesView.swift
//  Joodle
//
//  Created by Li Yuxuan on 2025.
//

import SwiftUI

struct ExperimentalFeaturesView: View {
  @Environment(\.userPreferences) private var userPreferences
  @StateObject private var subscriptionManager = SubscriptionManager.shared

  var body: some View {
    Form {
      Section {
        Toggle(isOn: Binding(
          get: { userPreferences.enableTimeBackdrop },
          set: { userPreferences.enableTimeBackdrop = $0 }
        )) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Time Passing Water Backdrop")
              .font(.body)
            Text("Shows an animated water level that drains throughout the day in the background.")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        .disabled(!subscriptionManager.isSubscribed)
      } header: {
        Text("Visual Effects")
      }

      Section {
        VStack(alignment: .leading, spacing: 12) {
          Label {
            Text("About Experimental Features")
              .font(.headline)
          } icon: {
            Image(systemName: "flask.fill")
              .foregroundStyle(.appAccent)
          }

          Text("Experimental features are fun little projects that we are testing. They may be incomplete, change significantly, or be removed in future updates.")
            .font(.subheadline)
            .foregroundColor(.secondary)

          Text("These features may affect performance or battery life.")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
      }
    }
    .navigationTitle("Experimental Features")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    ExperimentalFeaturesView()
  }
}
