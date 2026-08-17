import SwiftUI

/// ケプラー軌道要素（J2000元期からの変化量含む）
///
/// 出典: JPL Solar System Dynamics
///   "Keplerian Elements for Approximate Positions of the Major Planets"
///   https://ssd.jpl.nasa.gov/planets/approx_pos.html
///
/// 値は J2000.0 (= JD 2451545.0 = 2000-01-01 12:00 TT) 元期での値、
/// レートは 1 ユリウス世紀 (36525 日) あたりの変化量。
/// 角度はすべて度。
struct OrbitalElements {
    var a: Double        // 軌道長半径 (Semi-major axis) [AU]
    var e: Double        // 軌道離心率 (Eccentricity) [無次元]
    var I: Double        // 軌道傾斜角 (Inclination) [degrees]
    var L: Double        // 平均黄経 (Mean longitude) [degrees]
    var longPeri: Double // 近日点黄経 ϖ (Longitude of perihelion) [degrees]
    var longNode: Double // 昇交点黄経 Ω (Longitude of ascending node) [degrees]

    // 1ユリウス世紀あたりの変化率
    var aRate: Double
    var eRate: Double
    var IRate: Double
    var LRate: Double
    var longPeriRate: Double
    var longNodeRate: Double

    // 外惑星 (木星〜冥王星) 用の追加摂動項。
    // M = L - ϖ + b·T² + c·cos(f·T) + s·sin(f·T)
    // (f は度/世紀、cos/sin に渡す前にラジアン換算する)
    var b: Double = 0.0
    var c: Double = 0.0
    var s: Double = 0.0
    var f: Double = 0.0
}

/// 太陽系天体のデータモデル
struct CelestialBody: Identifiable {
    let id = UUID()
    let name: String
    let color: Color           // 描画時の色
    let radiusMultiplier: Double // 描画サイズの基準
    let elements: OrbitalElements
}
