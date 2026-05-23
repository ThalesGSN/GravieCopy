import SwiftUI

@main
struct GravieCopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { SettingsView() }
    }
}
