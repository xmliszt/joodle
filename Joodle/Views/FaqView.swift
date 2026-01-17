import SwiftUI
import UIKit
import MarkdownUI

// MARK: - FAQ Data Models

struct FaqItem: Identifiable, Hashable {
    let id: String
    let title: String
    let content: String

    /// Convenience initializer for bundled data (auto-generates UUID-based ID)
    init(title: String, content: String) {
        self.id = UUID().uuidString
        self.title = title
        self.content = content
    }

    /// Initializer for remote data with explicit ID
    init(id: String, title: String, content: String) {
        self.id = id
        self.title = title
        self.content = content
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FaqItem, rhs: FaqItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct FaqSection: Identifiable {
    let id: String
    let title: String
    let items: [FaqItem]

    /// Convenience initializer for bundled data (auto-generates UUID-based ID)
    init(title: String, items: [FaqItem]) {
        self.id = UUID().uuidString
        self.title = title
        self.items = items
    }

    /// Initializer for remote data with explicit ID
    init(id: String, title: String, items: [FaqItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

// MARK: - FAQ List View

struct FaqView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var faqManager = FaqManager.shared

    private var deviceIdentifier: String {
        let vendorId = UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
        let appId = Bundle.main.bundleIdentifier ?? "Unknown"
        return "\(vendorId):\(appId)"
    }

    private var contactUsMailURL: URL? {
        let email = "joodle@liyuxuan.dev"
        let subject = "Feedback on Joodle"
        let iOSVersion = UIDevice.current.systemVersion
        let body = "\n\n\n\n\nJoodle \(AppEnvironment.fullVersionDisplayString) - iOS \(iOSVersion)\nID: \(deviceIdentifier)"

        let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        return URL(string: "mailto:\(email)?subject=\(subjectEncoded)&body=\(bodyEncoded)")
    }

    var body: some View {
        List {
            // Show error banner if there was an issue loading FAQs
            if let errorMessage = faqManager.errorMessage {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.secondary)
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            ForEach(faqManager.sections) { section in
                Section {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        NavigationLink {
                            FaqDetailView(
                                sectionTitle: section.title,
                                items: section.items,
                                initialIndex: index
                            )
                        } label: {
                            Text(item.title)
                                .foregroundColor(.primary)
                        }
                    }
                } header: {
                    Text(section.title)
                }
            }

            // For Everything Else section
            Section {
                if let mailURL = contactUsMailURL {
                    Link(destination: mailURL) {
                        HStack {
                            Text("Get In Touch With Us")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("For Everything Else")
            }
        }
        .navigationTitle("Frequently Asked Questions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Track FAQ screen viewed
            AnalyticsManager.shared.trackFAQViewed()
        }
        .refreshable {
            await faqManager.refresh()
        }
        .task {
            await faqManager.loadFaqs()
        }
    }
}

// MARK: - FAQ Detail View with Swipe Navigation

struct FaqDetailView: View {
    let sectionTitle: String
    let items: [FaqItem]
    let initialIndex: Int

    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    init(sectionTitle: String, items: [FaqItem], initialIndex: Int) {
        self.sectionTitle = sectionTitle
        self.items = items
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }

    private func trackCurrentQuestion() {
        guard currentIndex < items.count else { return }
        let item = items[currentIndex]
        AnalyticsManager.shared.trackFAQQuestionExpanded(
            questionId: item.id,
            questionTitle: item.title,
            category: sectionTitle
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    FaqContentView(item: item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom page indicator
            if items.count > 1 {
                HStack(spacing: 8) {
                    ForEach(0..<items.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.primary : Color.secondary.opacity(0.5))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 24)
                .padding(.top, 8)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(sectionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            trackCurrentQuestion()
        }
        .onChange(of: currentIndex) { _, _ in
            trackCurrentQuestion()
        }
    }
}

// MARK: - FAQ Content View

struct FaqContentView: View {
    let item: FaqItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Markdown(item.content)
                    .markdownTheme(.docC)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
