//
//  RemoteAlert.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import Foundation
import SwiftUI

// MARK: - API Response

/// Response wrapper from the remote alert API endpoint
struct RemoteAlertResponse: Codable {
    let alert: RemoteAlert?
}

// MARK: - Remote Alert Model

/// A remote alert that can be displayed to users without an app update
struct RemoteAlert: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let primaryButton: AlertButton
    let secondaryButton: AlertButton?
    let imageURL: String?
    let type: AnnouncementType

    // MARK: - Announcement Type

    /// The type of announcement, used to filter based on user preferences
    enum AnnouncementType: String, Codable, CaseIterable, Identifiable {
        case promo       // Promotional content, sales, etc.
        case community   // Discord, social media, community events
        case tips        // App tips, feature highlights, tutorials

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .promo: return "Promotions"
            case .community: return "Community"
            case .tips: return "Tips & Tutorials"
            }
        }

        var description: String {
            switch self {
            case .promo: return "Special offers and promotions"
            case .community: return "Discord, events, and community updates"
            case .tips: return "App tips and tutorials"
            }
        }

        var iconName: String {
            switch self {
            case .promo: return "tag.fill"
            case .community: return "person.2.fill"
            case .tips: return "lightbulb.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .promo: return .orange
            case .community: return .purple
            case .tips: return .yellow
            }
        }
    }

    // MARK: - Alert Button

    struct AlertButton: Codable, Equatable {
        let text: String
        let url: String?  // nil means just dismiss

        /// Whether this button has an associated action URL
        var hasAction: Bool {
            url != nil && !url!.isEmpty
        }
    }
}

// MARK: - Equatable

extension RemoteAlert {
    static func == (lhs: RemoteAlert, rhs: RemoteAlert) -> Bool {
        lhs.id == rhs.id
    }
}
