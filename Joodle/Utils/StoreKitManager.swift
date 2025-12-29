//
//  StoreKitManager.swift
//  Joodle
//
//  Created by StoreKit Manager
//

import Foundation
import StoreKit
import Combine

@MainActor
class StoreKitManager: NSObject, ObservableObject {
    static let shared = StoreKitManager()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Subscription status details
    @Published var isInTrialPeriod = false
    @Published var subscriptionExpirationDate: Date?
    @Published var willAutoRenew = true
    @Published var isEligibleForIntroOffer = true
    @Published var currentProductID: String?  // The actual currently active subscription product

    private let productIDs: [String] = [
        "dev.liyuxuan.joodle.pro.monthly",
        "dev.liyuxuan.joodle.pro.yearly"
    ]

    private var updateListenerTask: Task<Void, Never>?
    private var foregroundObserver: AnyCancellable?

    /// Debug logger for TestFlight troubleshooting
    private let debugLogger = PaywallDebugLogger.shared

    override init() {
        super.init()

        // Add StoreKit 1 observer for App Store promoted in-app purchases
        // This is required for handling purchases initiated from the App Store product page
        SKPaymentQueue.default().add(self)

        // Start listening for StoreKit 2 transaction updates
        updateListenerTask = listenForTransactions()
        setupForegroundObserver()

        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
        foregroundObserver?.cancel()
        // Remove StoreKit 1 observer
        SKPaymentQueue.default().remove(self)
    }

    // MARK: - Foreground Observer

    /// Listen for app returning to foreground to refresh subscription status
    /// This catches changes made in the system subscription management sheet
    private func setupForegroundObserver() {
        foregroundObserver = NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.updatePurchasedProducts()
                    // Also sync SubscriptionManager to update feature flags and UI state
                    await SubscriptionManager.shared.updateSubscriptionStatus()
                    self?.debugLogger.log(.debug, "Refreshed subscription status on foreground")
                }
            }
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        debugLogger.logProductsLoading()
        print("📦 StoreKit: Loading products for IDs: \(productIDs)")
        print("📦 StoreKit: Environment - \(getEnvironmentInfo())")

        do {
            let loadedProducts = try await Product.products(for: productIDs)
            print("📦 StoreKit: Loaded \(loadedProducts.count) products")

            // Log to debug logger
            debugLogger.logProductsLoaded(count: loadedProducts.count, productIDs: loadedProducts.map { $0.id })

            for product in loadedProducts {
                print("📦 Product: \(product.id)")
                print("   💰 Display Name: \(product.displayName)")
                print("   💰 Display Price: \(product.displayPrice)")
                print("   💰 Raw Price: \(product.price)")
                print("   💰 Currency Code: \(product.priceFormatStyle.currencyCode)")
                print("   🌍 Locale: \(product.priceFormatStyle.locale.identifier)")

                // Log each product to debug logger
                debugLogger.logProductDetails(
                    id: product.id,
                    displayName: product.displayName,
                    price: product.displayPrice
                )
            }

            self.products = loadedProducts.sorted { product1, product2 in
                // Sort monthly first, then yearly
                if product1.id.contains("monthly") {
                    return true
                }
                return false
            }

            if loadedProducts.isEmpty {
                let troubleshootingMessage = """
                No products found. This typically means:

                1. Products not created in App Store Connect
                2. Products not in 'Ready to Submit' or 'Approved' status
                3. Product IDs don't match exactly
                4. Paid Applications Agreement not active
                5. Products just created (wait 24-48 hours for propagation)

                Expected IDs: \(productIDs.joined(separator: ", "))
                """
                errorMessage = "Unable to load subscription plans. Please try again later."
                print("⚠️ StoreKit: \(troubleshootingMessage)")
                debugLogger.log(.warning, "No products found", details: troubleshootingMessage)
            }
        } catch let error as StoreKitError {
            let detailedError = handleStoreKitError(error)
            errorMessage = detailedError
            print("❌ StoreKit Error (StoreKitError): \(error)")
            print("❌ Detailed: \(detailedError)")
            debugLogger.logStoreKitError(error, context: "Loading products (StoreKitError)")
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("❌ StoreKit Error: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Full error description: \(String(describing: error))")
            debugLogger.logStoreKitError(error, context: "Loading products")
        }

        isLoading = false
    }

    // MARK: - Debug Helpers

    private func getEnvironmentInfo() -> String {
        #if DEBUG
        return "DEBUG build"
        #else
        // Check if running from TestFlight
        if let receiptURL = Bundle.main.appStoreReceiptURL {
            if receiptURL.lastPathComponent == "sandboxReceipt" {
                return "TestFlight/Sandbox"
            } else if receiptURL.path.contains("sandboxReceipt") {
                return "TestFlight/Sandbox (path)"
            }
        }
        return "Production/App Store"
        #endif
    }

    private func handleStoreKitError(_ error: StoreKitError) -> String {
        switch error {
        case .unknown:
            return "Unknown StoreKit error. Check App Store Connect configuration."
        case .userCancelled:
            return "Request was cancelled."
        case .networkError(let underlyingError):
            return "Network error: \(underlyingError.localizedDescription). Check internet connection."
        case .systemError(let underlyingError):
            return "System error: \(underlyingError.localizedDescription)"
        case .notAvailableInStorefront:
            return "Products not available in your region. Check App Store Connect territories."
        case .notEntitled:
            return "Not entitled to access these products."
        case .unsupported:
            return "This device is not capable of making payments."
        @unknown default:
            return "Unexpected StoreKit error: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase Product

    func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        errorMessage = nil

        debugLogger.logPurchaseAttempt(productID: product.id)

        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Check if the transaction is verified
                let transaction = try checkVerified(verification)

                // Update purchased products and sync with SubscriptionManager
                await updatePurchasedProducts()
                await SubscriptionManager.shared.refreshSubscriptionFromStoreKit()

                // Finish the transaction after we've updated our state
                await transaction.finish()

                debugLogger.logPurchaseSuccess(productID: product.id)
                return transaction

            case .userCancelled:
                debugLogger.logPurchaseCancelled()
                return nil

            case .pending:
                // Transaction is pending approval (Ask to Buy, SCA, etc.)
                // It will appear in Transaction.updates when approved
                debugLogger.log(.info, "Purchase pending approval", details: product.id)
                return nil

            @unknown default:
                debugLogger.log(.warning, "Unknown purchase result", details: product.id)
                return nil
            }
        } catch {
            debugLogger.logPurchaseFailed(productID: product.id, error: error)
            throw error
        }
    }

    // MARK: - Restore Purchase

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        debugLogger.logRestoreAttempt()

        do {
            // AppStore.sync() forces the app to get fresh transaction data from the App Store
            // This satisfies App Store Review Guidelines section 3.1.1 requirement for restore mechanism
            try await AppStore.sync()
            await updatePurchasedProducts()
            debugLogger.logRestoreSuccess(productIDs: purchasedProductIDs)
        } catch {
            errorMessage = "Failed to restore purchase: \(error.localizedDescription)"
            debugPrint("Failed to restore purchase: \(error)")
            debugLogger.logRestoreFailed(error)
        }

        isLoading = false
    }

    // MARK: - Check Subscription Status

    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        var expirationDate: Date?
        var inTrial = false
        var autoRenew = false  // Default to false, will be set to true if we find an active subscription
        var eligibleForIntro = true
        var currentProduct: String?

        // Use Product.SubscriptionInfo.status for accurate current subscription detection
        // This is more reliable than Transaction.currentEntitlements for determining the CURRENT plan
        if let subscriptionProduct = products.first(where: { $0.subscription != nil }),
           let subscription = subscriptionProduct.subscription {
            do {
                let statuses = try await subscription.status

                for status in statuses {
                    // Only process active subscription states
                    guard status.state == .subscribed || status.state == .inGracePeriod || status.state == .inBillingRetryPeriod else {
                        debugLogger.log(.debug, "Skipping non-active status", details: "State: \(status.state)")
                        continue
                    }

                    // Verify the status components
                    let renewalInfo = try checkVerified(status.renewalInfo)
                    let transactionInfo = try checkVerified(status.transaction)

                    // The transaction's productID is the CURRENTLY active subscription
                    currentProduct = transactionInfo.productID
                    purchasedIDs.insert(transactionInfo.productID)

                    // Check if in trial period
                    if let offerType = transactionInfo.offer?.type {
                        inTrial = (offerType == .introductory)
                    }

                    // Get expiration date from the current transaction
                    if let expiration = transactionInfo.expirationDate {
                        expirationDate = expiration
                    }

                    // Check auto-renewal status
                    // renewalInfo.currentProductID shows what they'll renew to (could be different if they changed plans)
                    autoRenew = renewalInfo.willAutoRenew

                    debugLogger.log(.debug, "Found active subscription", details: "Product: \(transactionInfo.productID), AutoRenew: \(autoRenew), State: \(status.state), RenewalProduct: \(renewalInfo.currentProductID)")

                    // We found an active subscription, no need to continue
                    break
                }
            } catch {
                debugPrint("Failed to get subscription status: \(error)")
                debugLogger.log(.error, "Failed to get subscription status", details: error.localizedDescription)
            }
        }

        // Check intro offer eligibility on the user's current active subscription product
        // This must be done AFTER determining currentProduct to get accurate eligibility
        if let productID = currentProduct,
           let activeProduct = products.first(where: { $0.id == productID }),
           let subscription = activeProduct.subscription {
            eligibleForIntro = await subscription.isEligibleForIntroOffer
        } else if let anySubscriptionProduct = products.first(where: { $0.subscription != nil }),
                  let subscription = anySubscriptionProduct.subscription {
            // Fallback: If no current product (user not subscribed), check any subscription product
            eligibleForIntro = await subscription.isEligibleForIntroOffer
        }

        // Fallback: If we didn't find status via subscription.status, check currentEntitlements
        if currentProduct == nil {
            for await result in Transaction.currentEntitlements {
                do {
                    let transaction = try checkVerified(result)

                    if transaction.revocationDate == nil {
                        purchasedIDs.insert(transaction.productID)

                        // Only set as current if we don't have one yet
                        if currentProduct == nil {
                            currentProduct = transaction.productID
                        }
                    }
                } catch {
                    debugPrint("Failed to verify transaction: \(error)")
                }
            }
        }

        // StoreKit is the source of truth - always trust its response
        // If it returns empty, that means no active subscription
        self.purchasedProductIDs = purchasedIDs
        self.currentProductID = currentProduct
        self.isInTrialPeriod = inTrial
        self.subscriptionExpirationDate = expirationDate
        self.willAutoRenew = autoRenew
        self.isEligibleForIntroOffer = eligibleForIntro

        print("📊 Subscription Status:")
        print("   Active: \(!purchasedIDs.isEmpty)")
        print("   Current Product: \(currentProduct ?? "None")")
        print("   Trial: \(inTrial)")
        print("   Expiration: \(expirationDate?.formatted() ?? "N/A")")
        print("   Auto-Renew: \(autoRenew)")
        print("   Eligible for Intro Offer: \(eligibleForIntro)")

        // Log subscription status to debug logger
        let statusDetails = "Active: \(!purchasedIDs.isEmpty), Trial: \(inTrial), Auto-Renew: \(autoRenew)"
        debugLogger.log(.debug, "Subscription status updated", details: statusDetails)
    }

    // MARK: - Transaction Verification

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Transaction Listener

    /// Listen for transaction updates that happen outside the app
    /// This includes: renewals, cancellations, billing issues, Ask to Buy approvals,
    /// and purchases made on other devices
    private func listenForTransactions() -> Task<Void, Never> {
        return Task(priority: .background) { [weak self] in
            // Iterate through any pending/new transactions
            for await verificationResult in Transaction.updates {
                guard let self = self else { return }

                do {
                    // Only process verified transactions
                    let transaction = try self.checkVerified(verificationResult)

                    // Update our purchased products state
                    await self.updatePurchasedProducts()

                    // Notify SubscriptionManager to sync state and update widget
                    await SubscriptionManager.shared.refreshSubscriptionFromStoreKit()

                    // Finish the transaction only after successful processing
                    await transaction.finish()

                    debugPrint("✅ Transaction update processed: \(transaction.productID)")
                } catch {
                    // Transaction failed verification - log but don't finish
                    // Unverified transactions could be from jailbroken devices
                    debugPrint("❌ Transaction verification failed: \(error)")
                    self.debugLogger.log(.error, "Transaction update verification failed", details: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Helper Methods

    var hasActiveSubscription: Bool {
        !purchasedProductIDs.isEmpty
    }

    /// Returns the currently active subscription product
    var currentProduct: Product? {
        guard let productID = currentProductID else { return nil }
        return products.first { $0.id == productID }
    }

    var monthlyProduct: Product? {
        products.first { $0.id.contains("monthly") }
    }

    var yearlyProduct: Product? {
        products.first { $0.id.contains("yearly") }
    }

    func savingsPercentage() -> Int? {
        guard let monthly = monthlyProduct,
              let yearly = yearlyProduct else {
            print("⚠️ Cannot calculate savings: monthly or yearly product missing")
            return nil
        }

        let monthlyYearlyCost = monthly.price * 12
        let savings = monthlyYearlyCost - yearly.price

        // Convert to NSDecimalNumber for proper division
        let savingsNumber = NSDecimalNumber(decimal: savings)
        let costNumber = NSDecimalNumber(decimal: monthlyYearlyCost)

        // Perform division and multiply by 100 for percentage
        let percentageDecimal = savingsNumber.dividing(by: costNumber).multiplying(by: 100)
        let percentageInt = percentageDecimal.rounding(accordingToBehavior: NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )).intValue

        return percentageInt
    }
}

// MARK: - SKPaymentTransactionObserver (StoreKit 1)

/// Required for handling App Store promoted in-app purchases
/// When a user taps on a promoted IAP on the App Store product page,
/// this observer allows the app to handle the purchase flow
extension StoreKitManager: SKPaymentTransactionObserver {

    /// Called when transactions are updated
    /// For StoreKit 2, we handle most transactions through Transaction.updates,
    /// but this is still needed for promoted in-app purchases
    nonisolated func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        // StoreKit 2 handles most transaction processing through Transaction.updates
        // This method is primarily here for the shouldAddStorePayment callback to work
        // We don't need to process transactions here since StoreKit 2 will handle them
    }

    /// Called when a user initiates an in-app purchase from the App Store
    /// Return true to continue the purchase immediately
    /// Return false to defer the purchase to a later time
    nonisolated func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        // Return true to allow the purchase to proceed immediately
        // The transaction will be processed through StoreKit 2's Transaction.updates
        //
        // If you need to defer the purchase (e.g., show a custom paywall first),
        // return false and manually add the payment later:
        // SKPaymentQueue.default().add(payment)
        return true
    }
}

// MARK: - Store Errors

enum StoreError: Error {
    case failedVerification
}
