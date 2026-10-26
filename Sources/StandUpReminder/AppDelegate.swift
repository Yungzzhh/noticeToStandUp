import AppKit
import ReminderCore
import ServiceManagement
import UserNotifications

@main
struct StandUpReminderMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()

        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum InactiveReason: Hashable {
        case screenLocked
        case sleeping
    }

    private let stateStore = StateStore()
    private var engine = ReminderEngine()
    private var statusMenu: StatusMenuController?
    private var overlay: BreakOverlayCoordinator?
    private var timer: Timer?
    private var workspaceObserverTokens: [NSObjectProtocol] = []
    private var applicationObserverTokens: [NSObjectProtocol] = []
    private var inactiveReasons: Set<InactiveReason> = []
    private var inactiveSince: Date?
    private var lastTickUptime = ProcessInfo.processInfo.systemUptime
    private var lastPersistedUptime = ProcessInfo.processInfo.systemUptime

    func applicationDidFinishLaunching(_ notification: Notification) {
        let now = Date()
        let storedConfiguration = stateStore.loadConfiguration()
        engine = ReminderEngine(
            configuration: storedConfiguration,
            snapshot: stateStore.loadSnapshot(),
            resumedAt: now
        )

        overlay = BreakOverlayCoordinator { [weak self] in
            self?.endStandingEarly()
        }
        statusMenu = StatusMenuController(
            onBeginStanding: { [weak self] in self?.beginStandingNow() },
            onToggleWorkPause: { [weak self] in self?.toggleWorkPause() },
            onShowSettings: { [weak self] in self?.showTimerSettings() },
            onToggleLaunchAtLogin: { [weak self] in self?.toggleLaunchAtLogin() },
            onQuit: { [weak self] in self?.confirmQuit() }
        )

        requestNotificationPermission()
        installLifecycleObservers()
        startTimer()
        restoreVisibleState()
        updateInterface()
        persistState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        persistState()
        timer?.invalidate()
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObserverTokens.forEach(workspaceCenter.removeObserver)
        applicationObserverTokens.forEach(NotificationCenter.default.removeObserver)
    }

    private func startTimer() {
        lastTickUptime = ProcessInfo.processInfo.systemUptime
        lastPersistedUptime = lastTickUptime

        let timer = Timer(
            timeInterval: 1,
            target: self,
            selector: #selector(timerDidFire),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func timerDidFire() {
        let uptime = ProcessInfo.processInfo.systemUptime
        let elapsed = max(0, uptime - lastTickUptime)
        lastTickUptime = uptime

        guard inactiveReasons.isEmpty else {
            return
        }

        handle(transition: engine.advance(by: elapsed))

        if engine.phase == .standing {
            overlay?.update(
                remaining: engine.remaining,
                standingDuration: engine.configuration.standingDuration,
                workDuration: engine.configuration.workDuration
            )
        }

        updateInterface()

        if uptime - lastPersistedUptime >= 30 {
            persistState()
            lastPersistedUptime = uptime
        }
    }

    private func beginStandingNow() {
        handle(transition: engine.beginStandingNow())
        updateInterface()
        persistState()
    }

    private func endStandingEarly() {
        handle(transition: engine.endStandingEarly())
        lastTickUptime = ProcessInfo.processInfo.systemUptime
        updateInterface()
        persistState()
    }

    private func toggleWorkPause() {
        let uptime = ProcessInfo.processInfo.systemUptime
        let transition: ReminderTransition

        switch engine.phase {
        case .working:
            handle(
                transition: engine.advance(
                    by: max(0, uptime - lastTickUptime)
                )
            )

            guard engine.phase == .working else {
                lastTickUptime = uptime
                updateInterface()
                persistState()
                return
            }

            transition = engine.pauseWork()

        case .paused:
            transition = engine.resumeWork()

        case .standing:
            transition = .none
        }

        guard transition != .none else {
            return
        }

        lastTickUptime = uptime
        handle(transition: transition)
        updateInterface()
        persistState()
    }

    private func handle(transition: ReminderTransition) {
        switch transition {
        case .none:
            return

        case .standingStarted:
            overlay?.show(
                remaining: engine.remaining,
                standingDuration: engine.configuration.standingDuration,
                workDuration: engine.configuration.workDuration
            )
            NSSound(named: "Glass")?.play()
            sendStandingNotification()
            persistState()

        case .standingCompleted:
            overlay?.hide()
            stateStore.recordCompletion()
            NSSound(named: "Hero")?.play()
            persistState()

        case .standingEndedEarly:
            overlay?.hide()
            persistState()

        case .workPaused, .workResumed:
            persistState()
        }
    }

    private func restoreVisibleState() {
        guard engine.phase == .standing else {
            return
        }

        overlay?.show(
            remaining: engine.remaining,
            standingDuration: engine.configuration.standingDuration,
            workDuration: engine.configuration.workDuration
        )
    }

    private func updateInterface() {
        statusMenu?.update(
            phase: engine.phase,
            remainingSeconds: engine.roundedRemainingSeconds,
            completedCount: stateStore.completedCount(),
            configuration: engine.configuration,
            launchAtLoginStatus: SMAppService.mainApp.status
        )
    }

    private func persistState() {
        stateStore.save(snapshot: engine.snapshot(at: Date()))
    }

    private func installLifecycleObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        workspaceObserverTokens.append(
            workspaceCenter.addObserver(
                forName: NSWorkspace.sessionDidResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.markInactive(reason: .screenLocked)
                }
            }
        )
        workspaceObserverTokens.append(
            workspaceCenter.addObserver(
                forName: NSWorkspace.sessionDidBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.markActive(reason: .screenLocked)
                }
            }
        )
        workspaceObserverTokens.append(
            workspaceCenter.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.markInactive(reason: .sleeping)
                }
            }
        )
        workspaceObserverTokens.append(
            workspaceCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.markActive(reason: .sleeping)
                }
            }
        )
        applicationObserverTokens.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.overlay?.screensDidChange()
                }
            }
        )
    }

    private func markInactive(reason: InactiveReason) {
        if inactiveReasons.isEmpty {
            inactiveSince = Date()
            persistState()
            overlay?.hide()
        }

        inactiveReasons.insert(reason)
    }

    private func markActive(reason: InactiveReason) {
        inactiveReasons.remove(reason)

        guard inactiveReasons.isEmpty, let inactiveSince else {
            return
        }

        let inactiveDuration = max(0, Date().timeIntervalSince(inactiveSince))
        self.inactiveSince = nil
        lastTickUptime = ProcessInfo.processInfo.systemUptime

        if engine.phase == .paused {
            // 用户主动暂停的状态只能由用户主动继续。
        } else if inactiveDuration >= engine.configuration.standingDuration {
            engine.resetWorkCycle()
        } else if engine.phase == .standing {
            handle(transition: engine.advance(by: inactiveDuration))
        }

        restoreVisibleState()
        updateInterface()
        persistState()
    }

    private func showTimerSettings() {
        guard engine.phase == .working else {
            return
        }

        guard let newConfiguration = TimerSettingsDialog.present(
            current: engine.configuration
        ) else {
            return
        }

        // 设置窗口打开期间，计时器可能已经触发强制休息。
        guard engine.phase == .working else {
            return
        }

        guard newConfiguration != engine.configuration else {
            return
        }

        let transition = engine.applyConfiguration(newConfiguration)
        stateStore.save(configuration: newConfiguration)
        lastTickUptime = ProcessInfo.processInfo.systemUptime
        handle(transition: transition)
        updateInterface()
        persistState()
    }

    private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp

        do {
            switch service.status {
            case .enabled:
                try service.unregister()

            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()

            case .notFound, .notRegistered:
                try service.register()

            @unknown default:
                try service.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "无法修改登录启动设置"
            alert.informativeText = "请先把 StandUpReminder.app 移到“应用程序”文件夹，再重试。\n\n\(error.localizedDescription)"
            alert.runModal()
        }

        updateInterface()
    }

    private func confirmQuit() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "退出后将停止久坐提醒"
        alert.informativeText = "确定要退出站立提醒应用吗？"
        alert.addButton(withTitle: "继续运行")
        alert.addButton(withTitle: "退出")

        guard alert.runModal() == .alertSecondButtonReturn else {
            return
        }

        persistState()
        NSApp.terminate(nil)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendStandingNotification() {
        let content = UNMutableNotificationContent()
        content.title = "该站起来了"
        content.body = "你已经连续工作 \(durationText(engine.configuration.workDuration))。现在离开座位，活动 \(durationText(engine.configuration.standingDuration))。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "standing-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func durationText(_ duration: TimeInterval) -> String {
        "\(max(1, Int(round(duration / 60)))) 分钟"
    }
}
