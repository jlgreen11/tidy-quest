import SwiftUI

@main
struct ParentApp: App {
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
