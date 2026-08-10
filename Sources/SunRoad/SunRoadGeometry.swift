import Foundation

/// Passage des coordonnées solaires (azimut/élévation, convention SunCalc :
/// 0° = nord, 90° = est) vers le repère 3D de la scène SunRoad.
///
/// Repère SceneKit : Y vers le haut, nord = -Z, est = +X — ainsi une caméra
/// placée au sud et regardant l'origine voit le nord au fond, l'est à droite,
/// comme sur une carte.
///
/// Fonctions pures, testées sans SceneKit.
enum SunRoadGeometry {
    struct Point3: Equatable {
        var x: Double
        var y: Double
        var z: Double
    }

    /// Point sur la voûte de rayon `radius` pour un azimut/élévation en degrés.
    static func domePoint(azimuth: Double, elevation: Double, radius: Double) -> Point3 {
        let az = azimuth * .pi / 180
        let el = elevation * .pi / 180
        return Point3(
            x: radius * cos(el) * sin(az),
            y: radius * sin(el),
            z: -radius * cos(el) * cos(az)
        )
    }

    /// Surface (m²) d'un champ de panneaux estimée depuis sa puissance crête
    /// (~200 Wc/m², densité courante des modules résidentiels), bornée pour
    /// rester lisible dans la scène.
    static func panelArea(peakWatts: Double) -> Double {
        min(max(peakWatts / 200, 1), 40)
    }

    /// Facteur de luminosité du jour [0…1] selon l'élévation du soleil —
    /// pilote l'intensité des lumières et la couleur du ciel. Rampe douce
    /// de -6° (crépuscule civil) à +15°.
    static func daylightFactor(elevation: Double) -> Double {
        let t = (elevation + 6) / 21
        return min(max(t, 0), 1)
    }
}
