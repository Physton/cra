import CoreGraphics
import CraCore
import Testing

/// The split between the pinned and Today panes: the pins take what they need, Today keeps its
/// content when it fits, and the pins never fall below their share when both overflow.
struct SidebarPaneBudgetTests {
    @Test func bothFitKeepTheirContent() {
        let b = SidebarPaneBudget(available: 500, pinnedContent: 123, todayContent: 82)
        #expect(b.pinned == 123)
        #expect(b.today == 377)
    }

    @Test func shortTodayLeavesTheRestToPins() {
        // New Tab alone is 41 pt: the pins take everything else rather than a 55 % cap.
        let b = SidebarPaneBudget(available: 500, pinnedContent: 600, todayContent: 41)
        #expect(b.pinned == 459)
        #expect(b.today == 41)
    }

    @Test func emptyTodayLeavesEverythingToPins() {
        let b = SidebarPaneBudget(available: 500, pinnedContent: 600, todayContent: 0)
        #expect(b.pinned == 500)
        #expect(b.today == 0)
    }

    @Test func bothOverflowPinsKeepTheirShare() {
        let b = SidebarPaneBudget(available: 500, pinnedContent: 600, todayContent: 300)
        #expect(b.pinned == 275)
        #expect(b.today == 225)
    }

    @Test func longTodayStillLeavesPinsTheirShare() {
        let b = SidebarPaneBudget(available: 500, pinnedContent: 600, todayContent: 450)
        #expect(b.pinned == 275)
        #expect(b.today == 225)
    }

    @Test func onlyTodayTakesTheRoom() {
        let b = SidebarPaneBudget(available: 500, pinnedContent: 3, todayContent: 200)
        #expect(b.pinned == 3)
        #expect(b.today == 497)
    }

    @Test func noRoomGivesNoPins() {
        let b = SidebarPaneBudget(available: 0, pinnedContent: 600, todayContent: 300)
        #expect(b.pinned == 0)
        #expect(b.today == 0)
    }

    @Test func negativeInputsAreClamped() {
        let b = SidebarPaneBudget(available: -10, pinnedContent: -1, todayContent: -2)
        #expect(b.pinned == 0)
        #expect(b.today == 0)
    }

    @Test func shortPinsKeepTheirHeight() {
        let b = SidebarPaneBudget(available: 500, pinnedContent: 100, todayContent: 0)
        #expect(b.pinned == 100)
        #expect(b.today == 400)
    }

    @Test func paneHeightsFillTheRoom() {
        for available in stride(from: 0.0, through: 900.0, by: 37) {
            for pins in stride(from: 0.0, through: 900.0, by: 61) {
                let b = SidebarPaneBudget(available: available, pinnedContent: pins, todayContent: 120)
                #expect(abs(b.pinned + b.today - available) < 0.0001)
                #expect(b.pinned >= 0 && b.today >= 0)
                #expect(b.pinned <= pins)
            }
        }
    }
}
