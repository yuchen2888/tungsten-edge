import Combine
import Foundation

/// 自用改版：「最近关闭的 App」的退出历史，新的在前，持久化到 UserDefaults。
///
/// 退出事实取自 `RunningApplicationStore.runningBundleIDs` 的前后差集——那个集合本身只收
/// regular 进程，菜单栏小工具 / 后台进程天然进不来。主栏上显示哪几个由纯决策
/// `AppMembershipProjection.visibleRecentlyQuitIDs` 决定（过滤在跑 / 保留 / 抽屉成员），
/// 这里只管记账。
///
/// **只在任务条运行期间观察**（`startObserving` / `stopObserving`）：`RunningApplicationStore.stop()`
/// 会把在跑集合一次性清空，若还在观察，就会把所有 App 都误记成刚退出。
@MainActor
final class RecentlyQuitAppStore: ObservableObject {
    static let shared = RecentlyQuitAppStore()

    static let defaultsKey = "personal.recentlyQuitBundleIDs"
    /// 多存几条：显示时会滤掉在跑 / 保留 / 抽屉成员，靠后的条目负责补位。
    static let historyLimit = 12

    @Published private(set) var bundleIDs: [String]

    private let defaults: UserDefaults
    private var lastRunning: Set<String>?
    private var runningSubscription: AnyCancellable?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: Self.defaultsKey) ?? []
        bundleIDs = AppMembershipProjection.recordingQuits([], into: stored, limit: Self.historyLimit)
    }

    func startObserving(runningBundleIDs publisher: Published<Set<String>>.Publisher) {
        lastRunning = nil
        runningSubscription = publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] running in
                self?.runningChanged(running)
            }
    }

    func stopObserving() {
        runningSubscription?.cancel()
        runningSubscription = nil
        lastRunning = nil
    }

    func remove(_ bundleID: String) {
        let next = bundleIDs.filter { $0 != bundleID }
        guard next != bundleIDs else { return }
        bundleIDs = next
        persist()
    }

    private func runningChanged(_ running: Set<String>) {
        defer { lastRunning = running }
        // 第一次拿到的是基线，不是退出。
        guard let last = lastRunning else { return }
        let quit = last.subtracting(running)
        guard !quit.isEmpty else { return }
        let next = AppMembershipProjection.recordingQuits(quit.sorted(), into: bundleIDs, limit: Self.historyLimit)
        guard next != bundleIDs else { return }
        bundleIDs = next
        persist()
    }

    private func persist() {
        defaults.set(bundleIDs, forKey: Self.defaultsKey)
    }
}
