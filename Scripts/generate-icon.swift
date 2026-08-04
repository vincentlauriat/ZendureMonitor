import SwiftUI

struct IconView: View {
    var body: some View {
        ZStack {
            // Marge macOS standard : contenu 824/1024, coins ~185.
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.07, green: 0.19, blue: 0.34),
                                 Color(red: 0.04, green: 0.36, blue: 0.47)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 12)

            VStack(spacing: 40) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 380, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(red: 1.0, green: 0.85, blue: 0.2),
                                                Color(red: 1.0, green: 0.62, blue: 0.1)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: Color(red: 1.0, green: 0.75, blue: 0.2).opacity(0.55), radius: 46)

                // Jauge batterie stylisée
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(.white.opacity(0.22))
                        .frame(width: 430, height: 108)
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(colors: [Color(red: 0.3, green: 0.85, blue: 0.4),
                                                    Color(red: 0.15, green: 0.7, blue: 0.35)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: 300, height: 76)
                        .padding(.leading, 16)
                }
            }
            .offset(y: -8)
        }
        .frame(width: 1024, height: 1024)
    }
}

MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: IconView())
    renderer.scale = 1
    guard let img = renderer.nsImage, let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { fatalError("render failed") }
    try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    print("icon written")
}
