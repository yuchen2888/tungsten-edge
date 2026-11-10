import XCTest
@testable import macos_dock_cc_v2

final class AppMembershipProjectionTests: XCTestCase {

    func testDrawerMembersDeduplicates() {
        let result = AppMembershipProjection.drawerMembers(drawerIDs: ["a", "a", "b"])
        XCTAssertEqual(result, ["a", "b"])
    }

    func testDrawerMembersPreservesOrder() {
        let result = AppMembershipProjection.drawerMembers(drawerIDs: ["c", "a", "b"])
        XCTAssertEqual(result, ["c", "a", "b"])
    }

    // MARK: - visibleDrawerIDs = drawer ∩ (running ∪ kept)

    func testVisibleDrawerIDsUsesRunningKeptUnion() {
        let result = AppMembershipProjection.visibleDrawerIDs(
            drawerIDs: ["running", "kept", "messagingOnly", "hidden"],
            keptIDs: ["kept"],
            runningIDs: ["running"]
        )
        // messagingOnly 既不 running 也不 kept → 现在隐藏（messaging 不再独立保活）。
        XCTAssertEqual(result, ["running", "kept"])
    }

    func testVisibleDrawerIDsPreservesInputOrderAndDeduplicates() {
        let result = AppMembershipProjection.visibleDrawerIDs(
            drawerIDs: ["b", "a", "b", "c"],
            keptIDs: ["a", "b", "c"],
            runningIDs: []
        )
        XCTAssertEqual(result, ["b", "a", "c"])
    }

    func testDrawerPreviewHonorsLimit() {
        let drawerIDs = (0..<15).map { "app\($0)" }
        let result = AppMembershipProjection.drawerPreview(
            drawerIDs: drawerIDs,
            keptIDs: drawerIDs,
            runningIDs: [],
            limit: 4
        )
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result.first, "app0")
    }

    func testDrawerPreviewExcludesInactivePlacements() {
        let result = AppMembershipProjection.drawerPreview(
            drawerIDs: ["a", "b", "c"],
            keptIDs: ["b"],
            runningIDs: ["c"],
            limit: 9
        )
        XCTAssertEqual(result, ["b", "c"])
    }

    // MARK: - visibleMessagingIDs = (messaging − drawer) ∩ (running ∪ kept)

    func testVisibleMessagingIDsExcludesDrawerAndRequiresRunningOrKept() {
        let result = AppMembershipProjection.visibleMessagingIDs(
            messagingIDs: ["running", "kept", "stashed", "gone"],
            drawerIDs: ["stashed"],
            keptIDs: ["kept"],
            runningIDs: ["running"]
        )
        // stashed → 抽屉里隐藏；gone → 既不 running 也不 kept，隐藏。
        XCTAssertEqual(result, ["running", "kept"])
    }

    func testVisibleMessagingIDsPreservesOrderAndDeduplicates() {
        let result = AppMembershipProjection.visibleMessagingIDs(
            messagingIDs: ["c", "a", "c", "b"],
            drawerIDs: [],
            keptIDs: ["a", "b", "c"],
            runningIDs: []
        )
        XCTAssertEqual(result, ["c", "a", "b"])
    }


    // MARK: - 抽屉应用上主栏（自用改版的核心设计，同步上游后这一节变红 = 设计被改回去了）

    func testDrawerAppWindowCardIsAdmittedToStrip() {
        XCTAssertTrue(AppMembershipProjection.stripAdmitsSnapshotItem(
            bundleID: "com.apple.MobileSMS", isAppLevelFallback: false,
            isDrawerMember: true, showsFinderEntry: true),
            "抽屉里的应用在跑时，它的窗口卡必须出现在主栏")
    }

    func testDrawerAppRunningWithoutWindowIsAdmittedToStrip() {
        XCTAssertTrue(AppMembershipProjection.stripAdmitsSnapshotItem(
            bundleID: "com.apple.MobileSMS", isAppLevelFallback: true,
            isDrawerMember: true, showsFinderEntry: true),
            "抽屉里的应用在跑但没开窗口时，应用级卡也要出现在主栏")
    }

    func testStripAdmissionIgnoresDrawerMembership() {
        for isFallback in [false, true] {
            XCTAssertEqual(
                AppMembershipProjection.stripAdmitsSnapshotItem(
                    bundleID: "com.example.app", isAppLevelFallback: isFallback,
                    isDrawerMember: true, showsFinderEntry: true),
                AppMembershipProjection.stripAdmitsSnapshotItem(
                    bundleID: "com.example.app", isAppLevelFallback: isFallback,
                    isDrawerMember: false, showsFinderEntry: true))
        }
    }

    func testFinderEntryGateStillApplies() {
        XCTAssertFalse(AppMembershipProjection.stripAdmitsSnapshotItem(
            bundleID: FinderTaskbarPolicy.bundleID, isAppLevelFallback: true,
            isDrawerMember: false, showsFinderEntry: false))
        XCTAssertTrue(AppMembershipProjection.stripAdmitsSnapshotItem(
            bundleID: FinderTaskbarPolicy.bundleID, isAppLevelFallback: false,
            isDrawerMember: false, showsFinderEntry: false),
            "访达的真窗口卡不受「保留」闸门影响")
    }

    func testStoppedDrawerAppGetsNoStripPlaceholder() {
        XCTAssertFalse(AppMembershipProjection.stripInjectsKeptPlaceholder(
            bundleID: "com.example.app", isDrawerMember: true, isMessagingZoneMember: false),
            "没在跑的抽屉应用只待在抽屉里")
        XCTAssertTrue(AppMembershipProjection.stripInjectsKeptPlaceholder(
            bundleID: "com.example.app", isDrawerMember: false, isMessagingZoneMember: false))
        XCTAssertFalse(AppMembershipProjection.stripInjectsKeptPlaceholder(
            bundleID: "com.example.app", isDrawerMember: false, isMessagingZoneMember: true))
    }

    func testDrawerAppStripCardCannotBeStashedAgain() {
        XCTAssertFalse(AppMembershipProjection.stripCardCanStash(
            bundleID: "com.example.app", isDrawerMember: true))
        XCTAssertTrue(AppMembershipProjection.stripCardCanStash(
            bundleID: "com.example.app", isDrawerMember: false))
        XCTAssertFalse(AppMembershipProjection.stripCardCanStash(bundleID: nil, isDrawerMember: false))
        XCTAssertFalse(AppMembershipProjection.stripCardCanStash(bundleID: "", isDrawerMember: false))
    }

    // MARK: - 最近关闭（自用改版：固定 2 格，新退出的排第一，最旧的被挤掉）

    func testRecordingQuitsPutsNewestFirstAndCaps() {
        var history: [String] = []
        history = AppMembershipProjection.recordingQuits(["a"], into: history, limit: 3)
        history = AppMembershipProjection.recordingQuits(["b"], into: history, limit: 3)
        history = AppMembershipProjection.recordingQuits(["c"], into: history, limit: 3)
        history = AppMembershipProjection.recordingQuits(["d"], into: history, limit: 3)
        XCTAssertEqual(history, ["d", "c", "b"])
    }

    func testRecordingQuitsMovesRequitToFront() {
        let history = AppMembershipProjection.recordingQuits(["b"], into: ["a", "b", "c"], limit: 10)
        XCTAssertEqual(history, ["b", "a", "c"], "再次退出的 App 回到第一位，不重复")
    }

    func testRecordingQuitsDropsEmpty() {
        XCTAssertEqual(AppMembershipProjection.recordingQuits(["", "a"], into: [""], limit: 10), ["a"])
    }

    func testRecentlyQuitShowsTwoNewest() {
        let visible = AppMembershipProjection.visibleRecentlyQuitIDs(
            history: ["c", "b", "a"], runningIDs: [], keptIDs: [], drawerIDs: [])
        XCTAssertEqual(visible, ["c", "b"])
        XCTAssertEqual(AppMembershipProjection.recentlyQuitSlotCount, 2)
    }

    func testRelaunchedAppLeavesAndOlderOneFillsIn() {
        let visible = AppMembershipProjection.visibleRecentlyQuitIDs(
            history: ["c", "b", "a"], runningIDs: ["c"], keptIDs: [], drawerIDs: [])
        XCTAssertEqual(visible, ["b", "a"], "重新打开的 App 离开最近关闭区，更早的补位")
    }

    func testKeptAndDrawerAppsNeverShowInRecentlyQuit() {
        let visible = AppMembershipProjection.visibleRecentlyQuitIDs(
            history: ["kept", "drawer", "x", "y"], runningIDs: [],
            keptIDs: ["kept"], drawerIDs: ["drawer"])
        XCTAssertEqual(visible, ["x", "y"], "保留应用本来就在主栏上；抽屉应用退出后回抽屉")
    }

    func testFinderAndExcludedNeverShowInRecentlyQuit() {
        let visible = AppMembershipProjection.visibleRecentlyQuitIDs(
            history: [FinderTaskbarPolicy.bundleID, "self", "x"], runningIDs: [],
            keptIDs: [], drawerIDs: [], excludedIDs: ["self"])
        XCTAssertEqual(visible, ["x"])
    }

    // MARK: - badgeEligibleIDs = 身份 ∩ 在跑（抽屉应用在跑时窗口卡也在主栏，照样有角标）

    func testBadgeEligibleIDsUsesIdentityNotZone() {
        let identity: Set<String> = ["com.apple.MobileSMS", "com.tencent.xinWeChat", "com.slack"]
        let result = AppMembershipProjection.badgeEligibleIDs(
            isMessagingApp: { identity.contains($0) },
            runningIDs: ["com.apple.MobileSMS", "com.slack", "com.apple.Safari", "com.tencent.xinWeChat"]
        )
        // 信息从没进过消息区，但它是消息应用且在跑 → 有角标资格；Safari 不是消息应用。
        XCTAssertEqual(result, ["com.apple.MobileSMS", "com.slack", "com.tencent.xinWeChat"])
    }

    func testBadgeEligibleIDsIsEmptyWhenNothingRuns() {
        let result = AppMembershipProjection.badgeEligibleIDs(
            isMessagingApp: { _ in true },
            runningIDs: []
        )
        XCTAssertTrue(result.isEmpty, "没有消息应用在跑 → 空集 → BadgeStore 停轮询")
    }
}
