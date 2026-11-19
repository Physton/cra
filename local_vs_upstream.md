# 本地代码与上游(upstream/main)差异说明

> 本文档描述 Physton fork（origin: `https://github.com/Physton/cra.git`）相对上游（upstream: `https://github.com/VictorKildahl/cra.git`）的**全部本地修改与维护方法**。
>
> - 基线：`upstream/main`（`d1d90693`）；本地 `main` 是其上的 4 个线性提交
> - 同步方式：`git fetch upstream && git rebase upstream/main`，不要 merge
> - 同步后 `git diff upstream/main HEAD --stat` 应只出现 **19 个文件**：18 个代码/测试 + 本文件
> - 本文件是本地唯一的差异文档：不要修改 `CLAUDE.md`、`docs/*.md` 等上游文档，也不要在其中追加本地说明

## 1. 本地修改概览

| 修改 | 文件数 | 说明 |
|---|---|---|
| 侧边栏双窗格 | 7 | Pinned 与 Today 两个独立滚动窗格，中间是可拖动的固定分隔带 |
| 链接标签落位 | 5 | `target=_blank` / `window.open` 的标签跟到 Today 来源标签下方 |
| 多窗口全屏恢复 | 5 | 多块屏上的全屏窗口逐个串行恢复，并回到各自屏幕 |
| 测试兼容 | 1 | `ExtensionIconsTests` 使用本地循环实现，而非上游参数化写法 |
| 本文档 | 1 | 记录以上修改、不变量、冲突解法与验证方法 |

## 2. 侧边栏双窗格

侧边栏把固定标签（Pinned）与 Today 画成两个独立滚动窗格，中间有一条固定分隔带。这是**有意偏离 Arc parity 的产品决策，不是 bug**，同步上游时不得"恢复"单列表。分隔带可手动拖动调整上下高度，双击恢复内容自适应；高度存 `windows.json` 的 `WindowPrefs.pinnedPaneHeight`，所有空间/窗口共用。

### 2.1 文件与符号

| 文件 | 差异 |
|---|---|
| `Sources/Cra/UI/Sidebar/List/SpaceColumnView.swift` | `pinnedList`、`todayList`、`divider`；`place(animated:)` 负责三者的尺寸与位置；`observeDivider()`、`contentHeightChanged()`、`scrollerStyleChanged()`；拖动接口 `paneDragLimit`、`draggedPinnedHeight`、`resizeDivider(to:)`、`commitDividerDrag()`、`resetDividerSplit()`；私有 `SidebarSectionDividerView`（拖动字段 `pinnedHeight`、`onResize`、`onResizeEnded`、`onReset`，`hitTest` 保留 Clear/Tidy 可点） |
| `Sources/Cra/UI/Sidebar/List/SpaceListView.swift` | `scope`、`contentHeight(forWidth:)`、`onContentHeightChange`、`contentTopInset`、`rowsInset`、`measuredContentHeight`；`layoutAllRows()` / `layoutPaneRows()`；按 scope 分支的 `build()`、`resolve()`、`performDrop()`、`dragExited()` |
| `Sources/Cra/UI/Sidebar/List/SidebarRowViews.swift` | `DividerRowView` 的 1pt 线改为 `DividerLineView`（`hitTest` 返回 nil，让事件落到分隔带用于拖动）；`ClearButton` 与 `TidyButton` 加 `resetCursorRects` 的箭头光标（分隔带整块是 resize 光标） |
| `Sources/Cra/UI/Sidebar/SidebarListDrop.swift` | `SidebarListScope`；`SidebarListDrop.scope`；`SidebarListDrop.fromDivider` |
| `Packages/CraCore/Sources/CraCore/SidebarPaneBudget.swift` | 高度分配决策移入 CraCore；`pinnedShare = 0.55`；`pinnedOverride`（拖动后的手动高度优先于内容自适应） |
| `Packages/CraCore/Sources/CraCore/SidebarModel.swift` | `WindowPrefs.pinnedPaneHeight: Double?`（拖动后的高度，存 windows.json；nil = 内容自适应） |
| `Packages/CraCore/Tests/CraCoreTests/SidebarPaneBudgetTests.swift` | 高度分配测试，含 `pinnedOverride` 与 `draggedHeight*` |

复用且未修改：`SidebarMenus.swift`、`FolderPreview.swift`、`SpacePagerView.swift`、`SpacesManagerView.swift`。

### 2.2 形态与术语

```
SpaceColumnView
├─ FavoritesGridView              fixed, unchanged
├─ SpaceHeaderView                fixed, unchanged
├─ SpaceListView(scope: .pinned)  independent scroll view
├─ SidebarSectionDividerView      18 pt fixed band, DividerRowView inside, drop target
└─ SpaceListView(scope: .today)   independent scroll view, fills the rest
```

- **pane（窗格）**：一个带 `.pinned` 或 `.today` 的 `SpaceListView`，各自拥有一个 `NSScrollView` 与 document。
- **band（分隔带）**：`SidebarSectionDividerView`，两窗格之间的固定分隔带。
- **`.all`**：旧的合并列表（pinned + 分隔行 + Today），只为 Spaces 页保留。

### 2.3 数据兼容

不改变数据目录格式；`sidebar.json` 与 `settings.json` 不变；`windows.json` 只新增可选的 `pinnedPaneHeight`（未拖动时不存在，旧文件自然缺失）。

### 2.4 不变量（同步时必须逐条守住）

1. **两个窗格 + 一个 `.all`**：`SpaceColumnView` 必须创建 `.pinned` 与 `.today` 两个 `SpaceListView`；`.all` 只用于 `SpacesManagerView`（及其卡片布局）。若 `SpaceColumnView` 又只剩一个 list，功能即丢失。
2. **高度由预算决定**：不要在视图里内联另一套比例。公式 `pinned = min(pinnedContent, max(available * 0.55, available - todayContent))`，Today 得到 `available - pinned`；`available` 不含分隔带；常量是 `SidebarPaneBudget.pinnedShare`。
3. **分隔带不是一行**：`SidebarSectionDividerView` 是两个窗格的兄弟视图。把 `DividerRowView` 放回任一 document 会随滚动移走，固定边界与放置目标都会消失。
4. **每个窗格只 build 自己的区域**：保留 `build()` 里的 `scope != .today` / `scope != .pinned` 守卫；分隔行只在 `.all` 追加。
5. **保留 3/4pt 与 0/1pt 内边距**：`paneTopInset` 复现上游单列表的间距——pinned 行从 3pt + 1pt 行距开始；Today 从分隔带底部开始，带隐藏（Today 为空）时从 1pt 开始。`todayList.contentTopInset` 由 column 设置。
6. **121pt 尾部只属于 Today**：`layoutPaneRows()` 对 `.pinned` 用 `tail = 0`、`.today` 用 `tail = 121`。pinned 带尾会多出大片空滚动区。
7. **拖放归属**：每个 `SidebarListDrop` 带 `scope`；窗格只为自己的 scope 画装饰、插入线与区域高亮。`fromDivider` 标记分隔带的 drop，使窗格的 `dragExited()` 不能清掉它。`performDrop()` 只在 scope 匹配且 `!fromDivider` 时使用共享 drop，否则本地解析。
8. **两个窗格共用一个 legacy 滚动条留白**：`NSScroller.preferredScrollerStyle == .legacy` 时，`SpaceColumnView` 给两者都设 `rowsInset = 8`。按窗格各自判断 `legacyScrollerShown` 会让只有一个溢出时两窗格行宽相差 8pt。
9. **测量与布局一致**：`contentHeight(forWidth:)` 与 `layoutPaneRows()` 必须使用同一套行高，包括 `LiveStatusRowView.height(_:width:)`；新增可变高行时两处都要改。
10. **column 通过 `onContentHeightChange` 得知高度变化**：没有它，pinned 行增删、展开或折叠时分隔带与 Today 不会移动。
11. **每个窗格有自己的跳转药丸**：`updateJumpPill` 在窗格不足 2 行时隐藏；药丸只滚动拥有选中行的窗格。
12. **pinned 窗格关闭回弹**：`.pinned` 的 `verticalScrollElasticity = .none`，其边缘是内部边缘，回弹会在分隔带处露出空隙；Today 保持 `.allowed`。
13. **空 pinned 仍是放置目标**：空 pinned 保留 3pt inset，并在 `ui.draggingID` 设置时立即扩成一行占位，避免指针进入 0pt 视图。
14. **拖动后的高度必须经过预算**：`place()` 读取 `draggedPinnedHeight`（或 `store.prefs.pinnedPaneHeight`）交给 `SidebarPaneBudget(pinnedOverride:)`，绝不自己设置 frame 高度。Today 有标签时 override 被 clamp 到可用空间减一个 `CraMetrics.rowHeight`，保证 Today 不消失。分隔带只在松手时（`commitDividerDrag`）写 `pinnedPaneHeight`，一次拖动只写一次 `windows.json`；双击调用 `resetDividerSplit` 并清掉两处副本。无 override 时回到内容自适应分配。
15. **窗格靠分隔带的一侧不画发丝线**：Arc 的滚动边缘发丝线仍按窗格保留，但 pinned 的底边与 Today 的顶边是内部边缘：`updateHairlines()` 对 `.pinned` 强制 `bottom = false`、`.today` 强制 `top = false`。否则滚动中的窗格会在分隔带线旁再画一条，出现两三条分隔线。pinned 的顶边与 Today 的底边保留（面向 header 与侧边栏底部）。

### 2.5 同步冲突解法（rebase playbook）

上游把 `SpaceListView` 当单一列表编辑。以 upstream 为行渲染、hover、拖拽、autoscroll 与 Arc 度量的事实来源，在外层重新套上 scope 拆分。

**`SpaceListView.swift`（最大冲突面）**

- `build()`：保留上游的行构造；pinned 行放在 `scope != .today` 之后，Today 行与 New Tab 行放在 `scope != .pinned` 之后，分隔行只在 `scope == .all`。上游新增的行类型必须明确归入某个 section（pinned 文件夹与 Today 文件夹都走同一个 `add`）。
- `layoutRows()`：上游版本叫 `layoutAllRows()`。上游新增的度量、分隔高度或特例，必须同时移植到 `layoutPaneRows()` **和** `contentHeight(forWidth:)`。
- `resolve()`：每条返回路径都必须设置 `scope`。窗格专用 fallback（越过最后一行）追加到自己的容器；`.all` 的分隔带中点分支留给 Spaces 页。新增的 `SidebarListDrop.Target` case 必须被两个窗格与分隔带理解。
- `dragUpdated` / `performDrop` / `dragExited`：保留解析出的 drop 上的 `scope` 与 `!drop.fromDivider` 检查。删掉会让两个窗格同时画线或互相清掉 drop。
- `updateJumpPill`：保留短窗格守卫。
- `rowsWidth`：保留 `rowsInset` 作为 column 的覆盖；不要退回按窗格检测。
- `contentHeight(forWidth:)`：保持与窗格当前 frame 无关；column 在摆放窗格前就会调用它。
- `updateHairlines()`：先取上游的 clip 检查，再套回窗格守卫（`.pinned` 不画底、`.today` 不画顶）。没有它，滚动中的窗格会把分隔带的线变成两三条。

**`SpaceColumnView.swift`**

- 保留两个窗格与分隔带。上游的 favorites/header 摆放（`place`）与 `holdFavorites` 原样接受；只有 `top` 以下的部分是本地的。
- 分隔带高度在 Today 有内容时是 `18`，否则 `0`；上游若改分隔带度量，同时改 `dividerHeight` 与分隔带。
- 保留 override 接线：`divider.onResize/onResizeEnded/onReset`、`resizeDivider(to:)`、`commitDividerDrag()`、`resetDividerSplit()`、`paneDragLimit`，以及 `place()` 里的 `SidebarPaneBudget(pinnedOverride:)` 调用。上游不知道它们；重写 `place()` 时必须重新套上，而不是内联一个高度。
- `observeDivider()` 使用 CraCore 的 `observeChanges`，因为 `scripts/lint.py` 限制该文件中裸 `withObservationTracking` 的数量，第三个裸调用会导致 lint 失败。
- `contentHeightChanged()` 在拖动中（`ui.draggingID != nil`）不得做动画，pinned 占位才能跟随指针。

**`SidebarListDrop.swift`**

- 保留 `SidebarListScope` 与两个字段。上游新增字段就追加；`Equatable` 是合成的，窗格每次 `draggingUpdated` 都会比较 drop。
- 分隔带设置 `fromDivider: true`；窗格永远不设。

**`SidebarRowViews.swift` 与分隔带**

- `DividerRowView` 必须能在列表外使用：分隔带持有它，调用 `apply(...)`、`setColors(...)`，并从自己的 tracking area 驱动 `isHovered`。若上游让它依赖 `list.rows` 或必须是 document 里的一行，改分隔带适配，而不是把这一行放回窗格。
- 它的 `line` 必须保持为 `DividerLineView`（`hitTest` 返回 nil）：分隔带的 `hitTest` 把除 Clear/Tidy 之外的按压都交给自己做拖动。让线重新可命中会在 1pt 区域内留下拖动无反应的死区。
- `SidebarMenus.spaceList` 需要 `list.header`；两个窗格拿到同一 header，菜单才能工作。

**`SpacesManagerView` 与 `.all`**

- `.all` 必须保持上游的单列表行为，Spaces 页不属于该功能。上游改 `.all` 就接受；只有 `.pinned`/`.today` 路径是本地的。

**上游大重构时**

若上游把 `SpaceListView` 改到面目全非，不要逐行解冲突。在新列表上重建拆分：每个 section 一个实例、column 级分隔带、预算、drop 归属。上面的不变量是契约，具体 diff 可以替换。

### 2.6 同步后验证（侧边栏）

运行第 6 节的命令后，走一遍人工矩阵（功能是视觉的，测试不覆盖滚动视图）：

- 1 个、14 个、0 个 pinned；0、1、25 个 Today 标签。
- 在 pinned 窗格滚轮/触控板：只有 pinned 移动；到边缘停住（无链式滚动、无回弹）。
- 在 Today 滚轮/触控板：只有 Today 移动；到底部回弹，绝不继续滚进 pinned。
- 从空间 header 折叠 pinned 再展开：分隔带与 Today 移动；Today 保持自己的滚动偏移。
- 清空 Today：分隔带消失，New Tab 直接贴在 pinned 下方，pinned 占用腾出的空间。
- 先选 pinned 标签再选 Today 标签：只有所属窗格 reveal 该行；跳转药丸出现在该窗格，另一窗格不出现。
- Today → pinned（行上/行下/中间成 split）、pinned → Today、拖到分隔带上下两半：插入线/高亮只由一个窗格绘制；靠近窗格边缘会 autoscroll。
- 悬停分隔带：出现 Clear 与 Tidy Tabs；Tidy 仍有 squiggle 动画。
- 上下拖动分隔带：pins 跟随指针且无动画；Today 缩到一行就不再缩；双击分隔带恢复内容自适应。
- 把 pinned 滚到底、Today 滚到顶：交界处只有分隔带的一条线——没有 pinned 底边线、没有 Today 顶边线；pinned 顶边与 Today 底边仍在 column 外侧出现。
- 重启：拖动过的高度仍在（`windows.json` 的 `pinnedPaneHeight`），双击重置后保持重置。把窗口改矮：pins 被 clamp，Today 至少保留一行。
- 在 Clear/Tidy 显示时把标签拖到分隔带两半：分隔带仍路由 drop，点击 Clear 或 Tidy 不会开始 resize。
- 窗口改窄改矮；隐藏空间 header（单空间模式）；无 favorites。
- 设置 ▸ “Show scroll bars: Always”：两个窗格的行与分隔带的线对齐。
- Spaces 页（Library ▸ Spaces）：每张卡片仍是单列表，未改变。
- 空间滑动与 Library 覆盖层仍同时移动/覆盖两个窗格。

**Red flags（出现即说明同步出错）**

- `SpaceColumnView` 又只有一个 `list`，或 `pinnedList`/`todayList` 共用一个滚动视图。
- 两个窗格同时显示插入线。
- `ui.listDrop` 被任意 `dragExited` 清掉，而不只是所有者。
- 121pt 尾部出现在 pinned 窗格。
- 窗格内用 `pinnedCount` 拆分（它是 `.all` 的概念）。
- `DividerRowView` 又回到 document 里。
- pinned 高度来自固定比例或直接 `bounds.height`，绕过 `SidebarPaneBudget`。
- 同步给 `SpaceColumnView.swift` 增加了裸 `withObservationTracking`（lint 失败）。
- 分隔带按压会移动窗口、无反应，或线吞掉拖动。
- 每次 `mouseDragged` 都写 `windows.json`，而不是松手写一次。
- Today 有标签时仍能被整个拖走。
- 窗格在分隔带一侧画了滚动边缘发丝线（`updateHairlines()` 丢了 `.pinned`/`.today` 守卫）。

若某步失败，先与引入该功能的提交对比，再改设计。

## 3. 链接标签落位（target=_blank / window.open）

Chromium 的 `target=_blank`/`window.open` 走 `OnBeforePopup` → `BrowserManager.popupHostForURL`。上游只调 `createTab` 不传位置，导致标签落在 Today 最上方；Arc 的行为是跟到被点击的 Today 标签下方（固定标签或无来源时才用默认位置）。本地把落位规则抽成 `SidebarStore.linkTabPlacement(from:)`，`openLinkTab` 与 `popupHostForURL` 共用。

| 文件 | 差异 |
|---|---|
| `Sources/Cra/Services/SidebarStore.swift` | **新增** `linkTabPlacement(from:)`：来源标签在 Today（含 Today 里的文件夹，`rootContainer == .today`）时返回 `(parent, 来源下标 + 1)`，否则 `(nil, nil)` 交给 `createTab` 的默认位置（`newTabsAtTop`） |
| `Sources/Cra/Services/BrowserManager.swift` | `openLinkTab` 与 `popupHostForURL` 都改为先取 `store.linkTabPlacement(from: source)` 再传给 `createTab`。**`popupHostForURL` 的 `parent/index` 是最初的 bug 点：上游不传，target=_blank 必须在这里跟到来源下方** |
| `Tests/BrowserManagerLifecycleTests.swift`、`Tests/BrowserManagerSupport/AppServices.swift` | 契约测试 `linkTabBelowSourceCase`：fake store 记录 `parent/index` 并按序插入，验证弹窗标签落在 Today 来源下方；fake 新增 `todayItems` 与 `linkTabPlacement` |
| `Tests/StoreTests.swift` | `linkTabPlacement` 表测试：Today 标签、Today 文件夹内标签、固定标签、无来源四种情况 |

**同步冲突解法**：先接受 upstream 的 `openLinkTab`/`popupHostForURL`，再把两处 `createTab` 的 `parent:`/`index:` 恢复为 `place.parent`/`place.index`；`SidebarStore.linkTabPlacement` 保留。若上游自己也修了同类问题，按其实现与本地方向一致处理即可，确保两条路径一致。

**同步后手动核对（Link tabs）**：在 Today 标签（以及 Today 文件夹内的标签）打开的 Chromium 页面点击 `target=_blank` 链接，新标签应紧跟在来源标签下方，而不是落到 Today 顶部；WebKit 页面行为一致；从固定标签打开时仍落到 Today 顶部。

## 4. 多窗口全屏恢复

macOS 在一个窗口的全屏过渡进行中会拒绝另一个窗口的 `toggleFullScreen`（`windowDidFailToEnterFullScreen`）。上游在启动时同一轮循环里恢复全部全屏窗口，只有第一个成功，其余窗口留在普通桌面并叠在全屏窗口上；同时全屏时 `saveFrameNow` 直接 return，从不读取 `window.screen`，Mission Control 把全屏 Space 拖到另一显示器后 `windows.json` 仍保留旧屏幕的窗口化 frame，重启时第二个窗口回不到自己的屏幕。

本地把恢复串行化（`FullScreenRestore` 一次只放行一个窗口，被 AppKit 拒绝的请求在队尾重试一次），并在全屏窗口进入全屏、`windowDidChangeScreen`、退出全屏与退出程序时按 `window.screen` 保存"所在显示器的窗口化 frame"（`FullScreenWindowFrame`）。

| 文件 | 差异 |
|---|---|
| `Packages/CraCore/Sources/CraCore/FullScreenRestore.swift`、`Packages/CraCore/Tests/CraCoreTests/FullScreenRestoreTests.swift` | **新增**：`FullScreenRestore` 串行队列（`add`/`next`/`ended(entered:)`，一次只放行一个窗口，失败排到队尾重试一次）与 `FullScreenWindowFrame.windowedFrame(_:saved:on:)`（frame 已在当前显示器则原样保留，否则保留尺寸、居中到该显示器） |
| `Sources/Cra/App/AppDelegate.swift` | 新增 `fullScreenRestore` 属性与 `restoreSavedFullScreens()` / `enterNextSavedFullScreen()` / `fullScreenRestoreEnded(_:entered:)`；启动时用 `restoreSavedFullScreens()` 替换原来的 `for w in mainWindows { w.enterSavedFullScreen() }` 同步循环；`browserWindowWillShow` 在菜单栏窗口全部回来后 async 触发一次恢复 |
| `Sources/Cra/UI/Windows/MainWindowController.swift` | 新增 `windowedFrame`（最近一次窗口化 frame 缓存）；`saveFrame`/`saveFrameNow` 在全屏时走 `saveFullScreenWindowedFrame()`（按 `window.screen` 写回窗口化 frame），不再直接 return；新增 `windowDidChangeScreen`（全屏 Space 被拖到另一显示器时立即改记）、`windowWillEnterFullScreen` 先把缓存写盘、`windowDidEnterFullScreen`/`windowDidFailToEnterFullScreen` 通知 AppDelegate 放行下一个；`bringBack` 不再自己 `toggleFullScreen`，交给 AppDelegate 队列 |
| `Tests/Scenarios/fullscreen-two-windows.scenario` | **新增**：seed 两个 `fullScreen: true` 的窗口，启动后断言 `window state ... main0/main1 fullscreen=1`（`requires screen`，单屏 CI 也能验证串行恢复） |

**同步冲突解法**：先接受 upstream 的窗口生命周期代码，再把本地恢复入口接回——启动与菜单栏只走 `restoreSavedFullScreens()` 串行队列；`windowDidEnterFullScreen` 与 `windowDidFailToEnterFullScreen` 必须通知 `fullScreenRestoreEnded`；`saveFrameNow` 遇到全屏窗口必须调用 `saveFullScreenWindowedFrame()`，并保留 `windowedFrame` 缓存与 `windowDidChangeScreen`。若上游自己实现了全屏恢复，按"一次一个窗口 + 按 `window.screen` 记窗口化 frame"这两个行为为准处理，不要直接采信上游的同步循环。

**同步后手动核对（双屏全屏）**：在两块屏的 Mac 上，每块屏放一个全屏 Cra 窗口，退出重开：两个都回到全屏且各在自己屏幕，不是一个窗口化后叠在另一个上面。在 Mission Control 把一个全屏 Space 拖到另一块屏后退出，下次它应在被拖到的屏幕全屏打开。`fullscreen-two-windows` 场景只有单屏，只能验证两个窗口都进全屏。

## 5. 测试兼容（ExtensionIconsTests）

`Packages/CraCore/Tests/CraCoreTests/ExtensionIconsTests.swift` 使用本地循环实现：上游用参数化 `@Test(arguments:)`，本地改为 `for (icons, files) in cases` 逐项 `#expect`。同步时保留本地实现，不要恢复上游写法。

## 6. 同步流程与验证

```bash
# 同步上游（线性历史，不要 merge）
git fetch upstream && git rebase upstream/main

# 差异面：应只出现本文件列出的 19 个文件
git diff upstream/main HEAD --stat

# 核心逻辑与侧边栏预算
swift test --package-path Packages/CraCore
scripts/lint.py

# 多窗口全屏恢复：真实屏幕下跑（CI 单屏只验证两个窗口都进全屏；双屏人工项见第 4 节）
CRA_SCENARIO_SCREEN=1 scripts/scenario.sh fullscreen-two-windows

# 构建（见第 7 节签名说明）
CRA_SIGN_IDENTITY="Apple Development: physton@163.com (7XSZ62JM7Y)" scripts/build.sh
```

同步纪律：本地 commit 只包含本文档列出的文件与行为，不混入上游内容、格式化或无关重构。rebase 后差异清单必须仍是这 19 个文件；改写已推送历史时用 `git push --force-with-lease`，不要用裸 `--force`。

## 7. 本地构建与签名

`scripts/build.sh` 默认 ad-hoc 签名，每次构建 cdhash 都变，macOS 会把它当成新 App：TCC（摄像头/麦克风/蓝牙/屏幕录制）、登录钥匙串里的 Chrome Safe Storage、登录项会反复失效或弹窗。用固定的个人 Apple 证书签名可让身份稳定；**不改 `build.sh`**（它本来就支持 `CRA_SIGN_IDENTITY`），保持上游文件零差异。

### 7.1 使用的证书

| 项 | 值 |
|---|---|
| 签名身份（codesign 名称） | `Apple Development: physton@163.com (7XSZ62JM7Y)` |
| 实际 TeamIdentifier | `6SGP99KNR4`（取自证书 OU；CN 括号里的 `7XSZ62JM7Y` 是个人团队的旧 ID，不参与签名） |
| 团队 | Xcode `IDEProvisioningTeamByIdentifier.6SGP99KNR4`：`相庭 廖 (Personal Team)`，`isFreeProvisioningTeam = 1`，免费个人团队 |
| 有效期 | 2026-08-27 至 2027-08-27；到期在 Xcode 续签。CN 不变时 TCC/钥匙串授权可延续 |

**不要用** `Apple Development: Physton Physton (72ZS5RL58V)`：它属于 `QV57Y5LTKH`（Nanjing Homecaught，`isFreeProvisioningTeam = 0`，Company），是公司证书。个人项目使用违反 Apple 开发者协议和公司政策，证书一旦被吊销还会波及公司全部 App。

该证书是 Apple Development（开发）证书，只用于本机，不能分发或公证。

### 7.2 构建命令

```bash
CRA_SIGN_IDENTITY="Apple Development: physton@163.com (7XSZ62JM7Y)" scripts/build.sh
```

- **不要全局导出 `CRA_SIGN_IDENTITY`**：`scripts/release.sh` 也读它，会把 release 构建误签成开发证书。
- `scripts/dev.sh` 仍硬编码 ad-hoc；如需 dev 构建也用该证书，要单独改 dev.sh（会产生本地差异，默认不做）。
- 非 ad-hoc 分支会使用 `--options runtime --timestamp` + `resources/Cra.entitlements`，并在末尾校验所有 Mach-O 的 TeamIdentifier 与 Timestamp。该证书已实测通过（`TeamIdentifier=6SGP99KNR4`，Timestamp 正常，`codesign --verify --strict` 通过）。

### 7.3 验证

```bash
security find-identity -v -p codesigning | grep "Apple Development: physton@163.com"
codesign -dv --verbose=2 build/Cra.app 2>&1 | grep -E "Authority|TeamIdentifier|Timestamp"
# 期望：Authority 含该证书；TeamIdentifier=6SGP99KNR4；Timestamp 存在

# 确认是免费个人团队（isFreeProvisioningTeam = 1，teamType = Personal Team）
defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier
```

### 7.4 首次运行与已知限制

- 第一次用新身份启动会重新弹一次钥匙串与 TCC 授权；钥匙串选「始终允许」，保留旧 Chrome Safe Storage 密钥与已保存密码。之后重建不再反复询问。
- 构建后替换 `/Applications/Cra.app`，保持路径一致。
- **Passkey 仍不可用**：免费个人团队没有 macOS 描述文件，拿不到 `keychain-access-groups`，`PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable()` 为 false。继续用手机扫码或安全密钥。要解锁本机 Passkey 需付费 Apple Developer Program：自己账号下注册 App ID、开启 Keychain Sharing（无需 Apple 审批）、创建 Apple Development/Developer ID 描述文件；iCloud 钥匙串 Passkey 还需 Apple 审批 `com.apple.developer.web-browser.public-key-credential`。
