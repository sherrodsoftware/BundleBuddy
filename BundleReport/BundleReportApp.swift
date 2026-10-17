import SwiftUI

@main
struct BundleReportApp: App {
    @StateObject private var catalog = AppCatalog()

    var body: some Scene {
        WindowGroup {
            BundleReportView()
                .environmentObject(catalog)
                .frame(minWidth: 660, minHeight: 500)
        }
        .defaultSize(width: 760, height: 580)

        MenuBarExtra("Bundle Report", systemImage: "shippingbox.fill") {
            BundleReportView(compact: true)
                .environmentObject(catalog)
                .frame(width: 460, height: 540)
        }
        .menuBarExtraStyle(.window)
    }
}
