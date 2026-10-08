import SwiftUI

@main
struct PorterPhoneApp: App {
    @State private var model = PhoneModel()

    var body: some Scene {
        WindowGroup {
            PhoneListView(model: model)
                .task { await model.load() }
        }
    }
}
