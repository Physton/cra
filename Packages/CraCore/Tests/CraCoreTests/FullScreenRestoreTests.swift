import CoreGraphics
import CraCore
import Foundation
import Testing

struct FullScreenRestoreTests {
    @Test func windowsComeBackOneAtATime() {
        let first = UUID(), second = UUID()
        var restore = FullScreenRestore([first, second])
        #expect(restore.next() == first)
        #expect(restore.next() == nil, "a request made during another window's transition fails")
        restore.ended(entered: true)
        #expect(restore.next() == second)
        restore.ended(entered: true)
        #expect(restore.next() == nil)
        #expect(restore.current == nil)
    }

    @Test func aFailedRequestIsTriedOnceMoreAfterTheOthers() {
        let first = UUID(), second = UUID()
        var restore = FullScreenRestore([first, second])
        #expect(restore.next() == first)
        restore.ended(entered: false)
        #expect(restore.next() == second, "the window behind it goes first")
        restore.ended(entered: true)
        #expect(restore.next() == first, "then the one AppKit refused")
        restore.ended(entered: false)
        #expect(restore.next() == nil, "once, not forever")
    }

    @Test func addingAWindowAlreadyQueuedOrRunningKeepsOneCopy() {
        let first = UUID(), second = UUID()
        var restore = FullScreenRestore()
        restore.add(first)
        restore.add(second)
        restore.add(first)
        #expect(restore.next() == first)
        restore.add(first)
        restore.ended(entered: true)
        #expect(restore.next() == second)
        #expect(restore.next() == nil)
    }

    @Test func windowedFrameStaysOnTheDisplayItWasFullScreenOn() {
        let windowed = CGRect(x: 221, y: 67, width: 1291, height: 880)
        let first = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let second = CGRect(x: 1728, y: 0, width: 1920, height: 1080)

        #expect(FullScreenWindowFrame.windowedFrame(windowed, saved: windowed, on: first) == windowed)

        let moved = FullScreenWindowFrame.windowedFrame(windowed, saved: windowed, on: second)
        #expect(moved.size == windowed.size, "the window comes back the size it was")
        #expect(moved.midX == second.midX && moved.midY == second.midY, "centred on the display it was full screen on")
    }

    @Test func windowedFrameWithoutASavedOneCentresItsSize() {
        let windowed = CGRect(x: 0, y: 0, width: 1291, height: 880)
        let display = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let frame = FullScreenWindowFrame.windowedFrame(windowed, saved: nil, on: display)
        #expect(frame.size == windowed.size)
        #expect(frame.midX == display.midX && frame.midY == display.midY)
    }
}
