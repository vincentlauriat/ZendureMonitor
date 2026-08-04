import AppKit
import Sparkle

/// Sparkle 2 updater, started once at launch. `SUEnableAutomaticChecks` and
/// the feed URL / EdDSA public key live in Info.plist.
enum Updater {
    static let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    static func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller.updater.checkForUpdates()
    }
}
