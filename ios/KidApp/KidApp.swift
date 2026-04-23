import SwiftUI

@main
struct KidApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("TidyQuest — ready")
            .font(.title)
            .padding()
    }
}
