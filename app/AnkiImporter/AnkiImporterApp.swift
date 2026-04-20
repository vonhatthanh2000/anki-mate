import SwiftUI
import AppKit

@main
struct AnkiImporterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 800)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app can receive text input
        NSApp.setActivationPolicy(.regular)

        // Make the window key without interfering with input methods
        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let window = sender.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
