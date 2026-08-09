import Foundation

/// Le jeton « Authorization Cloud Key » copié depuis l'app Zendure
/// (Profil → Authorization Cloud Key) est du base64 qui décode en
/// `"<apiUrl>.<appKey>"`, à découper sur le DERNIER point — l'URL contient
/// elle-même des points, et elle encode déjà la région (EU vs global).
struct CloudKey: Equatable {
    let apiUrl: URL
    let appKey: String

    enum DecodeError: LocalizedError {
        case notBase64
        case malformed

        var errorDescription: String? {
            switch self {
            case .notBase64: return String(localized: "Le jeton n'est pas du base64 valide.")
            case .malformed: return String(localized: "Le jeton décodé n'a pas la forme attendue (URL.appKey).")
            }
        }
    }

    static func decode(_ token: String) throws -> CloudKey {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        // Padding base64 parfois absent dans les jetons copiés.
        let padded = trimmed.padding(
            toLength: ((trimmed.count + 3) / 4) * 4,
            withPad: "=",
            startingAt: 0
        )
        guard let data = Data(base64Encoded: padded),
              let decoded = String(data: data, encoding: .utf8) else {
            throw DecodeError.notBase64
        }
        guard let lastDot = decoded.lastIndex(of: "."), lastDot != decoded.startIndex else {
            throw DecodeError.malformed
        }
        let urlPart = String(decoded[decoded.startIndex..<lastDot])
        let appKey = String(decoded[decoded.index(after: lastDot)...])
        guard !appKey.isEmpty, let url = URL(string: urlPart), url.scheme?.hasPrefix("http") == true else {
            throw DecodeError.malformed
        }
        return CloudKey(apiUrl: url, appKey: appKey)
    }
}
