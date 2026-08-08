import Foundation

/// Un champ de panneaux : puissance crête et orientation.
///
/// Azimut dans la même convention que `SunCalc` — 0° = nord, 90° = est,
/// 180° = sud, 270° = ouest. Inclinaison : 0° = à plat, 90° = vertical.
struct PanelArray: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String        // vide = « Champ n » calculé à l'affichage
    var peakWatts: Double
    var azimuth: Double
    var tilt: Double

    init(id: UUID = UUID(), name: String = "", peakWatts: Double,
         azimuth: Double = 180, tilt: Double = 30) {
        self.id = id
        self.name = name
        self.peakWatts = peakWatts
        self.azimuth = azimuth
        self.tilt = tilt
    }
}

/// Persistance des champs de panneaux (JSON dans UserDefaults).
///
/// L'ancien réglage `sunPeakWatts` — une seule puissance crête, sans
/// orientation — reste lu : tant qu'aucun champ n'a été saisi, il est présenté
/// comme un champ unique plein sud incliné à 30°, l'hypothèse la plus courante.
enum PanelArrayStore {
    static let key = "sunArrays"
    static let legacyPeakKey = "sunPeakWatts"

    static func load(from defaults: UserDefaults = .standard) -> [PanelArray] {
        if let json = defaults.string(forKey: key),
           let data = json.data(using: .utf8),
           let arrays = try? JSONDecoder().decode([PanelArray].self, from: data),
           !arrays.isEmpty {
            return arrays
        }
        let legacyPeak = defaults.double(forKey: legacyPeakKey)
        guard legacyPeak > 0 else { return [] }
        return [PanelArray(peakWatts: legacyPeak, azimuth: 180, tilt: 30)]
    }

    static func encode(_ arrays: [PanelArray]) -> String {
        guard let data = try? JSONEncoder().encode(arrays),
              let json = String(data: data, encoding: .utf8) else { return "" }
        return json
    }

    static func decode(_ json: String) -> [PanelArray] {
        guard let data = json.data(using: .utf8),
              let arrays = try? JSONDecoder().decode([PanelArray].self, from: data) else { return [] }
        return arrays
    }

    static func save(_ arrays: [PanelArray], to defaults: UserDefaults = .standard) {
        defaults.set(encode(arrays), forKey: key)
    }
}

/// Géométrie panneau × soleil : angle d'incidence et productible ciel clair
/// par orientation. Modèle volontairement simple — pas de suivi d'albédo ni de
/// trouble atmosphérique — mais cohérent avec l'estimation historique de la
/// fenêtre Soleil : à plat, il redonne exactement `crête × sin(élévation)`.
enum SolarGeometry {
    /// Part directe de l'irradiance par ciel clair ; le reste est diffus.
    static let directShare = 0.85
    /// Pertes onduleur + câblage + température, valeur déjà utilisée par l'app.
    static let systemEfficiency = 0.9

    /// Cosinus de l'angle d'incidence entre la normale du panneau et la
    /// direction du soleil. Vaut `sin(élévation)` pour un panneau à plat, 1
    /// quand le panneau pointe pile sur le soleil.
    static func cosIncidence(sunElevation: Double, sunAzimuth: Double,
                             tilt: Double, azimuth: Double) -> Double {
        let elevation = rad(sunElevation)
        let panelTilt = rad(tilt)
        return sin(elevation) * cos(panelTilt)
            + cos(elevation) * sin(panelTilt) * cos(rad(sunAzimuth - azimuth))
    }

    /// Angle d'incidence en degrés (0° = soleil dans l'axe du panneau).
    static func incidenceAngle(sunElevation: Double, sunAzimuth: Double,
                               tilt: Double, azimuth: Double) -> Double {
        let cosine = cosIncidence(sunElevation: sunElevation, sunAzimuth: sunAzimuth,
                                  tilt: tilt, azimuth: azimuth)
        return deg(acos(min(1, max(-1, cosine))))
    }

    /// Transmittance du rayonnement direct à travers l'atmosphère
    /// (Meinel & Meinel : 0,7^masse d'air^0,678), ramenée à 1 au zénith. Sans
    /// elle, une façade ouest afficherait sa pleine puissance au coucher du
    /// soleil alors que le rayon traverse 25 fois l'épaisseur d'atmosphère.
    static func atmosphericTransmittance(sunElevation: Double) -> Double {
        guard let airMass = airMass(sunElevation: sunElevation) else { return 0 }
        return pow(0.7, pow(airMass, 0.678) - 1)
    }

    /// Irradiance dans le plan des panneaux, en fraction de l'irradiance crête
    /// (0…1). Direct pondéré par l'incidence et par la traversée d'atmosphère,
    /// diffus par la fraction de ciel vue par le panneau — un champ à
    /// contre-jour garde donc un fond diffus au lieu de tomber à zéro en plein
    /// jour, et un champ face au soleil couchant ne prétend pas être au maximum.
    static func planeOfArrayFactor(sunElevation: Double, sunAzimuth: Double,
                                   tilt: Double, azimuth: Double) -> Double {
        guard sunElevation > 0 else { return 0 }
        let direct = directShare
            * max(0, cosIncidence(sunElevation: sunElevation, sunAzimuth: sunAzimuth,
                                  tilt: tilt, azimuth: azimuth))
            * atmosphericTransmittance(sunElevation: sunElevation)
        let skyView = (1 + cos(rad(tilt))) / 2
        let diffuse = (1 - directShare) * sin(rad(sunElevation)) * skyView
        return direct + diffuse
    }

    static func planeOfArrayFactor(for array: PanelArray,
                                   sunElevation: Double, sunAzimuth: Double) -> Double {
        planeOfArrayFactor(sunElevation: sunElevation, sunAzimuth: sunAzimuth,
                           tilt: array.tilt, azimuth: array.azimuth)
    }

    /// Productible ciel clair d'un champ (W).
    static func clearSkyWatts(for array: PanelArray,
                              sunElevation: Double, sunAzimuth: Double) -> Double {
        array.peakWatts * planeOfArrayFactor(for: array,
                                             sunElevation: sunElevation,
                                             sunAzimuth: sunAzimuth) * systemEfficiency
    }

    /// Productible ciel clair de l'installation entière (W).
    static func clearSkyWatts(for arrays: [PanelArray],
                              sunElevation: Double, sunAzimuth: Double) -> Double {
        arrays.reduce(0) { total, array in
            total + clearSkyWatts(for: array, sunElevation: sunElevation, sunAzimuth: sunAzimuth)
        }
    }

    /// Instant de meilleure production d'un champ sur la course fournie.
    static func bestMoment(for array: PanelArray,
                           track: [SunCalc.Position]) -> (date: Date, watts: Double)? {
        var best: (date: Date, watts: Double)?
        for position in track where position.elevation > 0 {
            let watts = clearSkyWatts(for: array,
                                      sunElevation: position.elevation,
                                      sunAzimuth: position.azimuth)
            if watts > (best?.watts ?? 0) {
                best = (position.date, watts)
            }
        }
        return best
    }

    /// Énergie ciel clair sur la journée (Wh), intégrée le long de la course.
    static func clearSkyEnergyWh(for arrays: [PanelArray],
                                 track: [SunCalc.Position]) -> Double {
        guard arrays.isEmpty == false, track.count > 1 else { return 0 }
        let stepHours = track[1].date.timeIntervalSince(track[0].date) / 3600
        return track.reduce(0) { total, position in
            guard position.elevation > 0 else { return total }
            return total + clearSkyWatts(for: arrays,
                                         sunElevation: position.elevation,
                                         sunAzimuth: position.azimuth) * stepHours
        }
    }

    /// Contour d'iso-incidence : les directions du ciel formant exactement
    /// l'angle `angle` avec la normale du panneau. Tracé tel quel dans le dôme
    /// et le compas, il dessine la zone où ce champ travaille près de son
    /// optimum — un cercle autour de la normale, déformé par la projection.
    static func incidenceLocus(tilt: Double, azimuth: Double, angle: Double,
                               samples: Int = 60) -> [(azimuth: Double, elevation: Double)] {
        // Repère orthonormé (normale, u, v) ; x vers l'est, y vers le nord, z au zénith.
        let normalElevation = rad(90 - tilt)
        let normalAzimuth = rad(azimuth)
        let n = (x: cos(normalElevation) * sin(normalAzimuth),
                 y: cos(normalElevation) * cos(normalAzimuth),
                 z: sin(normalElevation))
        let u = (x: cos(normalAzimuth), y: -sin(normalAzimuth), z: 0.0)
        let v = (x: u.y * n.z - u.z * n.y,
                 y: u.z * n.x - u.x * n.z,
                 z: u.x * n.y - u.y * n.x)

        let theta = rad(angle)
        return (0...max(8, samples)).map { step in
            let phi = 2 * Double.pi * Double(step) / Double(max(8, samples))
            let spread = (cos: cos(phi) * sin(theta), sin: sin(phi) * sin(theta))
            let x = n.x * cos(theta) + u.x * spread.cos + v.x * spread.sin
            let y = n.y * cos(theta) + u.y * spread.cos + v.y * spread.sin
            let z = n.z * cos(theta) + u.z * spread.cos + v.z * spread.sin
            var skyAzimuth = deg(atan2(x, y))
            if skyAzimuth < 0 { skyAzimuth += 360 }
            return (azimuth: skyAzimuth, elevation: deg(asin(min(1, max(-1, z)))))
        }
    }

    /// Masse d'air relative traversée (Kasten & Young 1989) : 1 au zénith,
    /// ~38 à l'horizon. `nil` sous l'horizon.
    static func airMass(sunElevation: Double) -> Double? {
        guard sunElevation > 0 else { return nil }
        return 1 / (sin(rad(sunElevation)) + 0.50572 * pow(sunElevation + 6.07995, -1.6364))
    }

    /// Longueur de l'ombre d'un objet d'une unité de haut. `nil` sous l'horizon.
    static func shadowRatio(sunElevation: Double) -> Double? {
        guard sunElevation > 0.5 else { return nil }
        return 1 / tan(rad(sunElevation))
    }

    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / .pi }
}
