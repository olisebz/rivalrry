import Foundation
import CoreImage.CIFilterBuiltins
import UIKit

/// Invite links and QR codes (plan.md §4 S4). Until there is a domain for Universal Links,
/// the link uses the app's own scheme: `rivalrry://invite/<username>`.
enum Invite {
    static let scheme = "rivalrry"

    static func url(for username: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "invite"
        components.path = "/\(username)"
        // A valid username only has a–z, 0–9 and _, so this can't fail.
        return components.url ?? URL(string: "\(scheme)://invite")!
    }

    /// The username in an invite link, or `nil` if it isn't one (also for scanned QR codes).
    static func username(from url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme, url.host?.lowercased() == "invite" else { return nil }
        let username = Username.cleaned(url.lastPathComponent)
        return Username.validate(username) == nil ? username : nil
    }

    static func username(from text: String) -> String? {
        URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { username(from: $0) }
    }

    /// Black-on-white QR code for the invite link, scaled up without blurring.
    static func qrCode(for username: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url(for: username).absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: image)
    }
}
