// 軌道計算の自己整合性検証 (アプリには組み込まれない)
//
// 1. ケプラーの第三法則  T² / a³ = const  をチェック
//    (太陽中心 GMsun 単位系では T² = a³ なので、すべての惑星で T² / a³ = 1 になる)
// 2. 公転周期分だけ進めて元の位置に戻るかチェック
// 3. 春分日 (太陽中心系での Sun→Earth 方向が黄経 180°) の確認
//
// 比較値は天文学的に既知の量 (= 大きな桁数で正確) のみを使い、
// 自分で記憶している不正確な座標値は使わない

import Foundation

struct OrbitalElements {
    var a, e, I, L, longPeri, longNode: Double
    var aRate, eRate, IRate, LRate, longPeriRate, longNodeRate: Double
    var b: Double = 0.0
    var c: Double = 0.0
    var s: Double = 0.0
    var f: Double = 0.0
}

struct Body {
    let name: String
    let knownPeriodDays: Double // 既知の公転周期 [日] (NASA fact sheet 値)
    let el: OrbitalElements
}

let bodies: [Body] = [
    Body(name: "水星", knownPeriodDays: 87.969, el: OrbitalElements(
        a: 0.38709843, e: 0.20563661, I: 7.00559432,
        L: 252.25166724, longPeri: 77.45771895, longNode: 48.33961819,
        aRate: 0.0, eRate: 0.00002123, IRate: -0.00590158,
        LRate: 149472.67486623, longPeriRate: 0.15940013, longNodeRate: -0.12214182)),
    Body(name: "金星", knownPeriodDays: 224.701, el: OrbitalElements(
        a: 0.72332102, e: 0.00676399, I: 3.39777545,
        L: 181.97970850, longPeri: 131.76755713, longNode: 76.67261496,
        aRate: -0.00000026, eRate: -0.00005107, IRate: 0.00043494,
        LRate: 58517.81560260, longPeriRate: 0.05679648, longNodeRate: -0.27274174)),
    Body(name: "地球", knownPeriodDays: 365.256, el: OrbitalElements(
        a: 1.00000018, e: 0.01673163, I: -0.00054346,
        L: 100.46691572, longPeri: 102.93005885, longNode: -5.11260389,
        aRate: -0.00000003, eRate: -0.00003661, IRate: -0.01337178,
        LRate: 35999.37306329, longPeriRate: 0.31795260, longNodeRate: -0.24123856)),
    Body(name: "火星", knownPeriodDays: 686.980, el: OrbitalElements(
        a: 1.52371243, e: 0.09336511, I: 1.85181869,
        L: -4.56813164, longPeri: -23.91744784, longNode: 49.71320984,
        aRate: 0.00000097, eRate: 0.00009149, IRate: -0.00724757,
        LRate: 19140.29934243, longPeriRate: 0.45223625, longNodeRate: -0.26852431)),
    Body(name: "木星", knownPeriodDays: 4332.589, el: OrbitalElements(
        a: 5.20248019, e: 0.04853590, I: 1.29861416,
        L: 34.33479152, longPeri: 14.27495244, longNode: 100.29282654,
        aRate: -0.00002864, eRate: 0.00018026, IRate: -0.00322699,
        LRate: 3034.90371757, longPeriRate: 0.18199196, longNodeRate: 0.13024619,
        b: -0.00012452, c: 0.06064060, s: -0.35635438, f: 38.35125000)),
    Body(name: "土星", knownPeriodDays: 10759.22, el: OrbitalElements(
        a: 9.54149883, e: 0.05550825, I: 2.49424102,
        L: 50.07571329, longPeri: 92.86136063, longNode: 113.63998702,
        aRate: -0.00003065, eRate: -0.00032044, IRate: 0.00451969,
        LRate: 1222.11494724, longPeriRate: 0.54179478, longNodeRate: -0.25015002,
        b: 0.00025899, c: -0.13434469, s: 0.87320147, f: 38.35125000)),
    Body(name: "天王星", knownPeriodDays: 30688.5, el: OrbitalElements(
        a: 19.18797948, e: 0.04685740, I: 0.77298127,
        L: 314.20276625, longPeri: 172.43404441, longNode: 73.96250215,
        aRate: -0.00020455, eRate: -0.00001550, IRate: -0.00180155,
        LRate: 428.49512595, longPeriRate: 0.09266985, longNodeRate: 0.05739699,
        b: 0.00058331, c: -0.97731848, s: 0.17689245, f: 7.67025000)),
    Body(name: "海王星", knownPeriodDays: 60182.0, el: OrbitalElements(
        a: 30.06952752, e: 0.00895439, I: 1.77005520,
        L: 304.22289287, longPeri: 46.68158724, longNode: 131.78635853,
        aRate: 0.00006447, eRate: 0.00000818, IRate: 0.00022400,
        LRate: 218.46515314, longPeriRate: 0.01009938, longNodeRate: -0.00606302,
        b: -0.00041348, c: 0.68346318, s: -0.10162547, f: 7.67025000)),
    Body(name: "冥王星", knownPeriodDays: 90560.0, el: OrbitalElements(
        a: 39.48686035, e: 0.24885238, I: 17.14104260,
        L: 238.96535011, longPeri: 224.09702598, longNode: 110.30167986,
        aRate: 0.00449751, eRate: 0.00006016, IRate: 0.00000501,
        LRate: 145.18042903, longPeriRate: -0.00968827, longNodeRate: -0.00809981,
        b: -0.01262724)),
]

func deg2rad(_ d: Double) -> Double { d * .pi / 180.0 }
func rad2deg(_ r: Double) -> Double { r * 180.0 / .pi }
func normalize(_ d: Double) -> Double {
    var x = d.truncatingRemainder(dividingBy: 360.0)
    if x < 0 { x += 360.0 }
    return x
}
func solveKepler(M: Double, e: Double) -> Double {
    var E = M + e * sin(M)
    for _ in 0..<60 {
        let dE = (E - e * sin(E) - M) / (1.0 - e * cos(E))
        E -= dE
        if abs(dE) < 1e-12 { break }
    }
    return E
}

// J2000 (UNIX 946728000) からのユリウス世紀
func julianCenturies(_ unix: TimeInterval) -> Double {
    return ((unix - 946728000.0) / 86400.0) / 36525.0
}

func position3D(_ b: Body, T: Double) -> (Double, Double, Double) {
    let el = b.el
    let a = el.a + el.aRate * T
    let e = el.e + el.eRate * T
    let I = el.I + el.IRate * T
    let L = el.L + el.LRate * T
    let pi_ = el.longPeri + el.longPeriRate * T
    let node = el.longNode + el.longNodeRate * T

    var M = L - pi_
    if el.b != 0 || el.c != 0 || el.s != 0 {
        let fT = deg2rad(el.f * T)
        M += el.b * T * T + el.c * cos(fT) + el.s * sin(fT)
    }
    let M_rad = deg2rad(normalize(M))
    let E = solveKepler(M: M_rad, e: e)

    let xp = a * (cos(E) - e)
    let yp = a * sqrt(1 - e * e) * sin(E)

    let w = deg2rad(pi_ - node)
    let O = deg2rad(node)
    let i = deg2rad(I)
    let cw = cos(w), sw = sin(w)
    let cO = cos(O), sO = sin(O)
    let ci = cos(i), si = sin(i)

    let x = (cw * cO - sw * sO * ci) * xp + (-sw * cO - cw * sO * ci) * yp
    let y = (cw * sO + sw * cO * ci) * xp + (-sw * sO + cw * cO * ci) * yp
    let z = (sw * si) * xp + (cw * si) * yp
    return (x, y, z)
}

// ===== テスト 1: ケプラーの第三法則 T_days² = a_AU³ × 365.25² =====
print("== Test 1: ケプラー第三法則 (T[日]² / a[AU]³ → 既知値) と公転周期 ==\n")
print("天体         : LRate由来周期[日]   既知値[日]    比 (≈1.0)    a³[AU³]   T²/a³[AU年単位]")
for b in bodies {
    let T_centuries_per_rev = 360.0 / b.el.LRate
    let T_days = T_centuries_per_rev * 36525.0
    let a = b.el.a
    let a3 = a * a * a
    // ケプラー第三法則: T[年]² = a[AU]³  (太陽質量単位)
    let T_years = T_days / 365.25
    let ratio = (T_years * T_years) / a3
    let calcVsKnown = T_days / b.knownPeriodDays
    print(String(format: "%@: %14.3f  %14.3f  %8.6f   %10.3f   %.6f",
                 padR(b.name, 8), T_days, b.knownPeriodDays, calcVsKnown, a3, ratio))
}

// ===== テスト 2: 一周期分進めて元の位置に戻るかチェック =====
// ただし要素自体が線形外挿で変化するので「ほぼ戻る」レベル
print("\n== Test 2: 公転周期 (LRate由来) 進めて軌道座標が戻るか ==\n")
print("天体    : 初期位置 r [AU]   差分 ‖Δ‖ [AU] (小さいほど良い)")
let T0 = julianCenturies(Date().timeIntervalSince1970)
for b in bodies {
    let (x0, y0, z0) = position3D(b, T: T0)
    // ちょうど 360° = 1周期 = (360 / LRate) 世紀
    let T1 = T0 + 360.0 / b.el.LRate
    let (x1, y1, z1) = position3D(b, T: T1)
    let r0 = sqrt(x0*x0 + y0*y0 + z0*z0)
    let dx = x1 - x0, dy = y1 - y0, dz = z1 - z0
    let d = sqrt(dx*dx + dy*dy + dz*dz)
    print(String(format: "%@: %8.4f         %.6f", padR(b.name, 8), r0, d))
}

// ===== テスト 3: 太陽中心黄道座標で、地球は近日点付近で r が最小、遠日点で最大 =====
print("\n== Test 3: 地球の太陽距離 r が e の許す範囲 [a(1-e), a(1+e)] に収まるか ==\n")
print("天体    : a       e       a(1-e)     a(1+e)    min(r)    max(r)")
for b in bodies {
    let a = b.el.a
    let e = b.el.e
    let rmin = a * (1 - e)
    let rmax = a * (1 + e)
    // 軌道上 360点をサンプリング
    var rs: [Double] = []
    for i in 0..<360 {
        let T = T0 + Double(i) / 360.0 * (360.0 / b.el.LRate) // 1周期を360分割
        let (x, y, z) = position3D(b, T: T)
        rs.append(sqrt(x*x + y*y + z*z))
    }
    let rmin_calc = rs.min()!
    let rmax_calc = rs.max()!
    print(String(format: "%@: %.4f  %.5f   %.4f    %.4f   %.4f    %.4f",
                 padR(b.name, 8), a, e, rmin, rmax, rmin_calc, rmax_calc))
}

// ===== テスト 4: 春分日 (2025-03-20 09:01 UTC) における 地球→太陽 方向 =====
// 春分日には、太陽 (Sun) は地球から見て黄経 0° (春分点) 方向。
// → 太陽中心系では、地球は黄経 180° 方向 = (-1, 0, 0) 付近
print("\n== Test 4: 2025年 春分点 (2025-03-20 09:01 UTC) における地球の太陽中心黄経 ==\n")
let vernal2025: TimeInterval = 1742461260 // 2025-03-20 09:01 UTC
let T_vernal = julianCenturies(vernal2025)
let earth = bodies.first(where: { $0.name == "地球" })!
let (ex, ey, ez) = position3D(earth, T: T_vernal)
let longEcl = rad2deg(atan2(ey, ex))
print(String(format: "地球の太陽中心黄道座標: (%.4f, %.4f, %.4f) AU", ex, ey, ez))
print(String(format: "太陽中心系での地球の黄経: %.3f° (期待値 ≈ 180°)", normalize(longEcl)))

// ===== ヘルパー =====
func padR(_ s: String, _ width: Int) -> String {
    let need = max(0, width - s.count * 2) // 全角を2幅と数える簡易版
    return s + String(repeating: " ", count: need)
}
