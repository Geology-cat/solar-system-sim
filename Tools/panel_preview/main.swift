// 内惑星サイドパネルをオフスクリーンで PNG に描き出すツール
//
//   ./build.sh preview [YYYY-MM-DD]
//
// アプリを起動せずにパネルの見た目を確認できる。
// 満ち欠けの形や離角の東西が意図どおりかを目視で点検するのに使う。

import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

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

let targetDate: Date = args.count > 1 ? (parseDate(args[1]) ?? Date()) : Date()
let outputPath = args.count > 2 ? args[2] : "build/panel-preview.png"

let panel = InnerPlanetPanel()
panel.frame = NSRect(x: 0, y: 0,
                     width: InnerPlanetPanel.preferredWidth,
                     height: panel.preferredHeight)
panel.layoutContents()
panel.update(date: targetDate, force: true)

// 一度レイアウト後にサブビューまで確実に再描画させる
panel.setNeedsDisplay(panel.bounds)
for sub in panel.subviews {
    sub.setNeedsDisplay(sub.bounds)
    for s2 in sub.subviews { s2.setNeedsDisplay(s2.bounds) }
}

guard let rep = panel.bitmapImageRepForCachingDisplay(in: panel.bounds) else {
    FileHandle.standardError.write("描画用ビットマップを作れませんでした\n".data(using: .utf8)!)
    exit(1)
}
panel.cacheDisplay(in: panel.bounds, to: rep)

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
