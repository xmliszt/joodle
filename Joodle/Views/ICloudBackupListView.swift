import SwiftUI
import SwiftData

struct ICloudBackupListView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  @State private var backups: [BackupManager.BackupFile] = []
  @State private var isLoading = true
  @State private var loadError: String?

  @State private var pendingRestore: BackupManager.BackupFile?
  @State private var pendingDelete: BackupManager.BackupFile?

  @State private var resultMessage: String?
  @State private var showResultAlert = false

  private static let byteFormatter: ByteCountFormatter = {
    let f = ByteCountFormatter()
    f.countStyle = .file
    return f
  }()

  private static func formatDate(_ date: Date) -> String {
    date.formatted(date: .abbreviated, time: .shortened)
  }

  var body: some View {
    Group {
      if isLoading {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = loadError {
        ContentUnavailableView("Couldn't load backups", systemImage: "exclamationmark.icloud", description: Text(error))
      } else if backups.isEmpty {
        ContentUnavailableView("No backups yet", systemImage: "icloud")
      } else {
        List {
          Section {
            ForEach(backups) { file in
              Button {
                pendingRestore = file
              } label: {
                HStack {
                  Text(Self.formatDate(file.createdAt))
                    .foregroundColor(.primary)
                  Spacer()
                  Text(Self.byteFormatter.string(fromByteCount: file.sizeBytes))
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
              .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                  pendingDelete = file
                } label: {
                  Image(systemName: "trash")
                }
              }
            }
          } footer: {
            Text("Tap a backup to restore. Restoring will replace all current entries with the contents of that backup.")
          }
        }
      }
    }
    .navigationTitle("iCloud Backups")
    .navigationBarTitleDisplayMode(.inline)
    .task { await loadBackups() }
    .alert(
      "Restore from this backup?",
      isPresented: Binding(
        get: { pendingRestore != nil },
        set: { if !$0 { pendingRestore = nil } }
      ),
      presenting: pendingRestore
    ) { file in
      Button("Restore", role: .destructive) { restore(file) }
      Button("Cancel", role: .cancel) { pendingRestore = nil }
    } message: { file in
      Text("This will permanently replace all current entries with the backup from \(Self.formatDate(file.createdAt)). This cannot be undone.")
    }
    .alert(
      "Delete this backup?",
      isPresented: Binding(
        get: { pendingDelete != nil },
        set: { if !$0 { pendingDelete = nil } }
      ),
      presenting: pendingDelete
    ) { file in
      Button("Delete", role: .destructive) { delete(file) }
      Button("Cancel", role: .cancel) { pendingDelete = nil }
    } message: { file in
      Text("The backup from \(Self.formatDate(file.createdAt)) will be removed from iCloud Drive.")
    }
    .alert("iCloud Backup", isPresented: $showResultAlert) {
      Button("OK", role: .cancel) { }
    } message: {
      Text(resultMessage ?? "")
    }
  }

  private func loadBackups() async {
    isLoading = true
    loadError = nil
    let result: Result<[BackupManager.BackupFile], Error> = await Task.detached(priority: .userInitiated) {
      do {
        return .success(try BackupManager.shared.listICloudBackups())
      } catch {
        return .failure(error)
      }
    }.value
    switch result {
    case .success(let files):
      backups = files
    case .failure(let error):
      if case BackupManager.BackupError.ubiquityUnavailable = error {
        loadError = "iCloud Drive is not available."
      } else {
        loadError = error.localizedDescription
      }
    }
    isLoading = false
  }

  private func delete(_ file: BackupManager.BackupFile) {
    pendingDelete = nil
    Task.detached(priority: .userInitiated) {
      do {
        try BackupManager.shared.deleteBackup(at: file.url)
        await MainActor.run {
          backups.removeAll { $0.id == file.id }
        }
      } catch {
        await MainActor.run {
          resultMessage = "Couldn't delete backup: \(error.localizedDescription)"
          showResultAlert = true
        }
      }
    }
  }

  private func restore(_ file: BackupManager.BackupFile) {
    pendingRestore = nil
    let container = modelContext.container
    let url = file.url
    Task.detached(priority: .userInitiated) {
      do {
        let count = try BackupManager.shared.restoreBackup(from: url, into: container)
        await MainActor.run {
          AnalyticsManager.shared.trackDataImported(entryCount: count)
          resultMessage = "Restored \(count) entries from backup."
          showResultAlert = true
        }
      } catch {
        await MainActor.run {
          AnalyticsManager.shared.trackDataImportFailed(errorMessage: error.localizedDescription)
          resultMessage = "Restore failed: \(error.localizedDescription)"
          showResultAlert = true
        }
      }
    }
  }
}
