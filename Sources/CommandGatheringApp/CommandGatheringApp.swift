import SwiftUI

@main
struct CommandGatheringApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .frame(minWidth: 1120, minHeight: 720)
        }
        .windowStyle(.titleBar)
    }
}
