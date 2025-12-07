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

    private let productIDs: [String] = [
        "dev.liyuxuan.joodle.super.monthly",
        "dev.liyuxuan.joodle.super.yearly"
    ]

    private var updateListenerTask: Task<Void, Error>?

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

        print("📦 StoreKit: Loading products for IDs: \(productIDs)")

        do {
            let loadedProducts = try await Product.products(for: productIDs)
            print("📦 StoreKit: Loaded \(loadedProducts.count) products")

            for product in loadedProducts {
                print("📦 Product: \(product.id)")
                print("   💰 Display Name: \(product.displayName)")
                print("   💰 Display Price: \(product.displayPrice)")
                print("   💰 Raw Price: \(product.price)")
                print("   💰 Currency Code: \(product.priceFormatStyle.currencyCode)")
                print("   🌍 Locale: \(product.priceFormatStyle.locale.identifier)")
            }

            self.products = loadedProducts.sorted { product1, product2 in
                // Sort monthly first, then yearly
                if product1.id.contains("monthly") {
                    return true
                }
                return false
            }

            if loadedProducts.isEmpty {
                errorMessage = "No products found. Make sure StoreKit Configuration is selected in scheme."
                print("⚠️ StoreKit: No products loaded. Check scheme settings.")
            }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("❌ StoreKit Error: \(error)")
            print("❌ Make sure 'SyncedProducts.storekit' is selected in Edit Scheme → Run → Options → StoreKit Configuration")
        }

        isLoading = false
    }

    // MARK: - Purchase Product

    func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Check if the transaction is verified
            let transaction = try checkVerified(verification)

            // Update purchased products
            await updatePurchasedProducts()

            // Finish the transaction
            await transaction.finish()

            return transaction

        case .userCancelled:
            return nil

        case .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            debugPrint("Failed to restore purchases: \(error)")
        }

        isLoading = false
    }

    // MARK: - Check Subscription Status

    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if the subscription is still active
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                debugPrint("Failed to verify transaction: \(error)")
            }
        }

        self.purchasedProductIDs = purchasedIDs
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
        let percentage = (savings / monthlyYearlyCost) * 100

        let percentageInt = NSDecimalNumber(decimal: percentage).intValue

        print("💵 Savings Calculation:")
        print("   Monthly: \(monthly.displayPrice) (\(monthly.price))")
        print("   Yearly: \(yearly.displayPrice) (\(yearly.price))")
        print("   Monthly x12: \(monthlyYearlyCost)")
        print("   Savings: \(savings)")
        print("   Percentage: \(percentageInt)%")

        return percentageInt
    }
}

// MARK: - Store Errors

enum StoreError: Error {
    case failedVerification
}
