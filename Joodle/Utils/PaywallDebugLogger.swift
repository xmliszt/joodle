//
//  PaywallDebugLogger.swift
//  Joodle
//
//  Debug logging utility for StoreKit troubleshooting in TestFlight builds
//

import Foundation
import SwiftUI

/// A debug logger that captures StoreKit-related events and errors
/// for troubleshooting in TestFlight builds where console logs aren't accessible
@MainActor
final class PaywallDebugLogger: ObservableObject {
    static let shared = PaywallDebugLogger()

    /// Maximum number of log entries to keep
    private let maxLogEntries = 100

    /// Published log entries for UI display
    @Published private(set) var logEntries: [LogEntry] = []

    /// Whether debug mode is enabled (can be toggled via hidden gesture)
    @Published var isDebugModeEnabled = false

    private init() {
        log(.info, "PaywallDebugLogger initialized")
        logEnvironmentInfo()
    }

    // MARK: - Log Entry Model

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let message: String
        let details: String?

        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }
    }

    enum LogLevel: String {
        case info = "ℹ️"
        case success = "✅"
        case warning = "⚠️"
        case error = "❌"
        case debug = "🔍"

        var color: Color {
            switch self {
            case .info: return .secondary
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .debug: return .purple
            }
        }
    }

    // MARK: - Logging Methods

    func log(_ level: LogLevel, _ message: String, details: String? = nil) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            details: details
        )

        logEntries.append(entry)

        // Trim old entries if needed
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }

        // Also print to console for Xcode debugging
        let detailsText = details.map { " | \($0)" } ?? ""
        print("\(level.rawValue) [Paywall] \(message)\(detailsText)")
    }

    func logProductsLoading() {
        log(.info, "Loading products...")
    }

    func logProductsLoaded(count: Int, productIDs: [String]) {
        if count > 0 {
            log(.success, "Loaded \(count) products", details: productIDs.joined(separator: ", "))
        } else {
            log(.warning, "No products loaded", details: "Expected: dev.liyuxuan.joodle.super.monthly, dev.liyuxuan.joodle.super.yearly")
        }
    }

    func logProductDetails(id: String, displayName: String, price: String) {
        log(.debug, "Product: \(id)", details: "\(displayName) - \(price)")
    }

    func logStoreKitError(_ error: Error, context: String) {
        let errorType = String(describing: type(of: error))
        let errorDescription = error.localizedDescription
        log(.error, "\(context): \(errorType)", details: errorDescription)
    }

    func logPurchaseAttempt(productID: String) {
        log(.info, "Purchase attempt", details: productID)
    }

    func logPurchaseSuccess(productID: String) {
        log(.success, "Purchase successful", details: productID)
    }

    func logPurchaseFailed(productID: String, error: Error) {
        log(.error, "Purchase failed for \(productID)", details: error.localizedDescription)
    }

    func logPurchaseCancelled() {
        log(.info, "Purchase cancelled by user")
    }

    func logRestoreAttempt() {
        log(.info, "Restoring purchases...")
    }

    func logRestoreSuccess(productIDs: Set<String>) {
        if productIDs.isEmpty {
            log(.warning, "Restore complete - no active subscriptions found")
        } else {
            log(.success, "Restore successful", details: productIDs.joined(separator: ", "))
        }
    }

    func logRestoreFailed(_ error: Error) {
        log(.error, "Restore failed", details: error.localizedDescription)
    }

    // MARK: - Environment Info

    private func logEnvironmentInfo() {
        let environment = getEnvironment()
        log(.info, "Environment: \(environment)")

        let bundleID = Bundle.main.bundleIdentifier ?? "Unknown"
        log(.debug, "Bundle ID: \(bundleID)")

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        log(.debug, "App Version: \(version) (\(build))")

        log(.debug, "Device: \(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)")
    }

    private func getEnvironment() -> String {
        #if DEBUG
        return "DEBUG (Xcode)"
        #else
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

    // MARK: - Utility Methods

    func clearLogs() {
        logEntries.removeAll()
        log(.info, "Logs cleared")
        logEnvironmentInfo()
    }

    func exportLogs() -> String {
        var output = "=== Joodle Paywall Debug Logs ===\n"
        output += "Exported: \(Date().formatted())\n"
        output += "================================\n\n"

        for entry in logEntries {
            output += "[\(entry.formattedTimestamp)] \(entry.level.rawValue) \(entry.message)"
            if let details = entry.details {
                output += "\n    Details: \(details)"
            }
            output += "\n"
        }

        return output
    }

    /// Returns a summary of the current state for quick diagnostics
    var diagnosticSummary: String {
        let environment = getEnvironment()
        let bundleID = Bundle.main.bundleIdentifier ?? "Unknown"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        let errorCount = logEntries.filter { $0.level == .error }.count
        let warningCount = logEntries.filter { $0.level == .warning }.count

        return """
        Environment: \(environment)
        Bundle ID: \(bundleID)
        Version: \(version) (\(build))

        Log Summary:
        - Total entries: \(logEntries.count)
        - Errors: \(errorCount)
        - Warnings: \(warningCount)

        Expected Product IDs:
        - dev.liyuxuan.joodle.super.monthly
        - dev.liyuxuan.joodle.super.yearly
        """
    }
}
