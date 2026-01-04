//
//  RemoteAlert.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import Foundation

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
