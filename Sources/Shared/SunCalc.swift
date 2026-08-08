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

    /// Position du soleil à un instant donné : sert à tracer la course réelle
    /// (élévation × azimut) au lieu d'un arc décoratif.
    struct Position: Equatable {
        var date: Date
        var elevation: Double
        var azimuth: Double
    }

    static func compute(at date: Date = .now,
                        latitude: Double, longitude: Double,
                        calendar: Calendar = .current) -> Ephemeris {
        let terms = dayTerms(at: date, longitude: longitude, calendar: calendar)
        let solarNoon = terms.startOfDay.addingTimeInterval(terms.noonMinutes * 60)

        // -0.833° : réfraction atmosphérique + demi-diamètre solaire.
        var sunrise: Date?
        var sunset: Date?
        var daylight: TimeInterval = 0
        switch hourAngle(atAltitude: sunriseAltitude, latitude: latitude, declination: terms.declination) {
        case .at(let ha):
            sunrise = terms.startOfDay.addingTimeInterval((terms.noonMinutes - ha * 4) * 60)
            sunset = terms.startOfDay.addingTimeInterval((terms.noonMinutes + ha * 4) * 60)
            daylight = ha * 8 * 60
        case .alwaysAbove:
            daylight = 86400   // jour polaire
        case .alwaysBelow:
            break              // nuit polaire
        }

        let horizontal = horizontalPosition(at: date, latitude: latitude, terms: terms)
        return Ephemeris(sunrise: sunrise, sunset: sunset, solarNoon: solarNoon,
                         daylight: daylight,
                         elevation: horizontal.elevation, azimuth: horizontal.azimuth,
                         maxElevation: 90 - abs(latitude - terms.declination))
    }

    /// Course du soleil sur la journée de `date`, échantillonnée (6 min par
    /// défaut) : socle des tracés élévation × azimut.
    static func track(on date: Date,
                      latitude: Double, longitude: Double,
                      calendar: Calendar = .current,
                      stepMinutes: Int = 6) -> [Position] {
        let terms = dayTerms(at: date, longitude: longitude, calendar: calendar)
        let step = max(1, stepMinutes)
        var positions: [Position] = []
        positions.reserveCapacity(1440 / step + 1)
        for minute in stride(from: 0, through: 1440, by: step) {
            let instant = terms.startOfDay.addingTimeInterval(Double(minute) * 60)
            let horizontal = horizontalPosition(at: instant, latitude: latitude, terms: terms)
            positions.append(Position(date: instant,
                                      elevation: horizontal.elevation,
                                      azimuth: horizontal.azimuth))
        }
        return positions
    }

    /// Instants où le soleil franchit une altitude donnée, le matin et le soir.
    /// Sert aux crépuscules (−6, −12, −18°) et à l'heure dorée (+6°). `nil`
    /// quand l'altitude n'est jamais franchie ce jour-là.
    static func crossings(atAltitude altitude: Double,
                          on date: Date,
                          latitude: Double, longitude: Double,
                          calendar: Calendar = .current) -> (morning: Date?, evening: Date?) {
        let terms = dayTerms(at: date, longitude: longitude, calendar: calendar)
        guard case .at(let ha) = hourAngle(atAltitude: altitude,
                                          latitude: latitude,
                                          declination: terms.declination) else {
            return (nil, nil)
        }
        return (terms.startOfDay.addingTimeInterval((terms.noonMinutes - ha * 4) * 60),
                terms.startOfDay.addingTimeInterval((terms.noonMinutes + ha * 4) * 60))
    }

    /// Crépuscules et heure dorée du jour, en un seul appel.
    struct Twilight {
        var goldenHourMorningEnd: Date?     // soleil à +6° le matin
        var goldenHourEveningStart: Date?   // soleil à +6° le soir
        var civilDawn: Date?                // −6°
        var civilDusk: Date?
        var nauticalDawn: Date?             // −12°
        var nauticalDusk: Date?
        var astronomicalDawn: Date?         // −18°
        var astronomicalDusk: Date?
    }

    static func twilight(on date: Date,
                         latitude: Double, longitude: Double,
                         calendar: Calendar = .current) -> Twilight {
        func pair(_ altitude: Double) -> (morning: Date?, evening: Date?) {
            crossings(atAltitude: altitude, on: date,
                      latitude: latitude, longitude: longitude, calendar: calendar)
        }
        let golden = pair(6)
        let civil = pair(-6)
        let nautical = pair(-12)
        let astronomical = pair(-18)
        return Twilight(goldenHourMorningEnd: golden.morning,
                        goldenHourEveningStart: golden.evening,
                        civilDawn: civil.morning, civilDusk: civil.evening,
                        nauticalDawn: nautical.morning, nauticalDusk: nautical.evening,
                        astronomicalDawn: astronomical.morning, astronomicalDusk: astronomical.evening)
    }

    // MARK: - Saisons

    enum SolarEventKind {
        case springEquinox, summerSolstice, autumnEquinox, winterSolstice
    }

    struct SolarEvent {
        var kind: SolarEventKind
        var date: Date
    }

    /// Déclinaison du soleil (°) : positive au nord de l'équateur céleste.
    static func declination(at date: Date) -> Double {
        orbital(at: date).declination
    }

    /// Prochain solstice ou équinoxe après `date` : balayage jour par jour pour
    /// encadrer l'événement (annulation de la déclinaison ou de sa pente), puis
    /// bissection à la minute.
    static func nextSolarEvent(after date: Date) -> SolarEvent? {
        let day: TimeInterval = 86400
        let slope: (Date) -> Double = { declination(at: $0.addingTimeInterval(day)) - declination(at: $0) }

        var previous = date
        var previousDeclination = declination(at: previous)
        var previousSlope = slope(previous)

        for offset in 1...400 {
            let current = date.addingTimeInterval(Double(offset) * day)
            let currentDeclination = declination(at: current)
            let currentSlope = slope(current)

            if previousDeclination < 0, currentDeclination >= 0 {
                return SolarEvent(kind: .springEquinox,
                                  date: refine(from: previous, to: current, declination))
            }
            if previousDeclination > 0, currentDeclination <= 0 {
                return SolarEvent(kind: .autumnEquinox,
                                  date: refine(from: previous, to: current, declination))
            }
            if previousSlope > 0, currentSlope <= 0 {
                return SolarEvent(kind: .summerSolstice,
                                  date: refine(from: previous, to: current, slope))
            }
            if previousSlope < 0, currentSlope >= 0 {
                return SolarEvent(kind: .winterSolstice,
                                  date: refine(from: previous, to: current, slope))
            }

            previous = current
            previousDeclination = currentDeclination
            previousSlope = currentSlope
        }
        return nil
    }

    /// Bissection sur un intervalle où `f` change de signe.
    private static func refine(from start: Date, to end: Date,
                               _ f: (Date) -> Double) -> Date {
        var low = start
        var high = end
        let atLowIsNegative = f(low) < 0
        for _ in 0..<24 {
            let middle = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if (f(middle) < 0) == atLowIsNegative {
                low = middle
            } else {
                high = middle
            }
        }
        return low.addingTimeInterval(high.timeIntervalSince(low) / 2)
    }

    // MARK: - Noyau NOAA

    private static let sunriseAltitude = -0.833

    /// Termes valables pour toute la journée : déclinaison, équation du temps,
    /// midi solaire (minutes après minuit local).
    private struct DayTerms {
        var declination: Double
        var eqOfTime: Double
        var noonMinutes: Double
        var startOfDay: Date
        var tzHours: Double
        var longitude: Double
    }

    private static func dayTerms(at date: Date, longitude: Double,
                                 calendar: Calendar) -> DayTerms {
        let tzHours = Double(calendar.timeZone.secondsFromGMT(for: date)) / 3600.0
        let orbital = orbital(at: date)
        let startOfDay = calendar.startOfDay(for: date)
        let noonMinutes = 720 - 4 * longitude - orbital.eqOfTime + tzHours * 60
        return DayTerms(declination: orbital.declination, eqOfTime: orbital.eqOfTime,
                        noonMinutes: noonMinutes, startOfDay: startOfDay,
                        tzHours: tzHours, longitude: longitude)
    }

    /// Déclinaison et équation du temps (min) pour un instant donné.
    private static func orbital(at date: Date) -> (declination: Double, eqOfTime: Double) {
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

        return (declination, eqOfTime)
    }

    private enum Crossing {
        case at(Double)      // angle horaire (°) du franchissement
        case alwaysAbove     // le soleil ne descend jamais sous cette altitude
        case alwaysBelow     // il ne monte jamais jusque là
    }

    private static func hourAngle(atAltitude altitude: Double,
                                 latitude: Double, declination: Double) -> Crossing {
        let zenith = 90 - altitude
        let cosHA = cos(rad(zenith)) / (cos(rad(latitude)) * cos(rad(declination)))
            - tan(rad(latitude)) * tan(rad(declination))
        if cosHA < -1 { return .alwaysAbove }
        if cosHA > 1 { return .alwaysBelow }
        return .at(deg(acos(cosHA)))
    }

    private static func horizontalPosition(at date: Date, latitude: Double,
                                           terms: DayTerms) -> (elevation: Double, azimuth: Double) {
        let minutesLocal = date.timeIntervalSince(terms.startOfDay) / 60
        var trueSolarTime = (minutesLocal + terms.eqOfTime + 4 * terms.longitude - 60 * terms.tzHours)
            .truncatingRemainder(dividingBy: 1440)
        if trueSolarTime < 0 { trueSolarTime += 1440 }
        var hourAngle = trueSolarTime / 4 - 180
        if hourAngle < -180 { hourAngle += 360 }

        let cosZenith = sin(rad(latitude)) * sin(rad(terms.declination))
            + cos(rad(latitude)) * cos(rad(terms.declination)) * cos(rad(hourAngle))
        let zenith = deg(acos(min(1, max(-1, cosZenith))))
        let elevation = 90 - zenith

        var azimuth = 0.0
        let azDenom = cos(rad(latitude)) * sin(rad(zenith))
        if abs(azDenom) > 0.001 {
            let acosArg = min(1, max(-1, (sin(rad(latitude)) * cos(rad(zenith)) - sin(rad(terms.declination))) / azDenom))
            let acosVal = deg(acos(acosArg))
            azimuth = hourAngle > 0
                ? (acosVal + 180).truncatingRemainder(dividingBy: 360)
                : (540 - acosVal).truncatingRemainder(dividingBy: 360)
        }
        return (elevation, azimuth)
    }

    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / .pi }
}
