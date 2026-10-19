import SwiftUI

@main
struct BundleReportApp: App {
    @StateObject private var catalog = AppCatalog()

    var body: some Scene {
        WindowGroup {
            BundleReportView()
                .environmentObject(catalog)
                .frame(minWidth: 940, minHeight: 620)
        }
        .defaultSize(width: 1_060, height: 720)
    }
}
