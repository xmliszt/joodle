//
//  StoreKitManager.swift
//  Joodle
//
//  Created by StoreKit Manager
//

import Foundation
import StoreKit

@MainActor
class StoreKitManager: ObservableObject {
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

    private let productIDs: [String] = [
        "dev.liyuxuan.joodle.super.monthly",
        "dev.liyuxuan.joodle.super.yearly"
    ]

    private var updateListenerTask: Task<Void, Error>?

    /// Debug logger for TestFlight troubleshooting
    private let debugLogger = PaywallDebugLogger.shared

    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
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

                // Update purchased products
                await updatePurchasedProducts()

                // Finish the transaction
                await transaction.finish()

                debugLogger.logPurchaseSuccess(productID: product.id)
                return transaction

            case .userCancelled:
                debugLogger.logPurchaseCancelled()
                return nil

            case .pending:
                debugLogger.log(.info, "Purchase pending", details: product.id)
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

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        debugLogger.logRestoreAttempt()

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            debugLogger.logRestoreSuccess(productIDs: purchasedProductIDs)
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            debugPrint("Failed to restore purchases: \(error)")
            debugLogger.logRestoreFailed(error)
        }

        isLoading = false
    }

    // MARK: - Check Subscription Status

    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        var expirationDate: Date?
        var inTrial = false
        var autoRenew = true
        var eligibleForIntro = true

        // Check intro offer eligibility using any subscription product
        if let subscriptionProduct = products.first(where: { $0.subscription != nil }),
           let subscription = subscriptionProduct.subscription {
            eligibleForIntro = await subscription.isEligibleForIntroOffer
        }

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if the subscription is still active
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)

                    // Get subscription status details
                    if let product = products.first(where: { $0.id == transaction.productID }),
                       let subscription = product.subscription {

                        // Check current subscription status
                        let statuses = try await subscription.status

                        for status in statuses {
                            // Verify the status
                            let renewalInfo = try checkVerified(status.renewalInfo)
                            let transactionInfo = try checkVerified(status.transaction)

                            // Check if in trial period
                          if let offerType = transactionInfo.offer?.type {
                                inTrial = (offerType == .introductory)
                            }

                            // Get expiration date
                            if let expiration = transactionInfo.expirationDate {
                                expirationDate = expiration
                            }

                            // Check auto-renewal status
                            autoRenew = renewalInfo.willAutoRenew
                        }
                    }
                }
            } catch {
                debugPrint("Failed to verify transaction: \(error)")
            }
        }

        self.purchasedProductIDs = purchasedIDs
        self.isInTrialPeriod = inTrial
        self.subscriptionExpirationDate = expirationDate
        self.willAutoRenew = autoRenew
        self.isEligibleForIntroOffer = eligibleForIntro

        print("📊 Subscription Status:")
        print("   Active: \(!purchasedIDs.isEmpty)")
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

    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction: Transaction
                    switch result {
                    case .unverified:
                        throw StoreError.failedVerification
                    case .verified(let safe):
                        transaction = safe
                    }

                    await self.updatePurchasedProducts()

                    // Notify SubscriptionManager to sync state and update widget
                    await SubscriptionManager.shared.updateSubscriptionStatus()

                    await transaction.finish()
                } catch {
                    debugPrint("Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Helper Methods

    var hasActiveSubscription: Bool {
        !purchasedProductIDs.isEmpty
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

// MARK: - Store Errors

enum StoreError: Error {
    case failedVerification
}
