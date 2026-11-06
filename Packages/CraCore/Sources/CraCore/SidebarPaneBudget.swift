import CoreGraphics

/// How tall a space's pinned pane is when the sidebar shows the pinned tabs and Today as two
/// scrolling panes (Cra's own arrangement; Arc scrolls them as one list).
///
/// The pins take what they need while Today keeps its content; today's content is never taken
/// by the pins when it fits. When both overflow, the pins keep at least `pinnedShare` of the
/// room, so a long pinned list never leaves Today a sliver.
///
/// `available` is the column's list area less the divider. `pinnedContent` and `todayContent`
/// are the panes' own content heights, including their top insets.
public struct SidebarPaneBudget: Equatable {
    /// The pins' least share of the room when both lists have more than fits.
    public static let pinnedShare: CGFloat = 0.55

    public let pinned: CGFloat
    public let today: CGFloat

    public init(available: CGFloat, pinnedContent: CGFloat, todayContent: CGFloat) {
        let room = max(0, available)
        let pins = max(0, pinnedContent)
        let wantsToday = max(0, todayContent)
        let allowed = max(room * Self.pinnedShare, room - wantsToday)
        pinned = min(pins, allowed)
        today = room - pinned
    }
}
