import Foundation

/// Éphémérides et position du soleil, algorithme NOAA (précision ~1 min,
/// largement suffisante pour un tableau de bord). Calcul 100 % local.
enum SunCalc {
    struct Ephemeris {
        var sunrise: Date?          // nil en jour/nuit polaire
        var sunset: Date?
        var solarNoon: Date
        var daylight: TimeInterval  // s
        var elevation: Double       // ° à l'instant du calcul (négatif sous l'horizon)
        var azimuth: Double         // ° (0 = nord, 90 = est)
        var maxElevation: Double    // ° au midi solaire
    }

    static func compute(at date: Date = .now,
                        latitude: Double, longitude: Double,
                        calendar: Calendar = .current) -> Ephemeris {
        let tzHours = Double(calendar.timeZone.secondsFromGMT(for: date)) / 3600.0
        let jd = 2440587.5 + date.timeIntervalSince1970 / 86400.0
        let jc = (jd - 2451545.0) / 36525.0

        let geomMeanLong = (280.46646 + jc * (36000.76983 + jc * 0.0003032))
            .truncatingRemainder(dividingBy: 360)
        let geomMeanAnom = 357.52911 + jc * (35999.05029 - 0.0001537 * jc)
        let eccent = 0.016708634 - jc * (0.000042037 + 0.0000001267 * jc)
        let eqOfCenter = sin(rad(geomMeanAnom)) * (1.914602 - jc * (0.004817 + 0.000014 * jc))
            + sin(rad(2 * geomMeanAnom)) * (0.019993 - 0.000101 * jc)
            + sin(rad(3 * geomMeanAnom)) * 0.000289
        let appLong = geomMeanLong + eqOfCenter - 0.00569 - 0.00478 * sin(rad(125.04 - 1934.136 * jc))
        let meanObliq = 23 + (26 + (21.448 - jc * (46.815 + jc * (0.00059 - jc * 0.001813))) / 60) / 60
        let obliqCorr = meanObliq + 0.00256 * cos(rad(125.04 - 1934.136 * jc))
        let declination = deg(asin(sin(rad(obliqCorr)) * sin(rad(appLong))))

        let varY = pow(tan(rad(obliqCorr / 2)), 2)
        let eqOfTime = 4 * deg(varY * sin(2 * rad(geomMeanLong))
            - 2 * eccent * sin(rad(geomMeanAnom))
            + 4 * eccent * varY * sin(rad(geomMeanAnom)) * cos(2 * rad(geomMeanLong))
            - 0.5 * varY * varY * sin(4 * rad(geomMeanLong))
            - 1.25 * eccent * eccent * sin(2 * rad(geomMeanAnom)))

        let startOfDay = calendar.startOfDay(for: date)
        let noonMinutes = 720 - 4 * longitude - eqOfTime + tzHours * 60
        let solarNoon = startOfDay.addingTimeInterval(noonMinutes * 60)

        // -0.833° : réfraction atmosphérique + demi-diamètre solaire.
        var sunrise: Date?
        var sunset: Date?
        var daylight: TimeInterval = 0
        let cosHA = cos(rad(90.833)) / (cos(rad(latitude)) * cos(rad(declination)))
            - tan(rad(latitude)) * tan(rad(declination))
        if cosHA >= -1, cosHA <= 1 {
            let haSunrise = deg(acos(cosHA))
            sunrise = startOfDay.addingTimeInterval((noonMinutes - haSunrise * 4) * 60)
            sunset = startOfDay.addingTimeInterval((noonMinutes + haSunrise * 4) * 60)
            daylight = haSunrise * 8 * 60
        } else if cosHA < -1 {
            daylight = 86400   // jour polaire
        }

        let minutesLocal = date.timeIntervalSince(startOfDay) / 60
        var trueSolarTime = (minutesLocal + eqOfTime + 4 * longitude - 60 * tzHours)
            .truncatingRemainder(dividingBy: 1440)
        if trueSolarTime < 0 { trueSolarTime += 1440 }
        var hourAngle = trueSolarTime / 4 - 180
        if hourAngle < -180 { hourAngle += 360 }

        let cosZenith = sin(rad(latitude)) * sin(rad(declination))
            + cos(rad(latitude)) * cos(rad(declination)) * cos(rad(hourAngle))
        let zenith = deg(acos(min(1, max(-1, cosZenith))))
        let elevation = 90 - zenith

        var azimuth = 0.0
        let azDenom = cos(rad(latitude)) * sin(rad(zenith))
        if abs(azDenom) > 0.001 {
            let acosArg = min(1, max(-1, (sin(rad(latitude)) * cos(rad(zenith)) - sin(rad(declination))) / azDenom))
            let acosVal = deg(acos(acosArg))
            azimuth = hourAngle > 0
                ? (acosVal + 180).truncatingRemainder(dividingBy: 360)
                : (540 - acosVal).truncatingRemainder(dividingBy: 360)
        }

        return Ephemeris(sunrise: sunrise, sunset: sunset, solarNoon: solarNoon,
                         daylight: daylight, elevation: elevation, azimuth: azimuth,
                         maxElevation: 90 - abs(latitude - declination))
    }

    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / .pi }
}
