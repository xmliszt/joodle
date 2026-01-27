import Foundation
import PostHog

/// Centralized analytics manager for PostHog event tracking
///
/// **PostHog Autocapture (automatic, no action needed):**
/// - Application lifecycle events: Opened, Backgrounded, Installed, Updated
/// - Screen views: Use `.postHogScreenView()` modifier on SwiftUI views for automatic $screen events
/// - UIKit interactions: Automatically captured via $autocapture
///
/// **Custom events (defined here):**
/// - Business-critical user actions (e.g., entryCreated, subscriptionPurchased)
/// - Feature engagement (e.g., drawingCreated, shareCardShared)
/// - Use case: AnalyticsManager.shared.track(.eventName, properties: [...])
///
/// **Screen Tracking Best Practice:**
/// For SwiftUI apps, add the `.postHogScreenView()` modifier to full-screen views:
///   ```swift
///   ContentView()
///       .postHogScreenView("My Content View")
///   ```
/// This is preferred over manual screen tracking calls.
final class AnalyticsManager {
    static let shared = AnalyticsManager()

    private init() {}

    // MARK: - Event Definitions

    enum Event: String {
        // Onboarding
        case onboardingStepViewed = "onboarding_step_viewed"
        case onboardingCompleted = "onboarding_completed"
        case onboardingSkipped = "onboarding_skipped"
        case onboardingDrawingCreated = "onboarding_drawing_created"

        // Navigation & UI
        case viewModeChanged = "view_mode_changed"
        case yearChanged = "year_changed"
        case scrubbingUsed = "scrubbing_used"
        case pinchGestureUsed = "pinch_gesture_used"

        // Subscription
        case paywallViewed = "paywall_viewed"
        case paywallDismissed = "paywall_dismissed"
        case subscriptionStarted = "subscription_started"
        case subscriptionRestored = "subscription_restored"
        case subscriptionCancelled = "subscription_cancelled"
        case subscriptionExpired = "subscription_expired"
        case offerCodeRedeemed = "offer_code_redeemed"
        case restorePurchasesAttempted = "restore_purchases_attempted"
        case purchaseFailed = "purchase_failed"

        // Share Feature
        case shareCardOpened = "share_card_opened"
        case shareCardStyleSelected = "share_card_style_selected"
        case shareCardShared = "share_card_shared"
        case shareCardCancelled = "share_card_cancelled"

        // iCloud Sync
        case iCloudSyncEnabled = "icloud_sync_enabled"
        case iCloudSyncDisabled = "icloud_sync_disabled"
        case iCloudSyncStatusViewed = "icloud_sync_status_viewed"

        // Reminders
        case dailyReminderEnabled = "daily_reminder_enabled"
        case dailyReminderDisabled = "daily_reminder_disabled"
        case dailyReminderTimeChanged = "daily_reminder_time_changed"
        case anniversaryReminderCreated = "anniversary_reminder_created"
        case anniversaryReminderDeleted = "anniversary_reminder_deleted"

        // Settings
        case settingChanged = "setting_changed"
        case dataExported = "data_exported"
        case dataImported = "data_imported"
        case dataImportFailed = "data_import_failed"

        // Tutorials
        case tutorialStepViewed = "tutorial_step_viewed"
        case tutorialStepCompleted = "tutorial_step_completed"
        case tutorialCompleted = "tutorial_completed"
        case tutorialSkipped = "tutorial_skipped"

        // Help & Support
        case faqQuestionExpanded = "faq_question_expanded"
        case changelogViewed = "changelog_viewed"
        case externalLinkOpened = "external_link_opened"
        case contactUsOpened = "contact_us_opened"
        case reviewPromptShown = "review_prompt_shown"

        // Widgets
        case widgetDataUpdated = "widget_data_updated"
        case widgetTapped = "widget_tapped"

        // Theme & Appearance
        case themeColorChanged = "theme_color_changed"
        case colorSchemeChanged = "color_scheme_changed"

        // Deep Links & Navigation
        case deepLinkOpened = "deep_link_opened"
        case navigatedFromWidget = "navigated_from_widget"
        case navigatedFromNotification = "navigated_from_notification"
        case navigatedFromShortcut = "navigated_from_shortcut"

        // Remote Alerts
        case remoteAlertShown = "remote_alert_shown"
        case remoteAlertActionTaken = "remote_alert_action_taken"
        case remoteAlertDismissed = "remote_alert_dismissed"
    }

    // MARK: - Property Keys

    enum PropertyKey: String {
        // Common
        case screenName = "screen_name"
        case source = "source"
        case timestamp = "timestamp"

        // Entry
        case hasDrawing = "has_drawing"
        case hasText = "has_text"
        case isToday = "is_today"
        case isFuture = "is_future"
        case entryDate = "entry_date"
        case strokeCount = "stroke_count"
        case textLength = "text_length"

        // Onboarding
        case step = "step"
        case stepName = "step_name"
        case stepIndex = "step_index"

        // View Mode
        case viewMode = "view_mode"
        case previousViewMode = "previous_view_mode"
        case year = "year"
        case previousYear = "previous_year"

        // Subscription
        case productId = "product_id"
        case isTrial = "is_trial"
        case isOfferCode = "is_offer_code"
        case offerCodeId = "offer_code_id"
        case subscriptionType = "subscription_type"
        case errorMessage = "error_message"
        case paywallSource = "paywall_source"

        // Share
        case shareStyle = "share_style"
        case shareFormat = "share_format"
        case includesWatermark = "includes_watermark"
        case colorScheme = "color_scheme"

        // Settings
        case settingName = "setting_name"
        case settingValue = "setting_value"
        case previousValue = "previous_value"

        // Tutorial
        case tutorialStep = "tutorial_step"
        case tutorialName = "tutorial_name"
        case completionTime = "completion_time"

        // FAQ
        case questionId = "question_id"
        case questionTitle = "question_title"
        case category = "category"

        // Changelog
        case version = "version"

        // External Links
        case url = "url"
        case linkType = "link_type"

        // Widget
        case widgetType = "widget_type"
        case widgetFamily = "widget_family"

        // Theme
        case themeColor = "theme_color"

        // Error
        case errorType = "error_type"
        case errorContext = "error_context"

        // Feature
        case featureName = "feature_name"

        // Alert
        case alertId = "alert_id"
        case alertTitle = "alert_title"
        case actionType = "action_type"

        // Counts
        case entryCount = "entry_count"
        case reminderCount = "reminder_count"
    }

    // MARK: - Screen Names

    enum ScreenName: String {
        case home = "home"
        case settings = "settings"
        case iCloudSync = "icloud_sync"
        case customization = "customization"
        case dailyReminder = "daily_reminder"
        case backupRestore = "backup_restore"
        case interactions = "interactions"
        case anniversaryAlarms = "anniversary_alarms"
        case experimentalFeatures = "experimental_features"
        case subscriptions = "subscriptions"
        case paywall = "paywall"
        case shareCard = "share_card"
        case faq = "faq"
        case changelog = "changelog"
        case changelogDetail = "changelog_detail"
        case learnCoreFeatures = "learn_core_features"
        case tutorial = "tutorial"
        case entryEditing = "entry_editing"
        case drawingCanvas = "drawing_canvas"
        case reminderSheet = "reminder_sheet"
        case notePrompt = "note_prompt"

        // Onboarding screens
        case onboardingDrawing = "onboarding_drawing"
        case onboardingValueProp = "onboarding_value_prop"
        case onboardingTutorial = "onboarding_tutorial"
        case onboardingWidgets = "onboarding_widgets"
        case onboardingPaywall = "onboarding_paywall"
        case onboardingICloudConfig = "onboarding_icloud_config"
        case onboardingDailyReminder = "onboarding_daily_reminder"
        case onboardingCompletion = "onboarding_completion"
    }

    // MARK: - Tracking Methods

    /// Track an event with optional properties
    func track(_ event: Event, properties: [PropertyKey: Any]? = nil) {
        var props: [String: Any] = [:]

        if let properties = properties {
            for (key, value) in properties {
                props[key.rawValue] = value
            }
        }

        // Add common properties
        props["app_version"] = AppEnvironment.fullVersionString
        props["platform"] = "iOS"

        if props.isEmpty {
            PostHogSDK.shared.capture(event.rawValue)
        } else {
            PostHogSDK.shared.capture(event.rawValue, properties: props)
        }

        #if DEBUG
        print("📊 [Analytics] \(event.rawValue) - \(props)")
        #endif
    }


    // MARK: - Convenience Methods

    // MARK: Onboarding

    func trackOnboardingStep(_ stepName: String, stepIndex: Int) {
        track(.onboardingStepViewed, properties: [
            .stepName: stepName,
            .stepIndex: stepIndex
        ])
    }

    func trackOnboardingCompleted() {
        track(.onboardingCompleted)
    }

    func trackOnboardingSkipped(atStep stepName: String) {
        track(.onboardingSkipped, properties: [
            .stepName: stepName
        ])
    }

    // MARK: Navigation

    func trackViewModeChanged(to newMode: String, from previousMode: String) {
        track(.viewModeChanged, properties: [
            .viewMode: newMode,
            .previousViewMode: previousMode
        ])
    }

    func trackYearChanged(to year: Int, from previousYear: Int) {
        track(.yearChanged, properties: [
            .year: year,
            .previousYear: previousYear
        ])
    }

    func trackScrubbingUsed() {
        track(.scrubbingUsed)
    }

    func trackPinchGestureUsed(resultingMode: String) {
        track(.pinchGestureUsed, properties: [
            .viewMode: resultingMode
        ])
    }

    // MARK: Subscription

    func trackPaywallViewed(source: String) {
        track(.paywallViewed, properties: [
            .paywallSource: source
        ])
    }

    func trackPaywallDismissed(source: String, didPurchase: Bool) {
        track(.paywallDismissed, properties: [
            .paywallSource: source,
            .settingValue: didPurchase ? "purchased" : "dismissed"
        ])
    }

    func trackSubscriptionStarted(productId: String, isTrial: Bool, isOfferCode: Bool, offerCodeId: String? = nil) {
        var props: [PropertyKey: Any] = [
            .productId: productId,
            .isTrial: isTrial,
            .isOfferCode: isOfferCode
        ]
        if let offerCodeId = offerCodeId {
            props[.offerCodeId] = offerCodeId
        }
        track(.subscriptionStarted, properties: props)
    }

    func trackSubscriptionRestored(productId: String) {
        track(.subscriptionRestored, properties: [
            .productId: productId
        ])
    }

    func trackPurchaseFailed(productId: String, errorMessage: String) {
        track(.purchaseFailed, properties: [
            .productId: productId,
            .errorMessage: errorMessage
        ])
    }

    func trackRestorePurchasesAttempted(success: Bool) {
        track(.restorePurchasesAttempted, properties: [
            .settingValue: success ? "success" : "no_purchases_found"
        ])
    }

    // MARK: Share

    func trackShareCardOpened(hasDrawing: Bool, hasText: Bool) {
        track(.shareCardOpened, properties: [
            .hasDrawing: hasDrawing,
            .hasText: hasText
        ])
    }

    func trackShareCardStyleSelected(style: String) {
        track(.shareCardStyleSelected, properties: [
            .shareStyle: style
        ])
    }

    func trackShareCardShared(style: String, format: String, includesWatermark: Bool, colorScheme: String) {
        track(.shareCardShared, properties: [
            .shareStyle: style,
            .shareFormat: format,
            .includesWatermark: includesWatermark,
            .colorScheme: colorScheme
        ])
    }

    // MARK: iCloud Sync

    func trackICloudSyncEnabled() {
        track(.iCloudSyncEnabled)
    }

    func trackICloudSyncDisabled() {
        track(.iCloudSyncDisabled)
    }

    // MARK: Reminders

    func trackDailyReminderEnabled(time: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        track(.dailyReminderEnabled, properties: [
            .settingValue: formatter.string(from: time)
        ])
    }

    func trackDailyReminderDisabled() {
        track(.dailyReminderDisabled)
    }

    func trackDailyReminderTimeChanged(newTime: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        track(.dailyReminderTimeChanged, properties: [
            .settingValue: formatter.string(from: newTime)
        ])
    }

    func trackAnniversaryReminderCreated(forDate: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        track(.anniversaryReminderCreated, properties: [
            .entryDate: formatter.string(from: forDate)
        ])
    }

    func trackAnniversaryReminderDeleted() {
        track(.anniversaryReminderDeleted)
    }

    // MARK: Settings

    func trackSettingChanged(name: String, value: Any, previousValue: Any? = nil) {
        var props: [PropertyKey: Any] = [
            .settingName: name,
            .settingValue: "\(value)"
        ]
        if let previousValue = previousValue {
            props[.previousValue] = "\(previousValue)"
        }
        track(.settingChanged, properties: props)
    }

    func trackDataExported(entryCount: Int) {
        track(.dataExported, properties: [
            .entryCount: entryCount
        ])
    }

    func trackDataImported(entryCount: Int) {
        track(.dataImported, properties: [
            .entryCount: entryCount
        ])
    }

    func trackDataImportFailed(errorMessage: String) {
        track(.dataImportFailed, properties: [
            .errorMessage: errorMessage
        ])
    }

    // MARK: Tutorial

    func trackTutorialStepViewed(stepName: String, stepIndex: Int) {
        track(.tutorialStepViewed, properties: [
            .tutorialStep: stepName,
            .stepIndex: stepIndex
        ])
    }

    func trackTutorialStepCompleted(stepName: String, stepIndex: Int) {
        track(.tutorialStepCompleted, properties: [
            .tutorialStep: stepName,
            .stepIndex: stepIndex
        ])
    }

    func trackTutorialCompleted(tutorialName: String) {
        track(.tutorialCompleted, properties: [
            .tutorialName: tutorialName
        ])
    }

    func trackTutorialSkipped(tutorialName: String, atStep: String) {
        track(.tutorialSkipped, properties: [
            .tutorialName: tutorialName,
            .tutorialStep: atStep
        ])
    }

    // MARK: Help & Support

    func trackFAQQuestionExpanded(questionId: String, questionTitle: String, category: String) {
        track(.faqQuestionExpanded, properties: [
            .questionId: questionId,
            .questionTitle: questionTitle,
            .category: category
        ])
    }

    func trackChangelogViewed(version: String) {
        track(.changelogViewed, properties: [
            .version: version
        ])
    }

    func trackExternalLinkOpened(url: String, type: String) {
        track(.externalLinkOpened, properties: [
            .url: url,
            .linkType: type
        ])
    }

    // MARK: Theme

    func trackThemeColorChanged(to color: String, from previousColor: String) {
        track(.themeColorChanged, properties: [
            .themeColor: color,
            .previousValue: previousColor
        ])
    }

    func trackColorSchemeChanged(to scheme: String) {
        track(.colorSchemeChanged, properties: [
            .colorScheme: scheme
        ])
    }

    // MARK: Deep Links & Navigation

    func trackDeepLinkOpened(url: String, source: String) {
        track(.deepLinkOpened, properties: [
            .url: url,
            .source: source
        ])
    }

    func trackNavigatedFromWidget(widgetType: String) {
        track(.navigatedFromWidget, properties: [
            .widgetType: widgetType
        ])
    }

    func trackNavigatedFromNotification(notificationType: String) {
        track(.navigatedFromNotification, properties: [
            .source: notificationType
        ])
    }

    // MARK: Remote Alerts

    func trackRemoteAlertShown(alertId: String, title: String) {
        track(.remoteAlertShown, properties: [
            .alertId: alertId,
            .alertTitle: title
        ])
    }

    func trackRemoteAlertActionTaken(alertId: String, actionType: String) {
        track(.remoteAlertActionTaken, properties: [
            .alertId: alertId,
            .actionType: actionType
        ])
    }

    func trackRemoteAlertDismissed(alertId: String) {
        track(.remoteAlertDismissed, properties: [
            .alertId: alertId
        ])
    }

    // MARK: User Identification

    /// Set user properties for better segmentation
    func setUserProperties(isSubscribed: Bool, hasCompletedOnboarding: Bool, entryCount: Int) {
        PostHogSDK.shared.capture("$set", properties: [
            "$set": [
                "is_subscribed": isSubscribed,
                "has_completed_onboarding": hasCompletedOnboarding,
                "entry_count": entryCount
            ]
        ])
    }

    /// Identify user with anonymous ID (respects privacy)
    func identifyUser(anonymousId: String) {
        PostHogSDK.shared.identify(anonymousId)
    }

    /// Reset user identification (e.g., on logout or data clear)
    func reset() {
        PostHogSDK.shared.reset()
    }
}
