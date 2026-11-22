import SwiftUI

/// Authentication is the entry point; Luis's profile preview is still reachable
/// after login and has not been modified by this feature.
struct ContentView: View {
    var body: some View {
        AuthRootView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
