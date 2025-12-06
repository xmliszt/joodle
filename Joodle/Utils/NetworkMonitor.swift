//
//  NetworkMonitor.swift
//  Joodle
//
//  Created by AI Assistant
//

import Foundation
import Network
import Observation
import SwiftUI

@Observable
final class NetworkMonitor {
  // MARK: - Singleton
  static let shared = NetworkMonitor()

  // MARK: - Published State
  var isConnected = false
  var connectionType: NWInterface.InterfaceType?

  // MARK: - Private Properties
  private let monitor: NWPathMonitor
  private let queue = DispatchQueue(label: "NetworkMonitor")

  // MARK: - Initialization
  private init() {
    monitor = NWPathMonitor()
    startMonitoring()
  }

  deinit {
    stopMonitoring()
  }

  // MARK: - Monitoring
  private func startMonitoring() {
    monitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async {
        self?.isConnected = path.status == .satisfied
        self?.connectionType = self?.getConnectionType(path)
      }
    }
    monitor.start(queue: queue)
  }

  private func stopMonitoring() {
    monitor.cancel()
  }

  private func getConnectionType(_ path: NWPath) -> NWInterface.InterfaceType? {
    if path.usesInterfaceType(.wifi) {
      return .wifi
    } else if path.usesInterfaceType(.cellular) {
      return .cellular
    } else if path.usesInterfaceType(.wiredEthernet) {
      return .wiredEthernet
    }
    return nil
  }

  // MARK: - Public Methods
  func checkConnectivity() -> Bool {
    return isConnected
  }

  var connectionDescription: String {
    guard isConnected else {
      return "No Connection"
    }

    switch connectionType {
    case .wifi:
      return "Wi-Fi"
    case .cellular:
      return "Cellular"
    case .wiredEthernet:
      return "Ethernet"
    default:
      return "Connected"
    }
  }
}

// MARK: - Environment Extension
extension EnvironmentValues {
  @Entry var networkMonitor: NetworkMonitor = NetworkMonitor.shared
}
