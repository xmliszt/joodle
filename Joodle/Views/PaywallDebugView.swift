//
//  PaywallDebugView.swift
//  Joodle
//
//  Debug view for troubleshooting StoreKit issues in TestFlight builds
//

import SwiftUI

struct PaywallDebugView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var logger: PaywallDebugLogger
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var showCopiedAlert = false
    @State private var showShareSheet = false
    @State private var logsToShare = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary Card
                summaryCard
                    .padding()

                Divider()

                // Log List
                if logger.logEntries.isEmpty {
                    ContentUnavailableView(
                        "No Logs Yet",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Debug logs will appear here as StoreKit events occur.")
                    )
                } else {
                    logsList
                }
            }
            .navigationTitle("Paywall Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task {
                                await storeManager.loadProducts()
                            }
                        } label: {
                            Label("Reload Products", systemImage: "arrow.clockwise")
                        }

                        Button {
                            logsToShare = logger.exportLogs()
                            showShareSheet = true
                        } label: {
                            Label("Share Logs", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            UIPasteboard.general.string = logger.exportLogs()
                            showCopiedAlert = true
                        } label: {
                            Label("Copy Logs", systemImage: "doc.on.doc")
                        }

                        Divider()

                        Button(role: .destructive) {
                            logger.clearLogs()
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Copied!", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Debug logs have been copied to clipboard.")
            }
            .sheet(isPresented: $showShareSheet) {
                DebugShareSheet(items: [logsToShare])
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Diagnostic Summary")
                    .font(.headline)
                Spacer()

                // Status indicator
                statusBadge
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "Environment", value: getEnvironment())
                infoRow(label: "Products Loaded", value: "\(storeManager.products.count)")
                infoRow(label: "Is Loading", value: storeManager.isLoading ? "Yes" : "No")
                infoRow(label: "Has Subscription", value: storeManager.hasActiveSubscription ? "Yes" : "No")

                if let error = storeManager.errorMessage {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Error:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var statusBadge: some View {
        let hasError = storeManager.errorMessage != nil || storeManager.products.isEmpty
        let isLoading = storeManager.isLoading

        return HStack(spacing: 4) {
            Circle()
                .fill(isLoading ? .orange : (hasError ? .red : .green))
                .frame(width: 8, height: 8)

            Text(isLoading ? "Loading..." : (hasError ? "Issues Found" : "OK"))
                .font(.caption)
                .foregroundColor(isLoading ? .orange : (hasError ? .red : .green))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((isLoading ? Color.orange : (hasError ? Color.red : Color.green)).opacity(0.1))
        )
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .foregroundColor(.primary)
        }
    }

    private func getEnvironment() -> String {
        #if DEBUG
        return "DEBUG"
        #else
        if let receiptURL = Bundle.main.appStoreReceiptURL,
           receiptURL.lastPathComponent == "sandboxReceipt" {
            return "TestFlight"
        }
        return "Production"
        #endif
    }

    // MARK: - Logs List

    private var logsList: some View {
        List {
            ForEach(logger.logEntries.reversed()) { entry in
                logRow(entry)
            }
        }
        .listStyle(.plain)
    }

    private func logRow(_ entry: PaywallDebugLogger.LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.level.rawValue)
                    .font(.caption)

                Text(entry.formattedTimestamp)
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)

                Spacer()
            }

            Text(entry.message)
                .font(.caption)
                .foregroundColor(entry.level.color)

            if let details = entry.details {
                Text(details)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Debug Share Sheet

struct DebugShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Debug Gesture Modifier

/// A view modifier that adds a hidden triple-tap gesture to show the debug view
/// Only active in DEBUG builds - no-op in release builds
struct PaywallDebugGestureModifier: ViewModifier {
    #if DEBUG
    @ObservedObject var logger = PaywallDebugLogger.shared
    @State private var showDebugView = false
    @State private var tapCount = 0
    @State private var lastTapTime = Date.distantPast

    func body(content: Content) -> some View {
        content
            .onTapGesture(count: 3) {
                showDebugView = true
            }
            .sheet(isPresented: $showDebugView) {
                PaywallDebugView(logger: logger)
            }
    }
    #else
    func body(content: Content) -> some View {
        content
    }
    #endif
}

extension View {
    /// Adds a hidden debug gesture (triple tap) to show the paywall debug view
    /// Only active in DEBUG builds - no-op in release builds
    func paywallDebugGesture() -> some View {
        modifier(PaywallDebugGestureModifier())
    }
}

#Preview {
    PaywallDebugView(logger: PaywallDebugLogger.shared)
}
