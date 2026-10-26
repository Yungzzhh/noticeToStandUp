import AppKit
import Combine
import SwiftUI

@MainActor
final class BreakOverlayModel: ObservableObject {
    @Published private(set) var remainingSeconds = 5 * 60
    @Published private(set) var progress = 0.0
    @Published private(set) var standingDurationText = "5 分钟"
    @Published private(set) var workDurationText = "60 分钟"

    func update(
        remaining: TimeInterval,
        standingDuration: TimeInterval,
        workDuration: TimeInterval
    ) {
        remainingSeconds = max(0, Int(ceil(remaining)))
        progress = min(
            max((standingDuration - remaining) / standingDuration, 0),
            1
        )
        standingDurationText = Self.durationText(seconds: standingDuration)
        workDurationText = Self.durationText(seconds: workDuration)
    }

    var remainingText: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private static func durationText(seconds: TimeInterval) -> String {
        let minutes = max(1, Int(round(seconds / 60)))
        return "\(minutes) 分钟"
    }
}

@MainActor
final class BreakOverlayCoordinator {
    private let model = BreakOverlayModel()
    private let endStandingEarly: () -> Void
    private var windows: [NSPanel] = []
    private var isVisible = false

    init(endStandingEarly: @escaping () -> Void) {
        self.endStandingEarly = endStandingEarly
    }

    func show(
        remaining: TimeInterval,
        standingDuration: TimeInterval,
        workDuration: TimeInterval
    ) {
        model.update(
            remaining: remaining,
            standingDuration: standingDuration,
            workDuration: workDuration
        )

        guard !isVisible else {
            return
        }

        isVisible = true
        rebuildWindows()
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(
        remaining: TimeInterval,
        standingDuration: TimeInterval,
        workDuration: TimeInterval
    ) {
        model.update(
            remaining: remaining,
            standingDuration: standingDuration,
            workDuration: workDuration
        )
    }

    func hide() {
        isVisible = false
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    func screensDidChange() {
        guard isVisible else {
            return
        }

        rebuildWindows()
    }

    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map(makePanel)
        windows.forEach { $0.orderFrontRegardless() }
    }

    private func makePanel(for screen: NSScreen) -> NSPanel {
        let panel = BreakPanel(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        panel.setFrame(screen.frame, display: true)
        panel.level = .screenSaver
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        let hostingController = NSHostingController(
            rootView: BreakOverlayView(
                model: model,
                endStandingEarly: endStandingEarly
            )
        )
        hostingController.view.frame = NSRect(
            origin: .zero,
            size: screen.frame.size
        )
        hostingController.view.autoresizingMask = [.width, .height]
        panel.contentViewController = hostingController

        return panel
    }
}

private final class BreakPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private struct BreakOverlayView: View {
    @ObservedObject var model: BreakOverlayModel
    let endStandingEarly: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.10, blue: 0.12),
                    Color(red: 0.02, green: 0.23, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            centralContent
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .center
            )

            VStack {
                Spacer()
                bottomContent
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 30)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .center
        )
        .ignoresSafeArea()
    }

    private var centralContent: some View {
        VStack(spacing: 28) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 72, weight: .medium))
                .foregroundStyle(.mint)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("现在，站起来活动 \(model.standingDurationText)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("休息结束前，屏幕会保持锁定提醒")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Text(model.remainingText)
                .font(.system(size: 76, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .accessibilityLabel("站立休息剩余时间")
                .accessibilityValue(model.remainingText)

            ProgressView(value: model.progress)
                .progressViewStyle(.linear)
                .tint(.mint)
                .frame(maxWidth: 440)
                .scaleEffect(y: 2)
                .accessibilityLabel("站立休息进度")
        }
        .padding(48)
        .foregroundStyle(.white)
    }

    private var bottomContent: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                activityTip(icon: "figure.walk", text: "离开座位走动")
                activityTip(icon: "figure.cooldown", text: "活动肩颈手腕")
                activityTip(icon: "eye", text: "眺望远处 20 秒")
                activityTip(icon: "drop", text: "喝几口水")
            }

            Text("完成后会自动开始下一轮 \(model.workDurationText)工作计时")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.58))

            EndStandingEarlyControl(action: endStandingEarly)
        }
        .foregroundStyle(.white)
    }

    private func activityTip(icon: String, text: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .accessibilityHidden(true)
            Text(text)
                .font(.callout)
        }
        .frame(width: 132)
        .foregroundStyle(.white.opacity(0.82))
    }
}

private struct EndStandingEarlyControl: View {
    let action: () -> Void
    @State private var isPressing = false

    var body: some View {
        Text(isPressing ? "继续按住…" : "长按 3 秒结束本次休息")
            .font(.caption)
            .foregroundStyle(.white.opacity(isPressing ? 0.9 : 0.38))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.white.opacity(isPressing ? 0.12 : 0.04), in: Capsule())
            .contentShape(Capsule())
            .onLongPressGesture(
                minimumDuration: 3,
                maximumDistance: 30,
                pressing: { isPressing = $0 },
                perform: action
            )
            .accessibilityLabel("提前结束本次休息")
            .accessibilityHint("按住三秒钟结束休息并重新开始工作计时")
    }
}
