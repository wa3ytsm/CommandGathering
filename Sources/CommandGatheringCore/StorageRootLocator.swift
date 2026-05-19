import Foundation

public enum StorageRootLocator {
    public static func resolveRootDirectory(
        bundleURL: URL = Bundle.main.bundleURL,
        currentDirectoryURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    ) -> URL {
        if bundleURL.pathExtension == "app" {
            return bundleURL.appending(path: "CommandGatheringData", directoryHint: .isDirectory)
        }

        return currentDirectoryURL.appending(path: "CommandGatheringData", directoryHint: .isDirectory)
    }

    public static func resolveDefaultWorkspaceDirectory(
        bundleURL: URL = Bundle.main.bundleURL,
        currentDirectoryURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        guard bundleURL.pathExtension == "app" else {
            return currentDirectoryURL
        }

        let appContainerURL = bundleURL.deletingLastPathComponent()
        if appContainerURL.lastPathComponent == "dist" {
            return appContainerURL.deletingLastPathComponent()
        }

        return homeDirectoryURL
    }
}
