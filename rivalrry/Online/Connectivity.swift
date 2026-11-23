import Foundation
import Network
import SwiftUI

/// Whether the device has a network connection (plan.md §6.1 "Offline"). When it comes back,
/// `RootView` syncs, which sends everything that waited.
@Observable
final class Connectivity {
    private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    static let shared = Connectivity()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            // Started on the main queue, so this runs on the main actor.
            MainActor.assumeIsolated { self?.isOnline = path.status == .satisfied }
        }
        monitor.start(queue: .main)
    }
}

extension EnvironmentValues {
    @Entry var connectivity: Connectivity = Connectivity.shared
}
