// 内惑星サイドパネルをオフスクリーンで PNG に描き出すツール
//
//   ./build.sh preview [YYYY-MM-DD]
//
// アプリを起動せずにパネルの見た目を確認できる。
// 満ち欠けの形や離角の東西が意図どおりかを目視で点検するのに使う。

import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let args = CommandLine.arguments

func parseDate(_ s: String) -> Date? {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Asia/Tokyo")
    for format in ["yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
        f.dateFormat = format
        if let d = f.date(from: s) { return d }
    }
    return nil
}

// 第 1 引数が "window" のときはウインドウ全体 (俯瞰図 + 操作パネル + サイドパネル)、
// それ以外は日時とみなしてサイドパネル単体を描く。
let wantsWholeWindow = args.count > 1 && args[1] == "window"

let dateArgIndex = wantsWholeWindow ? 2 : 1
let outputArgIndex = wantsWholeWindow ? 3 : 2

let targetDate: Date = args.count > dateArgIndex
    ? (parseDate(args[dateArgIndex]) ?? Date()) : Date()
let outputPath = args.count > outputArgIndex
    ? args[outputArgIndex]
    : (wantsWholeWindow ? "build/window-preview.png" : "build/panel-preview.png")

/// サブビューまで確実に再描画させる
func markDirty(_ view: NSView) {
    view.setNeedsDisplay(view.bounds)
    for sub in view.subviews { markDirty(sub) }
}

let target: NSView

if wantsWholeWindow {
    let container = MainContainerView(
        frame: NSRect(x: 0, y: 0, width: 1320, height: 840))
    container.appState.date = targetDate
    container.datePicker.dateValue = targetDate
    container.dateChanged()
    // 内惑星がはっきり見える倍率にしておく
    container.appState.zoom = 2.2
    container.sliderZoom.doubleValue = 2.2
    target = container
} else {
    let panel = InnerPlanetPanel()
    panel.frame = NSRect(x: 0, y: 0,
                         width: InnerPlanetPanel.preferredWidth,
                         height: panel.preferredHeight)
    panel.layoutContents()
    panel.update(date: targetDate, force: true)
    target = panel
}

markDirty(target)

guard let rep = target.bitmapImageRepForCachingDisplay(in: target.bounds) else {
    FileHandle.standardError.write("描画用ビットマップを作れませんでした\n".data(using: .utf8)!)
    exit(1)
}
target.cacheDisplay(in: target.bounds, to: rep)

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("PNG への変換に失敗しました\n".data(using: .utf8)!)
    exit(1)
}

try! png.write(to: URL(fileURLWithPath: outputPath))

let f = DateFormatter()
f.calendar = Calendar(identifier: .gregorian)
f.locale = Locale(identifier: "en_US_POSIX")
f.timeZone = TimeZone(identifier: "Asia/Tokyo")
f.dateFormat = "yyyy-MM-dd HH:mm"
print("\(f.string(from: targetDate)) JST のパネルを \(outputPath) に出力しました")
