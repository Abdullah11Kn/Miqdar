#!/usr/bin/env python3
"""Adds the mobile permissions used by the Miqdar Flutter prototype."""

from pathlib import Path


def configure_android(project: Path) -> None:
    manifest = project / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if not manifest.exists():
        return
    text = manifest.read_text(encoding="utf-8")
    permissions = '    <uses-permission android:name="android.permission.INTERNET" />\n'
    if "android.permission.INTERNET" not in text:
        manifest_start = text.find("<manifest")
        closing = text.find(">", manifest_start) + 1
        text = text[:closing] + "\n" + permissions + text[closing:]
    manifest.write_text(text, encoding="utf-8")

    debug_manifest = project / "android" / "app" / "src" / "debug" / "AndroidManifest.xml"
    if debug_manifest.exists():
        debug_text = debug_manifest.read_text(encoding="utf-8")
        if "android:usesCleartextTraffic" not in debug_text:
            debug_text = debug_text.replace(
                "</manifest>",
                '    <application android:usesCleartextTraffic="true" />\n</manifest>',
                1,
            )
        debug_manifest.write_text(debug_text, encoding="utf-8")


def configure_ios(project: Path) -> None:
    plist = project / "ios" / "Runner" / "Info.plist"
    if not plist.exists():
        return
    text = plist.read_text(encoding="utf-8")
    if "NSCameraUsageDescription" not in text:
        permissions = (
            "\t<key>NSCameraUsageDescription</key>\n"
            "\t<string>Miqdar uses the camera to recognize food.</string>\n"
            "\t<key>NSPhotoLibraryUsageDescription</key>\n"
            "\t<string>Miqdar can analyze a food photo selected by you.</string>\n"
        )
        text = text.replace("</dict>", permissions + "</dict>", 1)
    plist.write_text(text, encoding="utf-8")


def main() -> None:
    project = Path(__file__).resolve().parent.parent
    configure_android(project)
    configure_ios(project)
    print("Configured Miqdar iOS media permissions and local API networking.")


if __name__ == "__main__":
    main()
