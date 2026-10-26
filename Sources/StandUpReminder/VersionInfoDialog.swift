import AppKit
import Foundation

enum AppReleaseInfo {
    static func updateItems(
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary
    ) -> [String] {
        guard
            let items = infoDictionary?["SURReleaseHighlights"] as? [String],
            !items.isEmpty
        else {
            return ["暂无更新说明。"]
        }

        return items
    }

    static func updateSummary(
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary
    ) -> String {
        updateItems(infoDictionary: infoDictionary)
            .map { "• \($0)" }
            .joined(separator: "\n")
    }
}

@MainActor
enum VersionInfoDialog {
    static func present() {
        let credits = NSAttributedString(
            string: "本版本更新\n\n\(AppReleaseInfo.updateSummary())"
        )
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
