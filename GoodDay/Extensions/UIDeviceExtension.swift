//
//  UIDeviceExtension.swift
//  GoodDay
//
//  Created by Li Yuxuan on 17/8/25.
//

import SwiftUI
import UIKit

// MARK: - Device Detection Extension
extension UIDevice {
    static var hasDynamicIsland: Bool {
        var systemInfo = utsname()
        uname(&systemInfo)
        
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        
        guard let deviceModel = machine else { return false }
        
        // iPhone models with Dynamic Island
        let dynamicIslandModels = [
            "iPhone15,2", // iPhone 14 Pro
            "iPhone15,3", // iPhone 14 Pro Max
            "iPhone16,1", // iPhone 15 Pro
            "iPhone16,2", // iPhone 15 Pro Max
            "iPhone17,1", // iPhone 15
            "iPhone17,2", // iPhone 15 Plus
            "iPhone17,3", // iPhone 16
            "iPhone17,4", // iPhone 16 Plus
            "iPhone17,5", // iPhone 16 Pro
            "iPhone17,6", // iPhone 16 Pro Max
            "arm64" // For this mac os preview
        ]
        
        return dynamicIslandModels.contains(deviceModel)
    }
    
    static var dynamicIslandFrame: CGRect {
        guard UIDevice.hasDynamicIsland else { return .zero }
        
        let screenWidth = UIScreen.main.bounds.width
        let islandWidth: CGFloat = 126
        let islandHeight: CGFloat = 36
        let x = (screenWidth - islandWidth) / 2
        let y: CGFloat = 11
        
        return CGRect(x: x, y: y, width: islandWidth, height: islandHeight)
    }
    
    static var dynamicIslandSize: CGSize {
        guard UIDevice.hasDynamicIsland else { return .zero }
        return CGSize(width: 126, height: 36)
    }
}


/// Device corner radius
extension UIDevice {
    static var screenCornerRadius: CGFloat {
        var systemInfo = utsname()
        uname(&systemInfo)
        
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        
        guard let deviceModel = machine else {
            // Fallback based on interface idiom
            return fallbackCornerRadius()
        }
        
        // iPhone corner radius mapping
        switch deviceModel {
            // iPhone X, Xs, Xs Max, 11 Pro, 11 Pro Max - 39.0
        case "iPhone10,3", "iPhone10,6", // iPhone X
            "iPhone11,2", "iPhone11,4", "iPhone11,6", // iPhone Xs, Xs Max
            "iPhone12,3", "iPhone12,5": // iPhone 11 Pro, 11 Pro Max
            return 39.0
            
            // iPhone Xr, 11 - 41.5
        case "iPhone11,8", // iPhone Xr
            "iPhone12,1": // iPhone 11
            return 41.5
            
            // iPhone 12 mini, 13 mini - 44.0
        case "iPhone13,1", // iPhone 12 mini
            "iPhone14,4": // iPhone 13 mini
            return 44.0
            
            // iPhone 12, 12 Pro, 13 Pro, 14, 16 - 47.33
        case "iPhone13,2", "iPhone13,3", // iPhone 12, 12 Pro
            "iPhone14,2", // iPhone 13 Pro
            "iPhone14,7", // iPhone 14
            "iPhone17,3": // iPhone 16
            return 47.33
            
            // iPhone 12 Pro Max, 13 Pro Max, 14 Plus - 53.33
        case "iPhone13,4", // iPhone 12 Pro Max
            "iPhone14,3", // iPhone 13 Pro Max
            "iPhone14,8": // iPhone 14 Plus
            return 53.33
            
            // iPhone 14 Pro, 14 Pro Max, 15, 15 Plus, 15 Pro, 15 Pro Max, 16, 16 Plus - 55.0
        case "iPhone15,2", "iPhone15,3", // iPhone 14 Pro, 14 Pro Max
            "iPhone15,4", "iPhone15,5", // iPhone 15, 15 Plus
            "iPhone16,1", "iPhone16,2", // iPhone 15 Pro, 15 Pro Max
            "iPhone17,4": // iPhone 16 Plus
            return 55.0
            
            // iPhone 16 Pro, 16 Pro Max - 62.0
        case "iPhone17,5", "iPhone17,6": // iPhone 16 Pro, 16 Pro Max
            return 62.0
        
            // For preview runs on iPhone 16 Pro
        case "arm64":
            return 62.0
            
        default:
            return fallbackCornerRadius()
        }
    }
    
    private static func fallbackCornerRadius() -> CGFloat {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            // iPhone models with rounded corners
            if UIScreen.main.bounds.height >= 812 { // iPhone X and newer
                return 39.0 // Conservative fallback
            }
            return 0 // Older iPhones without rounded corners
        case .pad:
            // iPad models - 18.0
            if #available(iOS 13.0, *) {
                return 18.0 // iPad Air / iPad Pro
            }
            return 0
        default:
            return 0
        }
    }
}
