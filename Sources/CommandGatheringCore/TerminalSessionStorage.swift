import Foundation

public enum TerminalSessionStorage {
    public static func historyFileURL(
        for sessionID: UUID,
        rootDirectory: URL = StorageRootLocator.resolveRootDirectory()
    ) -> URL {
        let historyDirectory = rootDirectory.appending(path: "history", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
        return historyDirectory.appending(path: "\(sessionID.uuidString).history", directoryHint: .notDirectory)
    }

    public static func deleteHistoryFile(
        for sessionID: UUID,
        rootDirectory: URL = StorageRootLocator.resolveRootDirectory()
    ) {
        let historyFileURL = historyFileURL(for: sessionID, rootDirectory: rootDirectory)
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            return
        }
        try? FileManager.default.removeItem(at: historyFileURL)
    }
}
