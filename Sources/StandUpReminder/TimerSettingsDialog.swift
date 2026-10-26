import AppKit
import ReminderCore

@MainActor
enum TimerSettingsDialog {
    private static let workOptions = [15, 25, 30, 45, 50, 60, 75, 90, 120]
    private static let standingOptions = [1, 3, 5, 10, 15, 20]

    static func present(
        current configuration: ReminderConfiguration
    ) -> ReminderConfiguration? {
        let workPopup = makePopup(
            options: workOptions,
            selectedMinutes: Int(configuration.workDuration / 60)
        )
        let standingPopup = makePopup(
            options: standingOptions,
            selectedMinutes: Int(configuration.standingDuration / 60)
        )

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "工作时长"), workPopup],
            [NSTextField(labelWithString: "休息时长"), standingPopup]
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 18
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .fill
        grid.frame = NSRect(x: 0, y: 0, width: 300, height: 68)

        let alert = NSAlert()
        alert.messageText = "计时设置"
        alert.informativeText = "保存后会保留本轮已经工作的时长；如果新的工作时长已经到期，会立即开始休息。站立休息期间不能修改设置。"
        alert.accessoryView = grid
        alert.addButton(withTitle: "保存设置")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        guard
            let workMinutes = workPopup.selectedItem?.representedObject as? Int,
            let standingMinutes = standingPopup.selectedItem?.representedObject as? Int
        else {
            return nil
        }

        return ReminderConfiguration(
            workDuration: TimeInterval(workMinutes * 60),
            standingDuration: TimeInterval(standingMinutes * 60)
        )
    }

    private static func makePopup(
        options: [Int],
        selectedMinutes: Int
    ) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)

        for minutes in options {
            let item = NSMenuItem(
                title: durationText(minutes: minutes),
                action: nil,
                keyEquivalent: ""
            )
            item.representedObject = minutes
            popup.menu?.addItem(item)
        }

        let selectedIndex = options.firstIndex(of: selectedMinutes)
            ?? options.firstIndex(of: 60)
            ?? 0
        popup.selectItem(at: selectedIndex)
        return popup
    }

    private static func durationText(minutes: Int) -> String {
        guard minutes.isMultiple(of: 60) else {
            return "\(minutes) 分钟"
        }

        return "\(minutes / 60) 小时"
    }
}
