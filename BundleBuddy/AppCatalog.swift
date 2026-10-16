import AppKit
import SwiftUI

struct InstalledApp: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let bundleIdentifier: String?

    var id: URL { url }
}

@MainActor
final class AppCatalog: ObservableObject {
    @Published private(set) var apps: [InstalledApp] = []
    @Published private(set) var isScanning = false

    init() {
        refresh()
    }

    func refresh() {
        guard !isScanning else { return }
        isScanning = true

        Task.detached(priority: .userInitiated) {
            let locations = ["/Applications", "/System/Applications", "\\(NSHomeDirectory())/Applications"]
            let manager = FileManager.default
            var found = [URL: InstalledApp]()

            for path in locations {
                let root = URL(fileURLWithPath: path, isDirectory: true)
                guard let enumerator = manager.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else { continue }

                for case let url as URL in enumerator {
                    guard url.pathExtension.lowercased() == "app", let bundle = Bundle(url: url) else { continue }
                    let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                        ?? url.deletingPathExtension().lastPathComponent
                    found[url] = InstalledApp(url: url, name: name, bundleIdentifier: bundle.bundleIdentifier)
                }
            }

            let apps = found.values.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            await MainActor.run {
                self.apps = apps
                self.isScanning = false
            }
        }
    }
}
