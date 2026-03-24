import SwiftUI

@main
struct WordGameApp: App {
    @StateObject private var databaseService = DatabaseService.shared
    @StateObject private var wordBookViewModel = WordBookViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(databaseService)
                .environmentObject(wordBookViewModel)
                .task {
                    // Block UI until vocabulary initialization completes.
                    // .task is @MainActor, so UI stays blocked on the main thread.
                    await wordBookViewModel.initializeIfNeeded()
                }
        }
        .defaultSize(width: 1024, height: 700)
    }
}
