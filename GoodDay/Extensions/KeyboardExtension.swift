//
//  File.swift
//  GoodDay
//
//  Created by Li Yuxuan on 17/8/25.
//

import Combine
import SwiftUI

struct KeyboardInfo {
    let height: CGFloat
    let duration: TimeInterval
}

/// Measure keyboard height
extension Publishers {
    static var keyboardInfo: AnyPublisher<KeyboardInfo, Never> {
        let willShow = NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillShowNotification
        )
            .map { notification -> KeyboardInfo in
                let height =
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
                let duration =
                (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval)
                ?? 0.25
                return KeyboardInfo(height: height, duration: duration)
            }
        
        let willHide = NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification
        )
            .map { notification -> KeyboardInfo in
                let duration =
                (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval)
                ?? 0.25
                return KeyboardInfo(height: 0, duration: duration)
            }
        
        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

/// Hide keyboard utility
extension UIApplication {
    func hideKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
