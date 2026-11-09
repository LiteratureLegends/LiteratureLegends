import SwiftUI

struct ContentView: View {
    @StateObject private var store = ProfileSampleData.makeStore()

    var body: some View {
        NavigationStack {
            ProfileView(store: store)
        }
        .tint(ProfileTheme.accent)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
