import AppKit
import ReminderCore
import ServiceManagement

@MainActor
final class StatusMenuController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let stateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let completedItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let beginStandingItem = NSMenuItem(
        title: "立即开始站立 5 分钟",
        action: #selector(beginStanding),
        keyEquivalent: "s"
    )
    private let pauseWorkItem = NSMenuItem(
        title: "暂停工作计时",
        action: #selector(toggleWorkPause),
        keyEquivalent: "p"
    )
    private let launchAtLoginItem = NSMenuItem(
        title: "登录时自动启动",
        action: #selector(toggleLaunchAtLogin),
        keyEquivalent: ""
    )
    private let settingsItem = NSMenuItem(
        title: "计时设置…",
        action: #selector(showSettings),
        keyEquivalent: ","
    )
    private let versionInfoItem = NSMenuItem(
        title: "版本与更新…",
        action: #selector(showVersionInfo),
        keyEquivalent: ""
    )

    private let onBeginStanding: () -> Void
    private let onToggleWorkPause: () -> Void
    private let onShowSettings: () -> Void
    private let onToggleLaunchAtLogin: () -> Void
    private let onQuit: () -> Void

    init(
        onBeginStanding: @escaping () -> Void,
        onToggleWorkPause: @escaping () -> Void,
        onShowSettings: @escaping () -> Void,
        onToggleLaunchAtLogin: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onBeginStanding = onBeginStanding
        self.onToggleWorkPause = onToggleWorkPause
        self.onShowSettings = onShowSettings
        self.onToggleLaunchAtLogin = onToggleLaunchAtLogin
        self.onQuit = onQuit
        super.init()

        configureStatusItem()
    }

    func update(
        phase: ReminderPhase,
        remainingSeconds: Int,
        completedCount: Int,
        configuration: ReminderConfiguration,
        launchAtLoginStatus: SMAppService.Status
    ) {
        let time = Self.format(seconds: remainingSeconds)
        let standingDurationText = Self.durationText(
            seconds: configuration.standingDuration
        )
        beginStandingItem.title = "立即开始站立 \(standingDurationText)"

        switch phase {
        case .working:
            statusItem.button?.title = " \(time)"
            statusItem.button?.toolTip = "距离下一次站立还有 \(time)"
            stateItem.title = "距离站立还有 \(time)"
            beginStandingItem.isEnabled = true
            pauseWorkItem.title = "暂停工作计时"
            pauseWorkItem.isEnabled = true
            settingsItem.isEnabled = true

        case .standing:
            statusItem.button?.title = " 站 \(time)"
            statusItem.button?.toolTip = "请站立活动，还剩 \(time)"
            stateItem.title = "正在站立休息：\(time)"
            beginStandingItem.isEnabled = false
            pauseWorkItem.title = "暂停工作计时"
            pauseWorkItem.isEnabled = false
            settingsItem.isEnabled = false

        case .paused:
            statusItem.button?.title = " 暂停 \(time)"
            statusItem.button?.toolTip = "工作计时已暂停，剩余 \(time)"
            stateItem.title = "工作计时已暂停：\(time)"
            beginStandingItem.isEnabled = false
            pauseWorkItem.title = "继续工作计时"
            pauseWorkItem.isEnabled = true
            settingsItem.isEnabled = false
        }

        completedItem.title = "今天已完成 \(completedCount) 次站立休息"
        updateLaunchAtLogin(status: launchAtLoginStatus)
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = Bundle.main.image(forResource: "MenuBarIcon") ?? NSImage(
                systemSymbolName: "figure.stand",
                accessibilityDescription: "站立提醒"
            )
            button.image?.isTemplate = true
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.accessibilityDescription = "站立提醒"
            button.imagePosition = .imageLeading
        }

        stateItem.isEnabled = false
        completedItem.isEnabled = false
        beginStandingItem.target = self
        pauseWorkItem.target = self
        settingsItem.target = self
        launchAtLoginItem.target = self
        versionInfoItem.target = self

        let quitItem = NSMenuItem(
            title: "退出应用…",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self

        let menu = NSMenu()
        menu.addItem(stateItem)
        menu.addItem(completedItem)
        menu.addItem(.separator())
        menu.addItem(beginStandingItem)
        menu.addItem(pauseWorkItem)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(launchAtLoginItem)
        menu.addItem(versionInfoItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateLaunchAtLogin(status: SMAppService.Status) {
        switch status {
        case .enabled:
            launchAtLoginItem.state = .on
            launchAtLoginItem.title = "登录时自动启动"

        case .requiresApproval:
            launchAtLoginItem.state = .mixed
            launchAtLoginItem.title = "登录启动需要系统批准…"

        case .notFound, .notRegistered:
            launchAtLoginItem.state = .off
            launchAtLoginItem.title = "登录时自动启动"

        @unknown default:
            launchAtLoginItem.state = .off
        }
    }

    @objc private func beginStanding() {
        onBeginStanding()
    }

    @objc private func toggleLaunchAtLogin() {
        onToggleLaunchAtLogin()
    }

    @objc private func toggleWorkPause() {
        onToggleWorkPause()
    }

    @objc private func showSettings() {
        onShowSettings()
    }

    @objc private func showVersionInfo() {
        VersionInfoDialog.present()
    }

    @objc private func quit() {
        onQuit()
    }

    private static func format(seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private static func durationText(seconds: TimeInterval) -> String {
        "\(max(1, Int(round(seconds / 60)))) 分钟"
    }
}
