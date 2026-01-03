import SwiftUI
import UIKit

// MARK: - FAQ Data Models

struct FaqItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let content: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FaqItem, rhs: FaqItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct FaqSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [FaqItem]
}

// MARK: - FAQ Data

enum FaqData {

    // MARK: - Subscription FAQs

    static let subscriptionFaqs: [FaqItem] = [
        FaqItem(
            title: "I need more details about the subscription",
            content: """
            **The general details about the billing timelines are as follows**:

            • You can subscribe to a yearly plan (billed once a year), and a monthly plan (billed once a month). The availability and pricing of subscription plans may vary.
            • The payment will be charged to your Apple ID Account when you confirm the purchase.
            • The subscription automatically renews for the same price and duration period as the original one monthly/yearly plan, unless canceled at least 24 hours before the end of the current period.
            • Free trial automatically converts to a paid subscription, unless canceled at least 24 hours before the end of the trial period. From that point onwards, subscription automatically renews, unless canceled at least 24 hours before the end of the current period.
            """
        ),
        FaqItem(
            title: "How do I cancel a subscription?",
            content: """
            **To cancel a subscription or a free trial on your iPhone, follow these steps**:

            1. Open the **Settings app**.
            2. Tap your name.
            3. Tap **Subscriptions**.
            4. Tap on **Joodle**.
            5. Tap **Cancel Subscription**. You might need to scroll down to find the Cancel Subscription button. The subscription is already cancelled if there is no Cancel button or you see an expiration message in red text.

            Do it at least 24 hours before the end of the free trial or subscription period to avoid being charged. Any unused portion of a free trial period will be forfeited when the user purchases a Joodle subscription.

            **How to request a refund**:

            1. Go to https://support.apple.com/billing
            2. Tap on **Start a refund request**.
            """
        ),
        FaqItem(
            title: "I want to share the Joodle subscription with my family",
            content: """
            With Family Sharing, you and up to five other family members can share access to Joodle Pro.

            Only Joodle Pro Yearly subscription is eligible for Family Sharing.

            **How to set up Family Sharing**:

            1. Open the **Settings app**.
            2. Tap your name.
            3. Tap **Family Sharing**, then tap **Set Up Your Family**.
            4. Follow the onscreen instructions to set up your family and invite your family members.

            Joodle Pro subscription sometimes isn't enabled by default.

            **If this is the case, follow these steps**:

            1. Open the Joodle app.
            2. Go to **Settings**.
            3. Scroll down until you see **Unlock Joodle Pro** and tap it.
            4. Tap **Restore Purchase** below the subscribe slider.

            A connection with your iCloud account can be unstable. If this happens, sign out of your iCloud account on all included devices, sign back in, and try again.
            """
        ),
        FaqItem(
            title: "What features are included in Joodle Pro?",
            content: """
            **Joodle Pro unlocks the full Joodle experience**:

            • **Unlimited Joodles** - Create as many daily entries as you want (free plan limited to 30)
            • **iCloud Sync** - Keep your Joodles in sync across all your Apple devices
            • **Home Screen Widgets** - Add beautiful widgets to see your Joodles at a glance
            • **Unlimited Anniversary Alarms** - Set alarms for special days (free plan limited to 5)
            • **All Theme Colors** - Access to the complete color palette
            • **Watermark-Free Sharing** - Share your Joodle cards without the watermark

            You can try Joodle Pro free for 7 days before being charged.
            """
        )
    ]

    // MARK: - iCloud Sync FAQs

    static let iCloudSyncFaqs: [FaqItem] = [
        FaqItem(
            title: "How do I enable iCloud Sync?",
            content: """
            **To enable iCloud Sync, you need to**:

            1. Subscribe to **Joodle Pro** (iCloud Sync is a premium feature)
            2. Make sure you're signed into iCloud on your device
            3. Enable iCloud for Joodle in your device's **Settings → [Your Name] → iCloud → Saved to iCloud → Joodle**
            4. Enable sync in the Joodle app under **Settings → General → iCloud Sync**

            **Important**: Both the system iCloud toggle and the in-app toggle must be enabled for sync to work.

            After enabling sync, you may need to restart the app for changes to take effect.
            """
        ),
        FaqItem(
            title: "My Joodles aren't syncing across devices",
            content: """
            **If your Joodles aren't appearing on other devices, try these steps**:

            1. **Check your subscription** - iCloud Sync requires Joodle Pro
            2. **Verify iCloud is enabled** - Go to device Settings → [Your Name] → iCloud → Saved to iCloud → Joodle must be ON
            3. **Check network connection** - Sync requires an active internet connection
            4. **Same Apple ID** - Ensure all devices are signed into the same iCloud account
            5. **Allow time** - iCloud sync may take a few minutes to propagate changes
            6. **Restart the app** - Sometimes a fresh start helps

            **If sync was working before but stopped**:

            Try signing out of iCloud on all devices, signing back in, and reopening Joodle.

            **Note**: Joodle cannot control when Apple's iCloud servers sync data. If you've just made changes, please allow a few minutes for them to appear on other devices.
            """
        ),
        FaqItem(
            title: "Will I lose my data if I reinstall the app?",
            content: """
            **If you have iCloud Sync enabled**: Your Joodles are safely stored in iCloud and will automatically download when you reinstall the app and sign into the same iCloud account.

            **If you don't have iCloud Sync enabled**: Your Joodles are stored only on your device. Reinstalling the app will delete your data unless you create a backup first.

            **To create a backup**:

            1. Go to **Settings** in Joodle
            2. Tap **General → Backup & Restore**
            3. Tap **Backup Locally**
            4. Save the backup file to a safe location

            You can restore from this backup using the **Restore From Local Backup** option after reinstalling.
            """
        ),
        FaqItem(
            title: "Why do I need to restart the app after enabling sync?",
            content: """
            Joodle uses Apple's SwiftData with CloudKit for syncing your data securely. Due to how Apple's sync technology works, the sync configuration is set when the app launches.

            **When you change sync settings**, the app needs to restart to apply the new configuration properly. This ensures:

            • Your data syncs reliably
            • No conflicts occur between local and cloud data
            • The sync connection is established correctly

            This is a one-time restart whenever you toggle sync on or off. After that, syncing happens automatically in the background.
            """
        )
    ]

    // MARK: - Getting Started FAQs

    static let gettingStartedFaqs: [FaqItem] = [
        FaqItem(
            title: "How do I create a new Joodle?",
            content: """
            **Creating a Joodle is simple**:

            1. Open the app - you'll see the year grid view
            2. Tap on any day (dot) to select it
            3. Tap the **scribble icon** to open the drawing canvas
            4. Draw your Joodle using your finger
            5. Tap **tick** to save

            You can also add text notes to any day by tapping the selected day and typing in the text field.

            **Tip**: Try the scrubbing gesture! Press and hold on the grid, then drag your finger across days to quickly browse through your entries.
            """
        ),
        FaqItem(
            title: "How do I navigate between years?",
            content: """
            **Year Selector**
            • Tap the year shown at the top left corner of the screen
            • Select the year you want to view
            """
        ),
        FaqItem(
            title: "How do I set anniversary alarms?",
            content: """
            **Anniversary alarm notifies you on your special day**:

            1. Navigate to a future day you want to be reminded
            2. Add a drawing or note to that day
            3. Tap the **alarm icon** in the header
            4. Set the time you'd like to be reminded
            5. Tap **Set Alarm**

            You'll receive a notification on that day at the specific time you set.

            **Note**: Free users can set up to 5 alarms. Joodle Pro subscribers get unlimited alarms.

            **To manage alarms**: You can view and delete your alarms by tapping on the **alarm icon** from individual day entry.
            """
        ),
        FaqItem(
            title: "Can I edit or delete a Joodle?",
            content: """
            **To edit a Joodle**:

            1. Tap on the day entry you want to edit
            2. Tap the **scribble icon** to modify the drawing
            3. Or tap in the text area to edit your note

            **To clear a drawing**:

            1. Open the drawing canvas
            2. Tap the **trash icon** to clear the canvas

            **To delete text**: Simply select and delete the text in the text field.

            **Note**: Free users can only edit their first 30 Joodles. Joodle Pro removes this limitation.
            """
        ),
        FaqItem(
            title: "What is the scrubbing gesture?",
            content: """
            **Scrubbing is a quick way to browse your Joodles with haptic feedback**:

            1. Press and hold down on any day entry on the grid
            2. Keep your finger pressed and drag across the dots
            3. As you move, you'll see a preview of each day's Joodle in the header
            4. Release your finger to select that day

            This gesture lets you quickly scan through an entire year of entries without tapping each day individually.

            **Tip**: Haptic feedback helps you feel when you move to a new day. You can toggle haptics on/off in Settings → General → Interactions.
            """
        )
    ]

    // MARK: - Widgets FAQs

    static let widgetsFaqs: [FaqItem] = [
        FaqItem(
            title: "How do I add Joodle widgets to my Home Screen?",
            content: """
            **To add a Joodle widget**:

            1. Long press on your Home Screen until apps start wiggling
            2. Tap the **+** button in the top corner
            3. Search for **Joodle**
            4. Choose a widget style and size
            5. Tap **Add Widget**
            6. Position the widget where you want it
            7. Tap **Done**

            **Available widgets**:

            • **Today** - Shows today's Joodle
            • **Random Doodle** - Shows a random Joodle from your collection
            • **Anniversary** - Countdown to your next anniversary day
            • **Year Grid** - A mini view of your year's Joodles

            **Note**: Widgets are a Joodle Pro feature. Free users will see a locked widget prompting them to upgrade.
            """
        ),
        FaqItem(
            title: "Why isn't my widget updating?",
            content: """
            **If your widget shows outdated content, try these steps**:

            1. **Open the Joodle app** - Widgets update when the app is opened
            2. **Wait a few minutes** - iOS updates widgets periodically, not instantly
            3. **Remove and re-add** - Long press the widget → Remove Widget, then add it again

            **How widget updates work**:

            • Widgets refresh automatically when you open Joodle
            • iOS manages widget refresh timing to save battery
            • The Random Doodle widget shows a different Joodle each day
            • Different widget sizes may show different random selections

            **Note**: iOS limits how often widgets can refresh. This is an Apple limitation to preserve battery life.
            """
        ),
        FaqItem(
            title: "Can I choose which Joodle appears in the widget?",
            content: """
            **Currently, widgets display content automatically. You can only choose Joodle for Anniversary widgets**:

            To choose a specific Joodle for your Anniversary widget, follow these steps:

            1. Long press on the Anniversary widget.
            2. Select **Edit Widget**.
            3. Choose the desired Joodle from the list. Choose "Random" to allow the widget to display a random Anniversary Joodle.

            Now, your chosen Joodle will appear in the Anniversary widget.
            """
        )
    ]

    // MARK: - Sharing FAQs

    static let sharingFaqs: [FaqItem] = [
        FaqItem(
            title: "How do I share my Joodle?",
            content: """
            **To share a Joodle as a beautiful card**:

            1. Navigate to the day you want to share
            2. Make sure it has a drawing or note
            3. Tap the **share icon** (↑) in the header
            4. Swipe left/right to browse different card styles
            5. Tap **Share Card**
            6. Choose where to share (Messages, Instagram, Save to Photos, etc.)

            **Available card styles**:

            • **Minimal** - Only the Joodle is shown
            • **Excerpt** - Joodle and a short excerpt of the note are shown
            • **Detailed** - Joodle and a long excerpt of the note are shown
            • **Anniversary** - Only available for Anniversary day, shows the Joodle and the countdown to the date.

            Each style supports both light and dark modes. You can toggle it from bottom left corner of the share screen.
            """
        ),
        FaqItem(
            title: "How do I remove the watermark from shared cards?",
            content: """
            **Free users see a small Joodle watermark on shared cards.**

            To remove the watermark:

            1. Subscribe to **Joodle Pro**
            2. When sharing, you can toggle off the watermark above the share button.
            """
        ),
    ]

    // MARK: - Reminders FAQs

    static let remindersFaqs: [FaqItem] = [
        FaqItem(
            title: "Why am I not receiving anniversary alarm notifications?",
            content: """
            **If your anniversary alarms aren't working, check these settings**:

            1. **System notifications must be enabled**:
               • Go to **Settings** (iOS) → **Notifications** → **Joodle**
               • Make sure **Allow Notifications** is turned ON
               • Ensure **Lock Screen**, **Notification Center**, and **Banners** are enabled

            2. **Focus Mode may be blocking notifications**:
               • Check if Do Not Disturb or a Focus mode is active
               • Add Joodle to your Focus mode's allowed apps if needed

            3. **Notification permission was denied**:
               • If you denied permission when first asked, you need to enable it manually in iOS Settings

            **To re-enable notifications**:

            1. Open the **Settings app** on your device
            2. Scroll down and tap **Joodle**
            3. Tap **Notifications**
            4. Toggle **Allow Notifications** ON
            """
        ),
        FaqItem(
            title: "How do I delete an anniversary alarm?",
            content: """
            **To remove an anniversary alarm**:

            1. Navigate to the day with the alarm
            2. Tap the **alarm icon** in the header
            3. You'll see your existing alarm
            4. Tap **Clear** on the top right corner

            The alarm will be removed and you won't receive notifications for that date anymore.

            **Note**: Deleting a alarm doesn't delete the Joodle itself - your drawing and notes remain safe. If you delete the Joodle, any existing alarm will also be removed.
            """
        ),
        FaqItem(
            title: "Can I change the time of an anniversary alarm?",
            content: """
            **To change when you receive an anniversary alarm notification**:

            1. Navigate to the day with the existing alarm
            2. Tap the **alarm icon** in the header
            3. Adjust the time picker to your preferred time
            4. Tap **Update Alarm**

            The alarm will now notify you at the new time on that anniversary date.
            """
        )
    ]

    // MARK: - All Sections

    static let allSections: [FaqSection] = [
        FaqSection(title: "Subscription", items: subscriptionFaqs),
        FaqSection(title: "iCloud Sync", items: iCloudSyncFaqs),
        FaqSection(title: "Getting Started", items: gettingStartedFaqs),
        FaqSection(title: "Anniversary Alarms", items: remindersFaqs),
        FaqSection(title: "Widgets", items: widgetsFaqs),
        FaqSection(title: "Sharing", items: sharingFaqs)
    ]
}

// MARK: - FAQ List View

struct FaqView: View {
    @Environment(\.dismiss) private var dismiss

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
            ForEach(FaqData.allSections) { section in
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

                Text(LocalizedStringKey(item.content))
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FaqView()
    }
}

#Preview("FAQ Detail") {
    NavigationStack {
        FaqDetailView(
            sectionTitle: "Subscription",
            items: FaqData.subscriptionFaqs,
            initialIndex: 0
        )
    }
}
