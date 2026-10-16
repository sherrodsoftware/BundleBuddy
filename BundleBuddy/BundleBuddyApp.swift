import SwiftUI

@main
struct BundleBuddyApp: App {
    @StateObject private var catalog = AppCatalog()

    var body: some Scene {
        WindowGroup {
            BundleBuddyView()
                .environmentObject(catalog)
                .frame(minWidth: 660, minHeight: 500)
        }
        .defaultSize(width: 760, height: 580)

        MenuBarExtra("Bundle Buddy", systemImage: "shippingbox.fill") {
            BundleBuddyView(compact: true)
                .environmentObject(catalog)
                .frame(width: 460, height: 540)
        }
        .menuBarExtraStyle(.window)
    }
}
