//
//  PremiumFeature.swift
//  Joodle
//
//  Created by Premium Feature System
//

import Foundation
import SwiftUI
import Combine

// MARK: - Premium Feature Definition

/// All premium features in Joodle.
/// Add new features here - they will automatically be gated.
enum PremiumFeature: String, CaseIterable, Identifiable {
    case unlimitedDoodles
    case widgets  // Free users have NO widget access
    case iCloudSync
    case allShareTemplates

    var id: String { rawValue }

    // MARK: - Feature Metadata

    var name: String {
        switch self {
        case .unlimitedDoodles:
            return "Unlimited Doodles"
        case .widgets:
            return "All Widgets"
        case .iCloudSync:
            return "iCloud Sync"
        case .allShareTemplates:
            return "All Share Templates"
        }
    }

    var description: String {
        switch self {
        case .unlimitedDoodles:
            return "Draw as much as you want, no limits"
        case .widgets:
            return "Access to all Joodle widgets"
        case .iCloudSync:
            return "Sync your doodles across all devices"
        case .allShareTemplates:
            return "Beautiful templates for sharing"
        }
    }

    var icon: String {
        switch self {
        case .unlimitedDoodles:
            return "scribble.variable"
        case .widgets:
            return "square.grid.3x3.fill"
        case .iCloudSync:
            return "icloud.fill"
        case .allShareTemplates:
            return "square.and.arrow.up.fill"
        }
    }

    /// Free tier limits for features that have limits
    var freeLimit: Int? {
        switch self {
        case .unlimitedDoodles:
            return SubscriptionManager.freeDoodlesAllowed
        default:
            return nil
        }
    }

    /// Check if this feature is currently available
    /// Note: Must be called from MainActor context
    @MainActor
    var isAvailable: Bool {
        SubscriptionManager.shared.isSubscribed
    }
}

// MARK: - Premium Access Controller

/// Central controller for premium feature access.
/// Use this to check and gate premium features throughout the app.
@MainActor
final class PremiumAccessController: ObservableObject {
    static let shared = PremiumAccessController()

    @Published private(set) var isSubscribed: Bool = false
    @Published private(set) var subscriptionExpired: Bool = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Observe subscription manager changes
        SubscriptionManager.shared.$isSubscribed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                let wasSubscribed = self?.isSubscribed ?? false
                self?.isSubscribed = newValue

                // Detect subscription expiry
                if wasSubscribed && !newValue {
                    self?.handleSubscriptionExpired()
                }
            }
            .store(in: &cancellables)

        // Initial state
        isSubscribed = SubscriptionManager.shared.isSubscribed
    }

    // MARK: - Feature Access Checks

    /// Check if a feature is accessible
    func canAccess(_ feature: PremiumFeature) -> Bool {
        return isSubscribed
    }

    /// Check if user can create a new doodle based on current total count
    func canCreateDoodle(currentTotalCount: Int) -> Bool {
        if isSubscribed {
            return true
        }
        return currentTotalCount < (PremiumFeature.unlimitedDoodles.freeLimit ?? SubscriptionManager.freeDoodlesAllowed)
    }

    /// Check if user can edit a specific doodle (by index in total order)
    func canEditDoodle(atIndex index: Int) -> Bool {
        if isSubscribed {
            return true
        }
        // Free users can only edit their first N doodles
        return index < (PremiumFeature.unlimitedDoodles.freeLimit ?? SubscriptionManager.freeDoodlesAllowed)
    }

    /// Get remaining doodles for free users
    func remainingDoodles(currentTotalCount: Int) -> Int {
        if isSubscribed {
            return Int.max
        }
        let limit = PremiumFeature.unlimitedDoodles.freeLimit ?? SubscriptionManager.freeDoodlesAllowed
        return max(0, limit - currentTotalCount)
    }

    // MARK: - Subscription Expiry Handling

    private func handleSubscriptionExpired() {
        subscriptionExpired = true

        // Post notification for app-wide handling
        NotificationCenter.default.post(
            name: .subscriptionDidExpire,
            object: nil
        )

        // Disable iCloud sync if it was enabled
        if UserPreferences.shared.isCloudSyncEnabled {
            UserPreferences.shared.isCloudSyncEnabled = false
            NotificationCenter.default.post(
                name: NSNotification.Name("CloudSyncPreferenceChanged"),
                object: nil
            )
        }
    }

    /// Reset the expired flag (call after user acknowledges)
    func acknowledgeExpiry() {
        subscriptionExpired = false
    }

    /// Refresh subscription status from StoreKit
    func refreshSubscriptionStatus() async {
        await StoreKitManager.shared.updatePurchasedProducts()
        await SubscriptionManager.shared.updateSubscriptionStatus()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let subscriptionDidExpire = Notification.Name("subscriptionDidExpire")
    static let subscriptionDidActivate = Notification.Name("subscriptionDidActivate")
    static let premiumFeatureAccessed = Notification.Name("premiumFeatureAccessed")
}

// MARK: - View Modifiers for Premium Gating

/// Modifier that shows a paywall when tapping a locked feature
struct PremiumGatedModifier: ViewModifier {
    let feature: PremiumFeature
    @Binding var showPaywall: Bool
    @ObservedObject private var accessController = PremiumAccessController.shared

    let onAccessGranted: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if accessController.canAccess(feature) {
                    onAccessGranted?()
                } else {
                    showPaywall = true
                }
            }
    }
}

/// Modifier that overlays a lock on premium content
struct PremiumLockedOverlayModifier: ViewModifier {
    let feature: PremiumFeature
    @ObservedObject private var accessController = PremiumAccessController.shared

    func body(content: Content) -> some View {
        content
            .overlay {
                if !accessController.canAccess(feature) {
                    ZStack {
                        Color.black.opacity(0.3)

                        VStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.title)
                                .foregroundColor(.white)

                            Text("Joodle Super")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                    }
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Gates a view behind premium - shows paywall if not subscribed
    func requiresPremium(
        _ feature: PremiumFeature,
        showPaywall: Binding<Bool>,
        onAccessGranted: (() -> Void)? = nil
    ) -> some View {
        self.modifier(PremiumGatedModifier(
            feature: feature,
            showPaywall: showPaywall,
            onAccessGranted: onAccessGranted
        ))
    }

    /// Overlays a lock on content if not subscribed
    func premiumLocked(_ feature: PremiumFeature) -> some View {
        self.modifier(PremiumLockedOverlayModifier(feature: feature))
    }

    /// Shows a premium badge on the view
    func withPremiumBadge(_ feature: PremiumFeature, show: Bool = true) -> some View {
        self.overlay(alignment: .topTrailing) {
            if show && !PremiumAccessController.shared.isSubscribed {
                PremiumFeatureBadge()
                    .offset(x: 4, y: -4)
            }
        }
    }
}

// MARK: - Premium UI Components

/// Small badge indicating a premium feature
struct PremiumFeatureBadge: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "crown.fill")
                .font(.system(size: 8))
            Text("SUPER")
                .font(.system(size: 7, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.yellow, .accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
    }
}

/// Button that gates action behind premium
struct PremiumGatedButton<Label: View>: View {
    let feature: PremiumFeature
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var showPaywall = false
    @ObservedObject private var accessController = PremiumAccessController.shared

    var body: some View {
        Button {
            if accessController.canAccess(feature) {
                action()
            } else {
                showPaywall = true
            }
        } label: {
            label()
                .overlay(alignment: .topTrailing) {
                    if !accessController.canAccess(feature) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .sheet(isPresented: $showPaywall) {
            StandalonePaywallView()
        }
    }
}

/// View showing remaining doodles for free users
struct RemainingDoodlesIndicator: View {
    let currentCount: Int
    @ObservedObject private var accessController = PremiumAccessController.shared

    var body: some View {
        if !accessController.isSubscribed {
            let remaining = accessController.remainingDoodles(currentTotalCount: currentCount)

            HStack(spacing: 4) {
                Image(systemName: remaining > 0 ? "scribble" : "lock.fill")
                    .font(.caption)

                if remaining > 0 {
                    Text("\(remaining) doodles left")
                        .font(.caption)
                } else {
                    Text("Limit reached")
                        .font(.caption)
                }
            }
            .foregroundColor(remaining > 10 ? .secondary : (remaining > 0 ? .accent : .red))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
            )
        }
    }
}

/// Alert shown when subscription expires
struct SubscriptionExpiredAlert: ViewModifier {
    @ObservedObject private var accessController = PremiumAccessController.shared
    @State private var showAlert = false

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .subscriptionDidExpire)) { _ in
                showAlert = true
            }
            .alert("Subscription Ended", isPresented: $showAlert) {
                Button("OK") {
                    accessController.acknowledgeExpiry()
                }
                Button("Resubscribe") {
                    accessController.acknowledgeExpiry()
                    // The calling view should handle showing paywall
                    NotificationCenter.default.post(
                        name: .premiumFeatureAccessed,
                        object: nil
                    )
                }
            } message: {
                Text("Your Joodle Super subscription has ended. Some features are now limited.")
            }
    }
}

extension View {
    /// Adds subscription expiry alert handling to a view
    func handlesSubscriptionExpiry() -> some View {
        self.modifier(SubscriptionExpiredAlert())
    }
}

// MARK: - Doodle Access Helper

/// Helper to check doodle access based on entry index
@MainActor
struct DoodleAccessChecker {
    /// Check if a doodle can be edited based on its position in the total list
    static func canEdit(entry: DayEntry, allEntries: [DayEntry]) -> Bool {
        let accessController = PremiumAccessController.shared

        // Subscribed users can edit any doodle
        if accessController.isSubscribed {
            return true
        }

        // Sort entries by date (oldest first) and find the index
        let sortedEntries = allEntries
            .filter { $0.drawingData != nil }
            .sorted { $0.createdAt < $1.createdAt }

        guard let index = sortedEntries.firstIndex(where: { $0.id == entry.id }) else {
            // Entry not found or has no drawing - allow editing (creating new)
            return true
        }

        return accessController.canEditDoodle(atIndex: index)
    }

    /// Get all entries that have drawings
    static func entriesWithDrawings(from entries: [DayEntry]) -> [DayEntry] {
        return entries.filter { entry in
            entry.drawingData != nil
        }
    }

    /// Count total doodles across all entries
    static func totalDoodleCount(from entries: [DayEntry]) -> Int {
        return entriesWithDrawings(from: entries).count
    }
}

// MARK: - Preview

#Preview("Premium Badge") {
    VStack(spacing: 20) {
        Text("Feature")
            .padding()
            .background(Color.blue)
            .withPremiumBadge(.iCloudSync)

        RemainingDoodlesIndicator(currentCount: 55)

        RemainingDoodlesIndicator(currentCount: 60)

        PremiumFeatureBadge()
    }
}
