import SwiftUI
import Vision
import VisionKit

/// "Scan QR Code" (plan.md §4 S4): camera scanner; a scanned invite opens the profile.
struct ScanQRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scannedUsername: String?

    var body: some View {
        NavigationStack {
            Group {
                if QRScanner.isAvailable {
                    QRScanner { username in
                        if scannedUsername == nil { scannedUsername = username }
                    }
                    .ignoresSafeArea()
                } else {
                    EmptyStateView(symbol: "camera",
                                   message: QRScanner.isSupported
                                       ? "Allow camera access in Settings to scan QR codes."
                                       : "Scanning isn't available on this device.")
                        .background(Color.rvBackground)
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $scannedUsername) { username in
                InviteProfileView(username: username)
            }
        }
        .tint(Color.rvAccent)
    }
}

/// VisionKit's `DataScannerViewController`, limited to QR codes that are RIVALRRY invites.
private struct QRScanner: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    static var isSupported: Bool { DataScannerViewController.isSupported }
    /// `false` without a camera or without camera permission.
    static var isAvailable: Bool { isSupported && DataScannerViewController.isAvailable }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                                qualityLevel: .balanced,
                                                isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onScan = onScan
        // Scanning can only start once the view is on screen.
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScan: (String) -> Void

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in addedItems {
                // Other QR codes are ignored.
                if case .barcode(let barcode) = item,
                   let payload = barcode.payloadStringValue,
                   let username = Invite.username(from: payload) {
                    onScan(username)
                    return
                }
            }
        }
    }
}
