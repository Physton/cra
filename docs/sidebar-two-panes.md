# Sidebar: Pinned and Today are two panes

**Read this before merging upstream changes to `Sources/Cra/UI/Sidebar/List/`.** The sidebar
deliberately draws a space's pinned tabs and Today as two independent scroll panes. Upstream
(and Arc) draw them as one scrolling list. A merge that takes upstream's single `SpaceListView`
wholesale silently removes the feature.

## In one paragraph

`SpaceColumnView` stacks two `SpaceListView`s: one with `scope: .pinned`, one with
`scope: .today`. A fixed 18 pt band (`SidebarSectionDividerView`, which hosts the existing
`DividerRowView`) sits between them and does not scroll with either. The pinned pane takes its
rows' height; when both lists overflow it keeps at least 55 % of the list area, and Today gets
the rest. The panes scroll strictly independently (no scroll chaining). Drag and drop works
across both, including onto the band. `SidebarPaneBudget` in CraCore owns the height split and
is tested. The Spaces page (`SpacesManagerView`) still uses one `.all` list, as upstream does.

## Product decision

Chosen 6 Nov 2026, on top of `94c1fc3`:

- regions: **Pinned** and **Today** (favorites stay fixed above, untouched);
- pinned height: **content-adaptive**; when both lists overflow, pinned keeps at least 55 % of
  the list area, not a fixed ratio;
- scrolling: **strictly independent**, no chaining from one pane into the other;
- drag: **full cross-pane** support (pin, unpin, drop on the band, autoscroll, insertion line).

This is a deliberate departure from Arc's one-list sidebar. `CONTRIBUTING.md` says Arc parity
by default; this is the exception, not a bug. Do not "restore" Arc's single list during a
merge, and do not add scroll chaining without a new product decision.

## Upstream

`origin` is this fork (`Physton/cra`); `upstream` is `VictorKildahl/cra`. Fetch and merge
`upstream/main` as usual. Upstream's commits know nothing about the two panes; after resolving
conflicts, walk the invariants below before building.

## Shape

```
SpaceColumnView
├─ FavoritesGridView              fixed, unchanged
├─ SpaceHeaderView                fixed, unchanged
├─ SpaceListView(scope: .pinned)  independent scroll view
├─ SidebarSectionDividerView      18 pt fixed band, DividerRowView inside, drop target
└─ SpaceListView(scope: .today)   independent scroll view, fills the rest
```

Terms used below:

- **pane**: one `SpaceListView` with `.pinned` or `.today`; one `NSScrollView` and one
  document each.
- **band**: `SidebarSectionDividerView`, the fixed divider between the panes.
- **`.all`**: the old combined list (pinned + divider + Today), kept only for the Spaces page.

## Files and symbols

| Path | What this feature puts there |
|---|---|
| `Sources/Cra/UI/Sidebar/List/SpaceColumnView.swift` | `pinnedList`, `todayList`, `divider`; `place(animated:)` sizes them; `observeDivider()`, `contentHeightChanged()`, `scrollerStyleChanged()`; private `SidebarSectionDividerView` |
| `Sources/Cra/UI/Sidebar/List/SpaceListView.swift` | `scope`, `contentHeight(forWidth:)`, `onContentHeightChange`, `contentTopInset`, `rowsInset`, `measuredContentHeight`; `layoutAllRows()` / `layoutPaneRows()`; scope-aware `build()`, `resolve()`, `performDrop()`, `dragExited()` |
| `Sources/Cra/UI/Sidebar/SidebarListDrop.swift` | `SidebarListScope`; `SidebarListDrop.scope`; `SidebarListDrop.fromDivider` |
| `Packages/CraCore/Sources/CraCore/SidebarPaneBudget.swift` | the height split; `pinnedShare = 0.55` |
| `Packages/CraCore/Tests/CraCoreTests/SidebarPaneBudgetTests.swift` | the split's tests |

Reused without modification: `SidebarRowViews.swift` (`DividerRowView` is now hosted by the
band), `SidebarMenus.swift`, `FolderPreview.swift`, `SpacePagerView.swift`,
`SpacesManagerView.swift`.

No data-folder format changed. `sidebar.json`, `settings.json` and `windows.json` are untouched;
there is no migration to preserve.

## Invariants

1. **Two panes, one `.all`.** `SpaceColumnView` must create both `SpaceListView`s with
   `.pinned` and `.today`. `.all` is only for `SpacesManagerView` (and its card layout). If
   `SpaceColumnView` ends up with one list again, the feature is gone.
2. **The budget decides height.** Do not inline a different split in the view. The formula is
   `pinned = min(pinnedContent, max(available * 0.55, available - todayContent))`; Today gets
   `available - pinned`. `available` excludes the band. The constant is
   `SidebarPaneBudget.pinnedShare`.
3. **The band is not a row.** `SidebarSectionDividerView` is a sibling of both panes. Putting
   `DividerRowView` back into either document makes it scroll away and removes the fixed
   boundary and its drop target.
4. **Each pane builds only its own section.** Keep the `scope != .today` / `scope != .pinned`
   guards in `build()`. The divider row is appended only in `.all`.
5. **Keep the 3/4 pt and 0/1 pt insets.** `paneTopInset` reproduces upstream's one-list
   spacing: pinned rows start at 3 pt + 1 pt row gap; Today starts at the band's bottom, or 1 pt
   below when the band is hidden (Today empty). `todayList.contentTopInset` is set by the column.
6. **The 121 pt tail belongs to Today only.** `layoutPaneRows()` uses `tail = 0` for `.pinned`
   and `121` for `.today`. A tail on the pinned pane creates a large empty scroll region.
7. **Drop ownership.** Every `SidebarListDrop` carries `scope`; a pane draws decor, insertion
   line and section highlight only for its own scope. `fromDivider` marks the band's drop so a
   pane's `dragExited()` cannot clear it. `performDrop()` uses the shared drop only when
   `scope` matches and `!fromDivider`; otherwise it resolves locally.
8. **One legacy-scroller gutter for both panes.** `SpaceColumnView` sets `rowsInset = 8` on both
   when `NSScroller.preferredScrollerStyle == .legacy`. Per-pane `legacyScrollerShown` makes one
   pane's rows 8 pt narrower than the other's when only one overflows.
9. **Measurement and layout agree.** `contentHeight(forWidth:)` and `layoutPaneRows()` must use
   the same row heights, including `LiveStatusRowView.height(_:width:)`. A new variable-height
   row must update both.
10. **The column learns about height changes through `onContentHeightChange`.** Without it the
    band and Today do not move when pinned rows are added, removed, expanded or collapsed.
11. **Jump pill per pane.** `updateJumpPill` hides it when the pane is under 2 rows; the pill
    only scrolls the pane that owns the selected row.
12. **Pinned pane bounce is off.** `verticalScrollElasticity = .none` for `.pinned`; its edges
    are internal, and a bounce would open a gap at the band. Today keeps `.allowed`.
13. **Empty pinned is still a drop target.** When pinned is empty, the pane keeps its 3 pt inset
    and expands to a one-row placeholder as soon as `ui.draggingID` is set, before the pointer
    can enter a 0 pt view.

## Merge playbook

Upstream (as of `94c1fc3`) edits `SpaceListView` as one list. Treat upstream as the source of
truth for row rendering, hover, drag, autoscroll and Arc metrics; re-apply the scope split
around it.

### `SpaceListView.swift` (the largest conflict)

- `build()`: keep upstream's row construction; place pinned rows behind `scope != .today`,
  Today rows and the New Tab row behind `scope != .pinned`, and the divider row behind
  `scope == .all`. New upstream row types must be assigned to a section deliberately (a pinned
  folder and a Today folder both go through the same `add`).
- `layoutRows()`: upstream's version is `layoutAllRows()`. Port any new metric, divider height or
  special case into `layoutPaneRows()` **and** `contentHeight(forWidth:)` in the same commit.
- `resolve()`: every return path must set `scope`. The pane-specific fallback (past the last
  row) appends to its own container; the `.all` divider-midpoint branch stays for the Spaces
  page. A new `SidebarListDrop.Target` case must be understood by the panes and the band.
- `dragUpdated` / `performDrop` / `dragExited`: keep `scope` on the resolved drop and the
  `!drop.fromDivider` checks. Removing them makes both panes draw lines at once or clear each
  other's drops.
- `updateJumpPill`: keep the short-pane guard.
- `rowsWidth`: keep `rowsInset` as the column's override; do not revert to per-pane detection
  for the panes.
- `contentHeight(forWidth:)`: keep it independent of the pane's current frame; the column calls
  it before placing the panes.

### `SpaceColumnView.swift`

- Keep the two panes and the band. Port upstream's favorites/header placement (`place`) and
  `holdFavorites` unchanged; only the part below `top` is ours.
- The divider's height is `18` when Today has items, `0` otherwise; if upstream changes the
  divider's metrics, change `dividerHeight` and the band together.
- `observeDivider()` uses CraCore's `observeChanges` because `scripts/lint.py` limits raw
  `withObservationTracking` sites in this file. A third raw site fails lint.
- `contentHeightChanged()` must not animate during a drag (`ui.draggingID != nil`), so the
  pinned placeholder follows the pointer.

### `SidebarListDrop.swift`

- Keep `SidebarListScope` and both fields. If upstream adds fields, append them; `Equatable` is
  synthesized and the panes compare drops every `draggingUpdated`.
- The band sets `fromDivider: true`; panes never do.

### `SidebarRowViews.swift` and the divider

- `DividerRowView` must remain usable outside a list: the band owns it, calls `apply(...)`,
  `setColors(...)`, and drives `isHovered` from its own tracking area. If upstream makes it
  depend on `list.rows` or on being a row in a document, adapt the band rather than moving the
  row back into a pane.
- `SidebarMenus.spaceList` needs `list.header`; both panes get the same header, so menus keep
  working.

### `SpacesManagerView` and `.all`

- `.all` must stay upstream's one-list behavior. The Spaces page is not part of this feature.
  If upstream changes `.all`, take it; only the `.pinned`/`.today` paths are ours.

### When upstream is heavily refactored

If upstream rewrites `SpaceListView` beyond recognition, do not resolve line by line. Rebuild
the split on top of the new list: one instance per section, a column-level band, the budget, and
the drop ownership. The invariants above are the contract; the diff is replaceable.

## Verification after a merge

Commands (normal repo commands; `scripts/test.sh` runs the full set):

    swift test --package-path Packages/CraCore     # includes SidebarPaneBudgetTests
    scripts/build.sh debug
    scripts/lint.py

Manual matrix (the feature is visual; tests do not cover the scroll views):

- 1 pinned, 14 pinned, 0 pinned; 0, 1 and 25 Today tabs.
- Wheel/trackpad in the pinned pane: only pinned moves; at its edges it stops (no chaining,
  no bounce).
- Wheel/trackpad in Today: only Today moves; at its bottom edge it bounces, and it never
  continues into the pinned pane.
- Collapse pinned from the space header; expand again. Band and Today move; Today keeps its
  scroll offset.
- Clear Today: band disappears, New Tab sits directly under pinned, pinned takes the freed room.
- Select a pinned tab then a Today tab: only the owning pane reveals the row; the jump pill
  appears in that pane, not the other.
- Drag Today → pinned (above/below a row, middle for a split), pinned → Today, and onto both
  halves of the band. Check the insertion line/highlight is drawn by one pane only, and
  autoscroll near a pane edge.
- Hover the band: Clear and Tidy Tabs appear; Tidy still animates the squiggle.
- Resize the window narrow and short; hide the space header (single-space mode); no favorites.
- Settings ▸ "Show scroll bars: Always": both panes' rows and the band's line line up.
- Spaces page (Library ▸ Spaces): still one list per card, unchanged.
- Space swipe and the Library overlay still move/cover both panes together.

If a step fails, compare with the introducing commit's version before changing the design.

## Red flags in a merge

- `SpaceColumnView` has a single `list` again, or `pinnedList`/`todayList` share one scroll view.
- Both panes show an insertion line at the same time.
- `ui.listDrop` is cleared by any `dragExited`, not only by its owner.
- The 121 pt tail appears in the pinned pane.
- `pinnedCount` is used to split rows in a pane (it is an `.all` concept).
- `DividerRowView` is back inside a document.
- The pinned pane's height is computed from a fixed ratio or from `bounds.height` directly,
  bypassing `SidebarPaneBudget`.
- A merge adds `withObservationTracking` to `SpaceColumnView.swift` (lint fails).

## Finding the change

    git log --oneline -- docs/sidebar-two-panes.md
    git show <commit> -- Sources/Cra/UI/Sidebar/List/SpaceColumnView.swift \
                          Sources/Cra/UI/Sidebar/List/SpaceListView.swift \
                          Sources/Cra/UI/Sidebar/SidebarListDrop.swift \
                          Packages/CraCore/Sources/CraCore/SidebarPaneBudget.swift

The introducing commit is the one that adds this file. It was written on top of `94c1fc3`
(6 Nov 2026); `git diff 94c1fc3..<commit>` shows the whole feature if the history is linear.
