import XCTest
@testable import StandUpReminder

final class ReleaseInfoTests: XCTestCase {
    func testReleaseHighlightsAreReadFromInfoDictionary() {
        let highlights = ["支持暂停。", "可以查看版本。"]
        let infoDictionary: [String: Any] = [
            "SURReleaseHighlights": highlights
        ]

        XCTAssertEqual(
            AppReleaseInfo.updateItems(infoDictionary: infoDictionary),
            highlights
        )
        XCTAssertEqual(
            AppReleaseInfo.updateSummary(infoDictionary: infoDictionary),
            "• 支持暂停。\n• 可以查看版本。"
        )
    }

    func testMissingReleaseHighlightsUseFallbackText() {
        XCTAssertEqual(
            AppReleaseInfo.updateItems(infoDictionary: [:]),
            ["暂无更新说明。"]
        )
    }
}
