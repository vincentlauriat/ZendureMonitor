import Foundation
import ServiceManagement

/// Launch-at-login via SMAppService (macOS 13+). Requires the app to run
/// from /Applications to register reliably.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns nil on success, or a user-facing error message.
    @discardableResult
    static func set(enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
