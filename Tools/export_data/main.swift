// 技術解説の図に使うデータを、アプリ本体と同じ実装から書き出すツール
//
//   ./build.sh data
//
// 出力先は docs/tex/data/ 。解説文書のグラフが実装と食い違わないよう、
// 数値は必ずここから生成する。

import Cocoa

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/tex/data"
try? FileManager.default.createDirectory(atPath: outDir,
                                         withIntermediateDirectories: true)

let utc: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f
}()

func write(_ name: String, _ text: String) {
    let path = "\(outDir)/\(name)"
    try! text.write(toFile: path, atomically: true, encoding: .utf8)
    print("  \(path)")
}

print("データを書き出します:")

// MARK: - 1 会合周期にわたる内惑星の見え方

// 金星の内合を起点に 1 会合周期ぶん、離角・輝面比・視直径をたどる。
for (planet, synodicDays) in [(NASAElements.body(named: "金星")!, 583.92),
                              (NASAElements.body(named: "水星")!, 115.88)] {
    let start = utc.date(from: "2026-01-01 00:00")!
    // 起点を直後の内合に合わせると、1 周期が「内合 → 内合」で閉じる
    let ic = InnerPlanetPhenomena.upcomingEvents(for: planet, from: start)
        .first(where: { $0.kind == .inferiorConjunction })!.date

    // pgfplots が列名として読めるよう、先頭行はコメント記号なしの識別子にする
    // days:経過日数 elong:離角[度] signed:東西符号つき離角 k:輝面比 diam:視直径[秒角] dist:地心距離[AU]
    var lines = ["days elong signed k diam dist"]
    let steps = 600
    for i in 0...steps {
        let f = Double(i) / Double(steps) * synodicDays
        let t = ic.addingTimeInterval(f * 86400.0)
        let s = InnerPlanetPhenomena.status(for: planet, at: t)
        let signed = s.isEastern ? s.elongationDeg : -s.elongationDeg
        lines.append(String(format: "%.4f %.5f %.5f %.6f %.4f %.6f",
                            f, s.elongationDeg, signed, s.illuminatedFraction,
                            s.apparentDiameterArcsec, s.geocentricDistanceAU))
    }
    let name = planet.name == "金星" ? "venus" : "mercury"
    write("\(name)-synodic.dat", lines.joined(separator: "\n") + "\n")
}

// MARK: - 最大離角の分布 (10 年ぶん)

for planet in NASAElements.innerPlanets {
    // year:起点からの経過年 elong:離角[度] kind:1=東方 -1=西方
    var lines = ["year elong kind"]
    var cursor = utc.date(from: "2026-01-01 00:00")!
    let end = utc.date(from: "2036-01-01 00:00")!
    let epoch = cursor
    while cursor < end {
        let events = InnerPlanetPhenomena.upcomingEvents(for: planet, from: cursor)
        let elong = events.filter {
            $0.kind == .greatestEasternElongation || $0.kind == .greatestWesternElongation
        }
        guard let last = elong.map({ $0.date }).max() else { break }
        for e in elong where e.date < end {
            let years = e.date.timeIntervalSince(epoch) / (365.25 * 86400.0)
            let kind = e.kind == .greatestEasternElongation ? 1 : -1
            lines.append(String(format: "%.5f %.5f %d", years, e.elongationDeg, kind))
        }
        cursor = last.addingTimeInterval(3600)
    }
    let name = planet.name == "金星" ? "venus" : "mercury"
    write("\(name)-elongations.dat", lines.joined(separator: "\n") + "\n")
}

// MARK: - 2026 年の内惑星現象一覧 (本文の表に使う)

// tabular の内側で \input すると罫線マクロ (\noalign) の位置がずれるため、
// 表そのものをこのファイルで完結させて、本文からは丸ごと \input する。
var table = [
    "% 自動生成 (Tools/export_data)。手で編集しないこと。",
    "\\begin{tabular}{llll}",
    "\\toprule",
    "天体 & 現象 & 日時（JST） & 離角 \\\\",
    "\\midrule"
]
let jstFmt: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Asia/Tokyo")
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f
}()
for (index, planet) in NASAElements.innerPlanets.enumerated() {
    if index > 0 { table.append("\\midrule") }
    var cursor = utc.date(from: "2026-01-01 00:00")!
    let end = utc.date(from: "2027-01-01 00:00")!
    while cursor < end {
        let events = InnerPlanetPhenomena.upcomingEvents(for: planet, from: cursor)
        guard let next = events.min(by: { $0.date < $1.date }), next.date < end else { break }
        let elong = (next.kind == .greatestEasternElongation
                     || next.kind == .greatestWesternElongation)
            ? String(format: "$%.2f^\\circ$", next.elongationDeg) : "---"
        table.append("\(planet.name) & \(next.kind.label) & \(jstFmt.string(from: next.date)) & \(elong) \\\\")
        cursor = next.date.addingTimeInterval(3600)
    }
}
table.append("\\bottomrule")
table.append("\\end{tabular}")
write("phenomena-2026.tex", table.joined(separator: "\n") + "\n")

print("完了。")
