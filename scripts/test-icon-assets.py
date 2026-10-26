#!/usr/bin/env python3
"""验证发布所需的图标容器与工程资源声明，无第三方依赖。"""

import pathlib
import plistlib
import struct
import unittest
import xml.etree.ElementTree as ET


ROOT = pathlib.Path(__file__).resolve().parents[1]


class IconAssetsTests(unittest.TestCase):
    def test_macos_icon_contains_standard_and_retina_sizes(self):
        data = (ROOT / "Resources/AppIcon.icns").read_bytes()
        self.assertEqual(data[:4], b"icns")
        self.assertEqual(struct.unpack(">I", data[4:8])[0], len(data))
        types = set()
        offset = 8
        while offset < len(data):
            kind, length = struct.unpack(">4sI", data[offset:offset + 8])
            self.assertGreater(length, 8)
            types.add(kind)
            offset += length
        self.assertEqual(offset, len(data))
        self.assertTrue({b"icp4", b"icp5", b"ic07", b"ic08", b"ic09", b"ic10"} <= types)
        with (ROOT / "Resources/Info.plist").open("rb") as file:
            self.assertEqual(plistlib.load(file)["CFBundleIconFile"], "AppIcon")

    def test_menu_bar_has_normal_and_retina_pngs(self):
        for name, size in [("MenuBarIcon.png", 18), ("MenuBarIcon@2x.png", 36)]:
            data = (ROOT / "Resources" / name).read_bytes()
            self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
            self.assertEqual(struct.unpack(">II", data[16:24]), (size, size))
            self.assertEqual(data[25], 6, "菜单栏图标需要 RGBA 透明通道")

    def test_windows_icon_contains_small_and_high_dpi_sizes(self):
        data = (ROOT / "windows/src/StandUpReminder.App/Assets/AppIcon.ico").read_bytes()
        reserved, kind, count = struct.unpack("<HHH", data[:6])
        self.assertEqual((reserved, kind), (0, 1))
        sizes = set()
        for i in range(count):
            width, height, _, _, _, _, length, offset = struct.unpack(
                "<BBBBHHII", data[6 + 16 * i:22 + 16 * i]
            )
            sizes.add(width or 256)
            self.assertEqual(width, height)
            self.assertGreater(length, 0)
            self.assertLessEqual(offset + length, len(data))
        self.assertTrue({16, 24, 32, 48, 64, 128, 256} <= sizes)

    def test_windows_icon_is_embedded_for_single_file_publishing(self):
        project = ET.parse(ROOT / "windows/src/StandUpReminder.App/StandUpReminder.App.csproj")
        self.assertEqual(project.findtext(".//ApplicationIcon"), "Assets\\AppIcon.ico")
        icons = project.findall(".//EmbeddedResource")
        self.assertTrue(any(
            item.attrib.get("Include") == "Assets\\AppIcon.ico"
            and item.attrib.get("LogicalName") == "StandUpReminder.AppIcon.ico"
            for item in icons
        ))


if __name__ == "__main__":
    unittest.main()
