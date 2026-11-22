import SwiftUI

@main
struct LiteratureLegendsApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if UITestLaunch.isDiscover {
                DiscoverUITestHarness()
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
    }
}
