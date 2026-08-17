import Cocoa

/// ケプラー軌道要素（J2000.0 元期の値と、1ユリウス世紀あたりの変化率）
///
/// 出典: JPL Solar System Dynamics
///   "Keplerian Elements for Approximate Positions of the Major Planets"
///   https://ssd.jpl.nasa.gov/planets/approx_pos.html
///   Table 2b (有効範囲: 3000 BC 〜 3000 AD)
///
/// 元期: J2000.0 (= JD 2451545.0 = 2000-01-01 12:00 TT)
/// 角度単位は度、レートは度/ユリウス世紀。
struct OrbitalElements {
    var a: Double        // 軌道長半径 (Semi-major axis) [AU]
    var e: Double        // 軌道離心率 (Eccentricity) [無次元]
    var I: Double        // 軌道傾斜角 (Inclination) [度]
    var L: Double        // 平均黄経 (Mean longitude) [度]
    var longPeri: Double // 近日点黄経 ϖ (Longitude of perihelion) [度]
    var longNode: Double // 昇交点黄経 Ω (Longitude of ascending node) [度]

    // 1ユリウス世紀あたりの変化率
    var aRate: Double
    var eRate: Double
    var IRate: Double
    var LRate: Double
    var longPeriRate: Double
    var longNodeRate: Double

    // 外惑星 (木星〜冥王星) 用の追加摂動項。
    // M = L - ϖ + b·T² + c·cos(f·T) + s·sin(f·T)
    // (f は度/世紀。cos/sin に渡す前にラジアン換算する)
    var b: Double = 0.0
    var c: Double = 0.0
    var s: Double = 0.0
    var f: Double = 0.0
}

/// 太陽系天体のデータモデル
struct CelestialBody {
    let name: String
    let color: NSColor            // 描画色
    let radiusMultiplier: Double  // 俯瞰図での描画サイズ基準 (地球 = 1.0)
    let equatorialRadiusKm: Double // 赤道半径 [km] (視直径の算出に使用)
    let elements: OrbitalElements
}
