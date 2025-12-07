//
//  SubscriptionManager.swift
//  Joodle
//
//  Created by Subscription Manager
//

import Foundation
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isSubscribed: Bool {
        didSet {
            UserDefaults.standard.set(isSubscribed, forKey: "isJoodleSuper")
        }
    }

    @Published var isInTrialPeriod: Bool = false
    @Published var subscriptionExpirationDate: Date?
    @Published var willAutoRenew: Bool = true

    private init() {
        self.isSubscribed = UserDefaults.standard.bool(forKey: "isJoodleSuper")

        // Start monitoring subscription status
        Task {
            await updateSubscriptionStatus()
        }
    }

    // MARK: - Subscription Features

    var hasUnlimitedDoodles: Bool {
        isSubscribed
    }

    var hasAllWidgets: Bool {
        isSubscribed
    }

    var hasICloudSync: Bool {
        isSubscribed
    }

    var hasAllShareTemplates: Bool {
        isSubscribed
    }

    // Free plan limits
    var doodlesPerYear: Int {
        isSubscribed ? Int.max : 60
    }

    // MARK: - Update Status

    func updateSubscriptionStatus() async {
        let storeManager = StoreKitManager.shared
        self.isSubscribed = storeManager.hasActiveSubscription
        self.isInTrialPeriod = storeManager.isInTrialPeriod
        self.subscriptionExpirationDate = storeManager.subscriptionExpirationDate
        self.willAutoRenew = storeManager.willAutoRenew
    }

    // MARK: - Computed Properties

    var subscriptionStatusMessage: String? {
        guard isSubscribed else { return nil }

        if isInTrialPeriod {
            if let expiration = subscriptionExpirationDate {
                return "Free trial ends \(expiration.formatted(date: .abbreviated, time: .omitted))"
            } else {
                return "You're on a free trial"
            }
        } else if !willAutoRenew {
            if let expiration = subscriptionExpirationDate {
                return "Subscription ends \(expiration.formatted(date: .abbreviated, time: .omitted))"
            } else {
                return "Subscription will not renew"
            }
        }

        return nil
    }

    var shouldShowRenewalWarning: Bool {
        guard isSubscribed, !willAutoRenew else { return false }

        // Show warning if subscription won't renew
        if let expiration = subscriptionExpirationDate {
            // Show warning if expiring within 7 days
            let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
            return daysUntilExpiration <= 7
        }

        return true
    }

    func grantSubscription() {
        self.isSubscribed = true
    }

    func revokeSubscription() {
        self.isSubscribed = false
    }
}
