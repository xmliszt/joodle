//
//  SubscriptionTestingView.swift
//  Joodle
//
//  Debug view for comprehensive StoreKit subscription testing
//

import SwiftUI
import StoreKit

struct SubscriptionTestingView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var storeKitManager = StoreKitManager.shared
  @StateObject private var subscriptionManager = SubscriptionManager.shared

  @State private var isSyncing = false
  @State private var showManageSubscriptions = false
  @State private var showRedeemCode = false
  @State private var expandedSection: TestSection?
  @State private var subscriptionGroupID: String?

  enum TestSection: String, CaseIterable {
    case status = "Current Status"
    case freshPurchase = "Fresh Purchase"
    case introOffer = "Introductory Offer"
    case renewal = "Renewal Testing"
    case interrupted = "Interrupted Purchase"
    case restore = "Restore Purchase"
    case billingIssues = "Billing Issues"
    case priceIncrease = "Price Increase"
    case manageSubscription = "Manage Subscription"
    case offerCodes = "Offer Codes"
  }

  var body: some View {
    NavigationStack {
      List {
        // MARK: - Current Status Section
        Section {
          statusRow("Subscription", value: subscriptionManager.isSubscribed ? "Subscribed ✓" : "Not Subscribed", isActive: subscriptionManager.isSubscribed)
          statusRow("Grace Period", value: GracePeriodManager.shared.isInGracePeriod ? "Active (\(GracePeriodManager.shared.gracePeriodDaysRemaining)d left)" : (GracePeriodManager.shared.hasGracePeriodExpired ? "Expired" : "N/A"), isActive: GracePeriodManager.shared.isInGracePeriod)
          statusRow("Premium Access", value: subscriptionManager.hasPremiumAccess ? "Yes ✓" : "No", isActive: subscriptionManager.hasPremiumAccess)
          statusRow("StoreKit Status", value: storeKitManager.hasActiveSubscription ? "Active ✓" : "None", isActive: storeKitManager.hasActiveSubscription)
          statusRow("In Trial", value: storeKitManager.isInTrialPeriod ? "Yes" : "No", isActive: storeKitManager.isInTrialPeriod)
          statusRow("Eligible for Intro Offer", value: storeKitManager.isEligibleForIntroOffer ? "Yes" : "No", isActive: storeKitManager.isEligibleForIntroOffer)
          statusRow("Will Auto-Renew", value: storeKitManager.willAutoRenew ? "Yes" : "No", isActive: storeKitManager.willAutoRenew)

          if let expiration = storeKitManager.subscriptionExpirationDate {
            statusRow("Expiration", value: expiration.formatted(date: .abbreviated, time: .shortened), isActive: expiration > Date())
          }

          if !storeKitManager.purchasedProductIDs.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              Text("Active Products")
                .font(.subheadline)
                .foregroundColor(.secondary)
              ForEach(Array(storeKitManager.purchasedProductIDs), id: \.self) { productID in
                Text(productID)
                  .font(.caption)
                  .foregroundColor(.primary)
              }
            }
          }
        } header: {
          Text("Current Status")
        }

        // MARK: - Quick Actions
        Section {
          #if DEBUG
          Button("Grant Subscription (App Only)") {
            subscriptionManager.grantSubscription()
          }
          .disabled(subscriptionManager.isSubscribed)

          Button("Revoke Subscription (App Only)", role: .destructive) {
            subscriptionManager.revokeSubscription()
          }
          .disabled(!subscriptionManager.isSubscribed)
          #endif

          Button {
            syncFromStoreKit()
          } label: {
            HStack {
              Text("Sync from StoreKit")
              Spacer()
              if isSyncing {
                ProgressView()
                  .scaleEffect(0.8)
              }
            }
          }
          .disabled(isSyncing)
        } header: {
          Text("Quick Actions")
        } footer: {
          Text("App-only changes don't affect StoreKit. Use 'Sync from StoreKit' to restore actual status.")
        }

        // MARK: - Test Scenarios
        Section {
          testScenarioDisclosure(.freshPurchase)
          testScenarioDisclosure(.introOffer)
          testScenarioDisclosure(.renewal)
          testScenarioDisclosure(.interrupted)
          testScenarioDisclosure(.restore)
          testScenarioDisclosure(.billingIssues)
          testScenarioDisclosure(.priceIncrease)
          testScenarioDisclosure(.manageSubscription)
          testScenarioDisclosure(.offerCodes)
        } header: {
          Text("Test Scenarios")
        } footer: {
          Text("Tap each scenario for step-by-step testing instructions.")
        }

        // MARK: - In-App Actions
        Section {
          Button("Show Manage Subscriptions Sheet") {
            showManageSubscriptions = true
          }

          Button("Show Redeem Code Sheet") {
            showRedeemCode = true
          }

          Button("Restore Purchase") {
            Task {
              await storeKitManager.restorePurchases()
            }
          }
        } header: {
          Text("In-App Actions")
        }

        // MARK: - Xcode Instructions
        Section {
          xcodeInstructionRow(
            title: "Open Transaction Manager",
            instruction: "Debug → StoreKit → Manage Transactions"
          )
          xcodeInstructionRow(
            title: "Delete All Transactions",
            instruction: "Transaction Manager → Select All → Delete"
          )
          xcodeInstructionRow(
            title: "Set Renewal Rate",
            instruction: "Select .storekit file → Editor → Subscription Renewal Rate"
          )
          xcodeInstructionRow(
            title: "Enable Interrupted Purchases",
            instruction: "Select .storekit file → Editor → Enable Interrupted Purchases"
          )
          xcodeInstructionRow(
            title: "Enable Billing Retry",
            instruction: "Select .storekit file → Editor → Enable Billing Retry on Renewal"
          )
          xcodeInstructionRow(
            title: "Enable Billing Grace Period",
            instruction: "Select .storekit file → Editor → Enable Billing Grace Period"
          )
        } header: {
          Text("Xcode Quick Reference")
        }
      }
      .navigationTitle("Subscription Testing")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
      .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
      .offerCodeRedemption(isPresented: $showRedeemCode)
      .task {
        // Load subscription group ID for status monitoring
        await loadSubscriptionGroupID()
      }
      .subscriptionStatusTask(for: subscriptionGroupID ?? "") { _ in
        // This fires automatically whenever subscription status changes
        // Works regardless of how the system sheet is dismissed
        guard subscriptionGroupID != nil else { return }

        Task {
          await storeKitManager.updatePurchasedProducts()
          await subscriptionManager.updateSubscriptionStatus()
        }
      }
      .onChange(of: showManageSubscriptions) { _, isPresented in
        // Additional refresh after the manage subscriptions sheet is dismissed
        if !isPresented {
          Task {
            await storeKitManager.updatePurchasedProducts()
            await subscriptionManager.updateSubscriptionStatus()
          }
        }
      }
      .onChange(of: showRedeemCode) { _, isPresented in
        // Refresh subscription status after the redeem code sheet is dismissed
        if !isPresented {
          Task {
            await storeKitManager.updatePurchasedProducts()
            await subscriptionManager.updateSubscriptionStatus()
          }
        }
      }
    }
  }

  // MARK: - Load Subscription Group ID

  private func loadSubscriptionGroupID() async {
    // Get the subscription group ID from the first subscription product
    for product in storeKitManager.products {
      if let subscription = product.subscription {
        subscriptionGroupID = subscription.subscriptionGroupID
        return
      }
    }

    // If products aren't loaded yet, wait and try again
    if storeKitManager.products.isEmpty {
      await storeKitManager.loadProducts()
      for product in storeKitManager.products {
        if let subscription = product.subscription {
          subscriptionGroupID = subscription.subscriptionGroupID
          return
        }
      }
    }
  }

  // MARK: - Helper Views

  private func statusRow(_ label: String, value: String, isActive: Bool) -> some View {
    HStack {
      Text(label)
        .font(.subheadline)
      Spacer()
      Text(value)
        .font(.subheadline)
        .foregroundColor(isActive ? .green : .secondary)
    }
  }

  private func xcodeInstructionRow(title: String, instruction: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.subheadline)
        .fontWeight(.medium)
      Text(instruction)
        .font(.caption)
        .foregroundColor(.secondary)
        .textSelection(.enabled)
    }
    .padding(.vertical, 2)
  }

  @ViewBuilder
  private func testScenarioDisclosure(_ scenario: TestSection) -> some View {
    DisclosureGroup(
      isExpanded: Binding(
        get: { expandedSection == scenario },
        set: { expandedSection = $0 ? scenario : nil }
      )
    ) {
      scenarioContent(for: scenario)
    } label: {
      Label(scenario.rawValue, systemImage: iconForScenario(scenario))
    }
  }

  private func iconForScenario(_ scenario: TestSection) -> String {
    switch scenario {
    case .status: return "info.circle"
    case .freshPurchase: return "cart"
    case .introOffer: return "gift"
    case .renewal: return "arrow.clockwise"
    case .interrupted: return "exclamationmark.triangle"
    case .restore: return "arrow.counterclockwise"
    case .billingIssues: return "creditcard.trianglebadge.exclamationmark"
    case .priceIncrease: return "arrow.up.circle"
    case .manageSubscription: return "gearshape"
    case .offerCodes: return "ticket"
    }
  }

  @ViewBuilder
  private func scenarioContent(for scenario: TestSection) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      switch scenario {
      case .status:
        EmptyView()

      case .freshPurchase:
        testStepView(steps: [
          "1. Delete all transactions in Xcode:\n   Debug → StoreKit → Manage Transactions → Delete All",
          "2. Tap 'Sync from StoreKit' above to confirm clean state",
          "3. Open any paywall in the app",
          "4. Complete a subscription purchase",
          "5. Verify: Transaction appears in Manage Transactions",
          "6. Verify: App shows subscribed status"
        ])

      case .introOffer:
        testStepView(steps: [
          "Prerequisites:",
          "• Ensure intro offer is configured in .storekit file",
          "• Delete existing transactions to reset eligibility",
          "",
          "Test Steps:",
          "1. Delete all transactions (Debug → StoreKit → Manage Transactions)",
          "2. Tap 'Sync from StoreKit' - verify 'Eligible for Intro Offer: Yes'",
          "3. Open paywall and purchase subscription",
          "4. Verify: Payment sheet shows intro offer pricing",
          "5. Complete purchase",
          "6. Verify: 'In Trial: Yes' after purchase",
          "",
          "To Retest:",
          "Delete the transaction in Manage Transactions"
        ])

      case .renewal:
        testStepView(steps: [
          "Setup:",
          "1. Select .storekit file in Project Navigator",
          "2. Editor → Subscription Renewal Rate → choose rate:",
          "   • Monthly Renewal Every 30 Seconds (fastest)",
          "   • Monthly Renewal Every 5 Minutes",
          "   • Monthly Renewal Every 30 Minutes",
          "",
          "Test Steps:",
          "1. Purchase a subscription",
          "2. Wait for renewal period to elapse",
          "3. Check Manage Transactions for renewal",
          "4. Verify app handles renewal correctly",
          "",
          "Reset:",
          "Editor → Subscription Renewal Rate → Real Time"
        ])

      case .interrupted:
        testStepView(steps: [
          "Setup:",
          "1. Select .storekit file in Project Navigator",
          "2. Editor → Enable Interrupted Purchases",
          "",
          "Test Steps:",
          "1. Attempt a purchase in the app",
          "2. Tap Confirm on payment sheet",
          "3. Verify: Purchase fails (expected behavior)",
          "4. Debug → StoreKit → Manage Transactions",
          "5. Select the failed transaction → Click 'Resolve'",
          "6. Verify: App receives successful purchase",
          "",
          "Reset:",
          "Editor → Disable Interrupted Purchases"
        ])

      case .restore:
        testStepView(steps: [
          "Test with NO purchases:",
          "1. Delete all transactions",
          "2. Tap 'Restore Purchase' button above",
          "3. Verify: App handles gracefully (no crash, appropriate message)",
          "",
          "Test WITH purchases:",
          "1. Make a purchase, then revoke locally",
          "2. Tap 'Restore Purchase'",
          "3. Verify: Subscription restored correctly"
        ])

      case .billingIssues:
        testStepView(steps: [
          "Setup for Billing Retry:",
          "1. Select .storekit file",
          "2. Editor → Enable Billing Retry on Renewal",
          "3. (Optional) Editor → Enable Billing Grace Period",
          "4. Set fast renewal rate (30 seconds)",
          "",
          "Test Steps:",
          "1. Purchase a subscription",
          "2. Wait for renewal to fail (billing retry)",
          "3. Debug → StoreKit → Manage Transactions",
          "4. Verify transaction shows billing retry state",
          "5. If grace period enabled: verify app still works",
          "6. Click 'Resolve Issues' to fix billing",
          "7. Verify subscription resumes",
          "",
          "Reset:",
          "• Editor → Disable Billing Retry on Renewal",
          "• Editor → Disable Billing Grace Period"
        ])

      case .priceIncrease:
        testStepView(steps: [
          "Setup:",
          "1. Purchase a subscription first",
          "2. (Optional) Increase price in .storekit file",
          "",
          "Test Steps:",
          "1. Debug → StoreKit → Manage Transactions",
          "2. Select subscription transaction",
          "3. Click 'Request Price Increase Consent'",
          "4. Verify: Consent sheet appears in app",
          "5. Test both 'Agree' and 'Close' options",
          "",
          "Note: Test deferred presentation by triggering",
          "consent while in a view that defers sheets"
        ])

      case .manageSubscription:
        testStepView(steps: [
          "Test Steps:",
          "1. Purchase a subscription",
          "2. Tap 'Show Manage Subscriptions Sheet' above",
          "3. Verify: Sheet displays current subscription",
          "4. Test upgrade/downgrade between plans",
          "5. Test cancellation flow",
          "6. Verify app responds to changes correctly"
        ])

      case .offerCodes:
        testStepView(steps: [
          "Setup:",
          "1. Configure offer codes in .storekit file",
          "   (Under subscription → Offer Codes)",
          "",
          "Test Steps:",
          "1. Tap 'Show Redeem Code Sheet' above",
          "2. Select configured offer code",
          "3. Verify: Payment sheet shows offer",
          "4. Complete redemption",
          "5. Verify: Subscription activated with offer",
          "",
          "To Retest:",
          "Delete transaction in Manage Transactions"
        ])
      }
    }
    .padding(.vertical, 8)
  }

  private func testStepView(steps: [String]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(steps, id: \.self) { step in
        if step.isEmpty {
          Spacer().frame(height: 4)
        } else {
          Text(step)
            .font(.caption)
            .foregroundColor(step.hasPrefix("•") || step.hasPrefix("1") || step.hasPrefix("2") || step.hasPrefix("3") || step.hasPrefix("4") || step.hasPrefix("5") || step.hasPrefix("6") || step.hasPrefix("7") ? .primary : .secondary)
            .fontWeight(step.contains(":") && !step.hasPrefix(" ") && !step.contains("→") ? .medium : .regular)
        }
      }
    }
    .textSelection(.enabled)
  }

  // MARK: - Actions

  private func syncFromStoreKit() {
    isSyncing = true
    Task {
      await storeKitManager.updatePurchasedProducts()
      await subscriptionManager.updateSubscriptionStatus()
      isSyncing = false
    }
  }
}

// MARK: - Preview

#if DEBUG
#Preview {
  SubscriptionTestingView()
}
#endif
