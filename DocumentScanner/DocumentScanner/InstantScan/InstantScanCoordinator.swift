import Foundation
import Observation
import UIKit

/// Hand-off point for an instant scan (Action button, Control, Siri).
/// The App Intent requests a scan; the presenter, save pipeline and lock gate
/// advance it. Transitions that don't apply to the current phase are silent
/// no-ops, so a duplicate trigger can never disturb a scan already in flight.
@MainActor
@Observable
final class InstantScanCoordinator {

    static let shared = InstantScanCoordinator()

    enum Phase: Equatable {
        case idle
        case requested
        case capturing
        case saving
        case saved(URL)
    }

    private(set) var phase: Phase = .idle

    /// Pages held while saving, and kept after a failure so Retry can reuse them.
    private(set) var capturedImages: [UIImage] = []

    /// True while a scan is in flight. `.saved` is not busy: the document is
    /// on disk and only waiting for the lock gate to open it.
    var isBusy: Bool {
        switch phase {
        case .requested, .capturing, .saving: return true
        case .idle, .saved: return false
        }
    }

    init() {}

    /// idle → requested; otherwise ignored.
    func request() {
        guard phase == .idle else { return }
        phase = .requested
    }

    /// requested → capturing. Returns false from any other phase.
    func beginCapture() -> Bool {
        guard phase == .requested else { return false }
        phase = .capturing
        return true
    }

    /// requested / capturing / saving → idle.
    func cancel() {
        guard isBusy else { return }
        phase = .idle
        capturedImages = []
    }

    /// capturing → saving, keeping the images for a possible Retry.
    func beginSaving(images: [UIImage]) {
        guard phase == .capturing else { return }
        capturedImages = images
        phase = .saving
    }

    /// saving → saved(url); the images are no longer needed.
    func saveSucceeded(url: URL) {
        guard phase == .saving else { return }
        capturedImages = []
        phase = .saved(url)
    }

    /// saving → capturing, with `capturedImages` kept so Retry can call
    /// `beginSaving(images: capturedImages)` again and Cancel can `cancel()`.
    func saveFailed() {
        guard phase == .saving else { return }
        phase = .capturing
    }

    /// The saved document, once the app is unlocked. Nil while locked or
    /// before a save has finished.
    func documentToOpen(isLocked: Bool) -> URL? {
        guard case .saved(let url) = phase, !isLocked else { return nil }
        return url
    }

    /// saved → idle, after the document has been opened.
    func markOpened() {
        guard case .saved = phase else { return }
        phase = .idle
    }

    /// Returns the shared coordinator to a clean idle state between tests.
    internal func resetForTesting() {
        phase = .idle
        capturedImages = []
    }
}
