import SwiftUI

/// Section de réglages listant les champs de panneaux : un champ par orientation
/// de toiture, avec sa puissance crête, son azimut et son inclinaison.
///
/// Extraite de `SunSettingsTab` pour être testable et capturable seule : c'est la
/// seule partie des réglages qui porte une vraie logique d'état (chargement du
/// store, liaison par identité, écriture des deux clés persistées).
struct PanelArraysSection: View {
    @AppStorage("sunPeakWatts") private var sunPeakWatts: Double = 0
    @AppStorage(PanelArrayStore.key) private var arraysJSON: String = ""
    @State private var arrays: [PanelArray] = []
    @State private var loaded = false

    var body: some View {
        Section("Champs de panneaux") {
            ForEach(Array(arrays.enumerated()), id: \.element.id) { index, array in
                PanelArrayEditor(array: binding(for: array.id), index: index) {
                    arrays.removeAll { $0.id == array.id }
                }
            }
            HStack {
                Button("Ajouter un champ", systemImage: "plus") {
                    arrays.append(PanelArray(peakWatts: 400, azimuth: 180, tilt: 30))
                }
                Spacer()
                if arrays.isEmpty == false {
                    Text("Total : \(Format.watts(arrays.reduce(0) { $0 + $1.peakWatts })) crête")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text("Un champ par orientation de toiture. Azimut : 0° = nord, 90° = est, 180° = plein sud, 270° = ouest. Inclinaison : 0° à plat, 30° pour une toiture courante, 90° en façade. La fenêtre Soleil en déduit l'incidence du soleil sur chaque champ, son productible ciel clair et sa meilleure heure.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            guard loaded == false else { return }
            arrays = PanelArrayStore.load()
            loaded = true
        }
        .onChange(of: arrays) {
            guard loaded else { return }
            arraysJSON = PanelArrayStore.encode(arrays)
            // La clé historique reste le total installé : elle sert de repli et
            // reste lisible par les versions antérieures de l'app. On ne la
            // remet jamais à zéro : supprimer tous ses champs ne doit pas
            // effacer la puissance crête saisie avant la mise à jour.
            let total = arrays.reduce(0) { $0 + $1.peakWatts }
            if total > 0 { sunPeakWatts = total }
        }
    }

    /// Liaison par identité plutôt que par indice : la suppression d'un champ
    /// ne peut pas faire écrire une ligne à côté.
    private func binding(for id: UUID) -> Binding<PanelArray> {
        Binding(
            get: { arrays.first { $0.id == id } ?? PanelArray(peakWatts: 0) },
            set: { updated in
                guard let index = arrays.firstIndex(where: { $0.id == id }) else { return }
                arrays[index] = updated
            }
        )
    }
}

/// Éditeur d'un champ de panneaux : nom libre, puissance crête, azimut (avec
/// son libellé cardinal) et inclinaison.
struct PanelArrayEditor: View {
    @Binding var array: PanelArray
    var index: Int
    var remove: () -> Void

    /// Dans un `Form` groupé, chaque vue d'une ligne est répartie entre colonne
    /// de libellé et colonne de contenu : un `VStack` se ferait éclater en
    /// lignes désalignées. On compose donc explicitement une ligne d'en-tête
    /// pleine largeur puis deux `LabeledContent` pour les curseurs.
    var body: some View {
        HStack(spacing: 8) {
            PanelGlyph(color: ArrayPalette.color(index))
                .frame(width: 18, height: 14)
            TextField("Nom", text: $array.name, prompt: Text("Champ \(index + 1)"))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
            TextField("Wc", value: $array.peakWatts, format: .number)
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .frame(width: 68)
                .monospacedDigit()
            Text("Wc")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(role: .destructive) { remove() } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(Text("Supprimer ce champ"))
        }
        LabeledContent {
            Slider(value: $array.azimuth, in: 0...360, step: 5)
        } label: {
            Text("Azimut \(Int(array.azimuth.rounded()))° — \(Cardinal.label(azimuth: array.azimuth))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        LabeledContent {
            Slider(value: $array.tilt, in: 0...90, step: 1)
        } label: {
            Text("Inclinaison \(Int(array.tilt.rounded()))°")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
