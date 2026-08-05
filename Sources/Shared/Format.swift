import Foundation

/// Formatage commun (app + widget + tests).
enum Format {
    static func watts(_ value: Double) -> String {
        if abs(value) >= 1000 {
            return String(format: "%.2f kW", locale: .current, value / 1000)
        }
        return "\(Int(value.rounded())) W"
    }

    /// Shorter variant for the menu bar itself.
    static func wattsCompact(_ value: Double) -> String {
        if abs(value) >= 1000 {
            return String(format: "%.1f kW", locale: .current, value / 1000)
        }
        return "\(Int(value.rounded())) W"
    }

    static func kilowattHours(_ wh: Double) -> String {
        if wh >= 1000 {
            return String(format: "%.2f kWh", locale: .current, wh / 1000)
        }
        return "\(Int(wh.rounded())) Wh"
    }

    static func duration(minutes: Double) -> String {
        let total = Int(minutes.rounded())
        if total >= 60 { return "\(total / 60) h \(String(format: "%02d", total % 60))" }
        return "\(total) min"
    }
}
