// 軌道計算の検証ツール (アプリ本体には組み込まれない)
//
// Sources/ の実装をそのままリンクして検証するので、
// 「検証用に書き写したコード」と本体がずれる心配がない。
//
//   ./build.sh verify
//
// 検証の考え方:
//   自分の記憶に頼った座標値とは突き合わせない。
//   代わりに (a) 物理法則から導かれる恒等式、(b) 大きな桁数で確立している
//   天文定数 (公転周期・会合周期・最大離角の変動範囲など) と比較する。

import Cocoa

// MARK: - 出力ヘルパー

var failures = 0

func title(_ s: String) {
    print("\n\u{001B}[1m== \(s) ==\u{001B}[0m")
}

func check(_ label: String, _ ok: Bool, _ detail: String) {
    if ok {
        print("  \u{001B}[32m[OK]\u{001B}[0m   \(label): \(detail)")
    } else {
        failures += 1
        print("  \u{001B}[31m[NG]\u{001B}[0m   \(label): \(detail)")
    }
}

func info(_ s: String) { print("        \(s)") }

/// 全角を 2 幅と数えて左詰めする
func padR(_ s: String, _ width: Int) -> String {
    var w = 0
    for ch in s.unicodeScalars { w += ch.value < 0x100 ? 1 : 2 }
    return s + String(repeating: " ", count: max(0, width - w))
}

let jst: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Asia/Tokyo")
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f
}()

func date(_ iso: String) -> Date {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: iso)!
}

let now = Date()

// MARK: - 1. ケプラーの第三法則

// 太陽質量単位では T[年]² = a[AU]³ が厳密に成り立つ。
// LRate (平均黄経の増加率) から求めた周期がこれを満たすか見る。
title("1. ケプラーの第三法則 T[年]² = a[AU]³")

// NASA Planetary Fact Sheet の公転周期 [日]
let knownPeriods: [String: Double] = [
    "水星": 87.969, "金星": 224.701, "地球": 365.256, "火星": 686.980,
    "木星": 4332.589, "土星": 10759.22, "天王星": 30688.5,
    "海王星": 60182.0, "冥王星": 90560.0
]

print("  天体      周期(計算)[日]   周期(既知)[日]      比      T²/a³")
for body in NASAElements.planets {
    let periodDays = 360.0 / body.elements.LRate * 36525.0
    let known = knownPeriods[body.name]!
    let periodYears = periodDays / 365.25
    let a3 = pow(body.elements.a, 3)
    let ratio = periodYears * periodYears / a3
    let vsKnown = periodDays / known
    print(String(format: "  %@ %14.3f %15.3f %10.6f %10.6f",
                 padR(body.name, 8), periodDays, known, vsKnown, ratio))
    check("\(body.name) の周期",
          abs(vsKnown - 1.0) < 0.001,
          String(format: "既知値との比 %.6f (許容 ±0.1%%)", vsKnown))
}

// MARK: - 2. 日心距離が [a(1-e), a(1+e)] に収まるか

title("2. 日心距離 r が軌道の許す範囲に収まるか")
for body in NASAElements.planets {
    let a = body.elements.a
    let e = body.elements.e
    let periodDays = 360.0 / body.elements.LRate * 36525.0
    var rs: [Double] = []
    for i in 0..<720 {
        let t = now.addingTimeInterval(Double(i) / 720.0 * periodDays * 86400.0)
        rs.append(OrbitalMechanics.position3D(for: body, at: t).length)
    }
    let rmin = rs.min()!, rmax = rs.max()!
    // 要素の線形外挿で a, e もわずかに動くため 0.5% の余裕を見る
    let ok = rmin > a * (1 - e) * 0.995 && rmax < a * (1 + e) * 1.005
    check(padR(body.name, 8), ok,
          String(format: "r ∈ [%.4f, %.4f] / 理論 [%.4f, %.4f] AU",
                 rmin, rmax, a * (1 - e), a * (1 + e)))
}

// MARK: - 3. 軌道傾斜 (z 成分) が効いているか

title("3. 面外成分 z が軌道傾斜と整合するか")
// 日心黄緯 β の最大値は軌道傾斜角 I に一致するはず
for body in NASAElements.planets {
    let periodDays = 360.0 / body.elements.LRate * 36525.0
    var maxBeta = 0.0
    for i in 0..<2000 {
        let t = now.addingTimeInterval(Double(i) / 2000.0 * periodDays * 86400.0)
        let v = OrbitalMechanics.position3D(for: body, at: t)
        let beta = abs(asin(v.z / v.length) * 180.0 / .pi)
        maxBeta = max(maxBeta, beta)
    }
    let I = abs(body.elements.I)
    check(padR(body.name, 8), abs(maxBeta - I) < 0.02,
          String(format: "最大日心黄緯 %.4f° / 軌道傾斜角 %.4f°", maxBeta, I))
}

// MARK: - 4. 春分点における地球の日心黄経

title("4. 2025年春分 (2025-03-20 09:01 UTC) の地球の日心黄経")
// 春分の瞬間、地球から見た太陽は「その日の真の春分点」の方向 = 黄経 0°。
// 日心系では地球がその反対、黄経 180° にある。
//
// ただし本シミュレーターの座標系は J2000.0 の平均黄道・平均分点に固定されている。
// 春分点は歳差で年 50.3 秒角ずつ西へ動くので、2025 年の春分点は J2000 の春分点から
//   p = 5028.796195″/世紀 × T
// だけずれている。よって J2000 系で測った地球の黄経は 180° - p になるはず。
let vernal = date("2025-03-20 09:01")
let T_vernal = OrbitalMechanics.julianCenturies(from: vernal)
let precessionDeg = 5028.796195 * T_vernal / 3600.0   // IAU 2006 一般歳差 (黄経)
let expectedLongitude = 180.0 - precessionDeg

let earthAtVernal = OrbitalMechanics.position3D(for: NASAElements.earth, at: vernal)
let lambda = earthAtVernal.eclipticLongitudeDeg
let residualArcsec = abs(lambda - expectedLongitude) * 3600.0

info(String(format: "座標 (%.6f, %.6f, %.6f) AU",
            earthAtVernal.x, earthAtVernal.y, earthAtVernal.z))
info(String(format: "J2000 からの歳差 %.1f″ (= %.2f 分角) を差し引いた期待値 %.4f°",
            precessionDeg * 3600, precessionDeg * 60, expectedLongitude))
// 低精度軌道要素の平均黄経誤差 (数分角) に収まっていればよい
check("地球の日心黄経", residualArcsec < 180.0,
      String(format: "%.4f° / 期待 %.4f° 残差 %.0f″ (許容 180″)",
             lambda, expectedLongitude, residualArcsec))

// MARK: - 5. 輝面比と位相角の整合

title("5. 輝面比 k = (1 + cos i) / 2 の整合と値域")
for planet in NASAElements.innerPlanets {
    var minK = 1.0, maxK = 0.0
    var consistent = true
    for i in 0..<4000 {
        let t = now.addingTimeInterval(Double(i) * 0.25 * 86400.0)
        let s = InnerPlanetPhenomena.status(for: planet, at: t)
        minK = min(minK, s.illuminatedFraction)
        maxK = max(maxK, s.illuminatedFraction)
        let expected = (1 + cos(s.phaseAngleDeg * .pi / 180)) / 2
        if abs(expected - s.illuminatedFraction) > 1e-12 { consistent = false }
        if s.illuminatedFraction < -1e-12 || s.illuminatedFraction > 1 + 1e-12 { consistent = false }
    }
    check(padR(planet.name, 8), consistent,
          String(format: "k は定義式と一致し 0〜1 に収まる (実測 %.4f 〜 %.4f)", minK, maxK))
}

// MARK: - 6. 最大離角の変動範囲

title("6. 最大離角の変動範囲")
// 離心率のため最大離角は毎回異なる。天文年鑑等で知られる変動範囲:
//   水星 17.9° 〜 27.8°   金星 45.4° 〜 47.1°
let expectedElongationRange: [String: (Double, Double)] = [
    "水星": (17.9, 27.8),
    "金星": (45.4, 47.1)
]

for planet in NASAElements.innerPlanets {
    var eastern: [(Date, Double)] = []
    var western: [(Date, Double)] = []
    // 10 年分の最大離角を集める
    var cursor = now
    let end = now.addingTimeInterval(3650 * 86400)
    while cursor < end {
        let events = InnerPlanetPhenomena.upcomingEvents(for: planet, from: cursor)
        let elongations = events.filter {
            $0.kind == .greatestEasternElongation || $0.kind == .greatestWesternElongation
        }
        guard let last = elongations.map({ $0.date }).max() else { break }
        for e in elongations where e.date < end {
            if e.kind == .greatestEasternElongation { eastern.append((e.date, e.elongationDeg)) }
            else { western.append((e.date, e.elongationDeg)) }
        }
        cursor = last.addingTimeInterval(3600)
    }

    let all = (eastern + western).map { $0.1 }
    let (lo, hi) = expectedElongationRange[planet.name]!
    let observedMin = all.min() ?? 0
    let observedMax = all.max() ?? 0
    // 探索した 10 年でちょうど端まで出るとは限らないので、
    // 「範囲内に収まっていること」と「幅がそれらしいこと」を見る
    check(padR(planet.name, 8),
          observedMin >= lo - 0.3 && observedMax <= hi + 0.3,
          String(format: "10年分 %d 回の最大離角は %.2f°〜%.2f° (既知の範囲 %.1f°〜%.1f°)",
                 all.count, observedMin, observedMax, lo, hi))
    info("直近の最大離角:")
    for e in (eastern.prefix(2).map { ("東方", $0) } + western.prefix(2).map { ("西方", $0) })
        .sorted(by: { $0.1.0 < $1.1.0 }) {
        info(String(format: "  %@最大離角  %@ JST  %.2f°", e.0, jst.string(from: e.1.0), e.1.1))
    }
}

// MARK: - 7. 会合周期

title("7. 合から合までの間隔 (会合周期)")
// 既知の会合周期: 水星 115.88 日、金星 583.92 日
let knownSynodic: [String: Double] = ["水星": 115.88, "金星": 583.92]

for planet in NASAElements.innerPlanets {
    var inferior: [Date] = []
    var cursor = now
    // 水星は離心率が大きく、内合の間隔が 106〜126 日と大きく振れる。
    // 平均が既知値に収束するかを見たいので区間数を多めに取る。
    for _ in 0..<31 {
        let events = InnerPlanetPhenomena.upcomingEvents(for: planet, from: cursor)
        guard let ic = events.first(where: { $0.kind == .inferiorConjunction }) else { break }
        inferior.append(ic.date)
        cursor = ic.date.addingTimeInterval(86400)
    }
    guard inferior.count >= 3 else {
        check(padR(planet.name, 8), false, "内合が 3 回以上見つからなかった")
        continue
    }
    var gaps: [Double] = []
    for i in 1..<inferior.count {
        gaps.append(inferior[i].timeIntervalSince(inferior[i - 1]) / 86400.0)
    }
    let mean = gaps.reduce(0, +) / Double(gaps.count)
    let known = knownSynodic[planet.name]!
    check(padR(planet.name, 8), abs(mean - known) < 1.0,
          String(format: "内合間隔の平均 %.2f 日 (既知 %.2f 日、%d 区間)", mean, known, gaps.count))
    info(String(format: "  各区間: %@", gaps.map { String(format: "%.1f", $0) }.joined(separator: ", ")))
}

// MARK: - 8. 内合・外合における輝面比と視直径

title("8. 内合・外合での輝面比・視直径")
// 内合では惑星がほぼ地球と太陽の間 → k ≈ 0、視直径はその周期で最大
// 外合では太陽の向こう側          → k ≈ 1、視直径はその周期で最小
//
// 「内合のたびに視直径が最大値まで太る」わけではない点に注意。
// 内合が起きる位置が近日点寄りか遠日点寄りかで地心距離が変わるため、
// 水星の内合時の視直径は 9.9″〜12.2″、金星は 60″〜66″ の幅で変動する。
// ここでは既知の変動範囲に収まっているかどうかを見る。
let knownDiameterRange: [String: (Double, Double)] = [
    "水星": (4.5, 13.0),
    "金星": (9.6, 66.0)
]

for planet in NASAElements.innerPlanets {
    let events = InnerPlanetPhenomena.upcomingEvents(for: planet, from: now)
    for e in events where e.kind == .inferiorConjunction || e.kind == .superiorConjunction {
        let s = InnerPlanetPhenomena.status(for: planet, at: e.date)
        let (dLo, dHi) = knownDiameterRange[planet.name]!
        let inRange = s.apparentDiameterArcsec >= dLo && s.apparentDiameterArcsec <= dHi
        if e.kind == .inferiorConjunction {
            // 内合では視直径が範囲の上半分に来るはず
            check("\(padR(planet.name, 6))内合",
                  s.illuminatedFraction < 0.05 && inRange
                      && s.apparentDiameterArcsec > (dLo + dHi) / 2,
                  String(format: "%@ JST  k=%.4f  視直径 %.1f″ (既知の範囲 %.1f〜%.1f″)",
                         jst.string(from: e.date), s.illuminatedFraction,
                         s.apparentDiameterArcsec, dLo, dHi))
        } else {
            // 外合では視直径が最小付近に来るはず
            check("\(padR(planet.name, 6))外合",
                  s.illuminatedFraction > 0.99 && inRange
                      && s.apparentDiameterArcsec < dLo * 1.15,
                  String(format: "%@ JST  k=%.4f  視直径 %.1f″ (既知の最小 %.1f″)",
                         jst.string(from: e.date), s.illuminatedFraction,
                         s.apparentDiameterArcsec, dLo))
        }
    }
}

// MARK: - 9. 離角の東西判定

title("9. 東方/西方の判定が最大離角の並びと整合するか")
// 内合をはさんで 東方最大離角 → 内合 → 西方最大離角 の順に並ぶはず。
for planet in NASAElements.innerPlanets {
    var seq: [(Date, String)] = []
    var cursor = now
    for _ in 0..<8 {
        let events = InnerPlanetPhenomena.upcomingEvents(for: planet, from: cursor)
        guard let next = events.first else { break }
        seq.append((next.date, next.kind.label))
        cursor = next.date.addingTimeInterval(3600)
    }
    // 「東方最大離角の直後の現象が内合」であることを確かめる
    var ok = true
    for i in 0..<max(0, seq.count - 1) where seq[i].1 == "東方最大離角" {
        if seq[i + 1].1 != "内合" { ok = false }
    }
    check(padR(planet.name, 8), ok,
          "東方最大離角の次は内合 → " + seq.map { $0.1 }.joined(separator: " → "))
}

// MARK: - 集計

print("")
if failures == 0 {
    print("\u{001B}[32m全ての検証項目に合格しました。\u{001B}[0m")
} else {
    print("\u{001B}[31m\(failures) 件の検証項目が不合格です。\u{001B}[0m")
    exit(1)
}
