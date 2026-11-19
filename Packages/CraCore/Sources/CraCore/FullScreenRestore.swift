import CoreGraphics
import Foundation

/// Windows that quit in full screen come back to it one at a time.
///
/// macOS fails a window's request to enter full screen while another window's transition is
/// still running (`windowDidFailToEnterFullScreen`), so at launch, when every window that quit
/// in full screen asked at once, only the first one got there and the others stayed windowed.
/// The next window asks when the one before it has finished; a request that failed is tried
/// once more, after the windows waiting behind it.
public struct FullScreenRestore: Equatable {
    private var pending: [UUID]
    private var retried: Set<UUID> = []
    /// The window in a full-screen transition now, if any.
    public private(set) var current: UUID?

    public init(_ ids: [UUID] = []) {
        pending = ids
    }

    /// Queues a window, unless it is the one in transition or already waiting.
    public mutating func add(_ id: UUID) {
        guard id != current, !pending.contains(id) else { return }
        pending.append(id)
    }

    /// The window to put in full screen now; nil while another window is in transition, or when
    /// none is left.
    public mutating func next() -> UUID? {
        guard current == nil, !pending.isEmpty else { return nil }
        current = pending.removeFirst()
        return current
    }

    /// The current window's transition ended. A failed request goes to the end of the queue once.
    public mutating func ended(entered: Bool) {
        guard let current else { return }
        self.current = nil
        if !entered, retried.insert(current).inserted { pending.append(current) }
    }
}

/// Where a window that quit in full screen opens next time.
public enum FullScreenWindowFrame {
    /// The windowed frame windows.json keeps while a window is in full screen: the frame it had
    /// on the display it is full screen on, or, when that frame is on another display (a
    /// full-screen Space carried across in Mission Control), its size centred on this display.
    public static func windowedFrame(_ windowed: CGRect, saved: CGRect?, on display: CGRect) -> CGRect {
        if let saved, saved.intersects(display) { return saved }
        return CGRect(x: display.midX - windowed.width / 2, y: display.midY - windowed.height / 2,
                      width: windowed.width, height: windowed.height)
    }
}
