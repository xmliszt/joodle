import Foundation
import BackgroundTasks
import SwiftData

/// Schedules periodic iCloud Drive backups using BGProcessingTask.
@available(iOS 13.0, *)
final class BackupScheduler {
  static let shared = BackupScheduler()
  private init() {}

  static let taskIdentifier = "dev.liyuxuan.joodle.backup"
  static let autoBackupEnabledKey = "autoBackupEnabled"
  static let lastAutoBackupAtKey = "lastAutoBackupAt"
  private static let intervalSeconds: TimeInterval = 60 * 60 * 24

  private var isAutoBackupEnabled: Bool {
    let defaults = UserDefaults.standard
    if defaults.object(forKey: Self.autoBackupEnabledKey) == nil {
      return true
    }
    return defaults.bool(forKey: Self.autoBackupEnabledKey)
  }

  func cancelScheduledBackup() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
  }

  /// Register the BGTask handler. Must be called before app finishes launching.
  func register() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { [weak self] task in
      guard let processingTask = task as? BGProcessingTask else {
        task.setTaskCompleted(success: false)
        return
      }
      self?.handle(task: processingTask)
    }
  }

  /// Schedule the next backup. Calling this when a request is already
  /// pending replaces it, which is fine.
  func schedulePeriodicBackup() {
    guard isAutoBackupEnabled else {
      cancelScheduledBackup()
      return
    }
    let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: Self.intervalSeconds)
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      print("BackupScheduler: failed to submit BGProcessingTask: \(error)")
    }
  }

  private func handle(task: BGProcessingTask) {
    schedulePeriodicBackup()

    let work = Task {
      let syncing = await MainActor.run { CloudSyncManager.shared.isSyncing }
      if syncing {
        task.setTaskCompleted(success: false)
        return
      }

      do {
        let container = ModelContainerManager.shared.container
        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<DayEntry>())
        let data = try BackupManager.shared.serializeEntries(entries)
        _ = try BackupManager.shared.writeBackupToICloudDrive(data: data)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastAutoBackupAtKey)
        task.setTaskCompleted(success: true)
      } catch {
        print("BackupScheduler: backup failed: \(error)")
        task.setTaskCompleted(success: false)
      }
    }

    task.expirationHandler = {
      work.cancel()
    }
  }
}
