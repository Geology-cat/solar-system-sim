import Foundation
import CoreGraphics

/// 軌道力学の計算ユーティリティ
///
/// アルゴリズム出典:
///   JPL Solar System Dynamics
///   "Keplerian Elements for Approximate Positions of the Major Planets"
///   https://ssd.jpl.nasa.gov/planets/approx_pos.html
///
/// 手順:
///   1. J2000 からのユリウス世紀 T を求める
///   2. 軌道要素を T で線形外挿
///   3. 平均近点角 M = L - ϖ  (木星〜冥王星では追加項を加算)
///   4. ケプラー方程式 M = E - e·sin(E) を E について解く
///   5. 軌道面上の (x', y') を計算
///   6. ω, Ω, I による回転で黄道面座標 (x, y) へ変換
struct OrbitalMechanics {

    /// J2000.0 元期 (2000-01-01 12:00:00 UTC) の UNIX 時刻 [秒]
    /// 厳密な J2000.0 は TT (Terrestrial Time) 基準で、UTC との差 ΔT ≈ 68 秒は
    /// 本シミュレーターの可視精度では無視できる
    private static let j2000UnixTime: TimeInterval = 946728000

    /// J2000 からのユリウス世紀 T を返す
    static func julianCenturies(from date: Date) -> Double {
        let daysSinceJ2000 = (date.timeIntervalSince1970 - j2000UnixTime) / 86400.0
        return daysSinceJ2000 / 36525.0
    }

    /// 度をラジアンへ
    static func deg2rad(_ deg: Double) -> Double {
        return deg * .pi / 180.0
    }

    /// 角度 [degrees] を 0〜360 の範囲へ畳む
    static func normalizeDegrees(_ deg: Double) -> Double {
        var d = deg.truncatingRemainder(dividingBy: 360.0)
        if d < 0 { d += 360.0 }
        return d
    }

    /// ケプラー方程式 M = E - e·sin(E) を E について解く (ラジアン)
    ///
    /// ニュートン・ラフソン法。離心率 e < 0.6 程度なら数回で収束する。
    /// 初期推定は M + e·sin(M)/(1 - sin(M+e)+sin(M)) でなく単純な M を使用
    /// (収束性は十分)。tolerance を 1e-12 rad ≈ 2e-7 arcsec に強化。
    static func solveKepler(M: Double, e: Double) -> Double {
        var E = M + e * sin(M) // 一次近似でわずかに高速化
        let tolerance = 1e-12
        for _ in 0..<60 {
            let f  = E - e * sin(E) - M
            let fp = 1.0 - e * cos(E)
            let deltaE = f / fp
            E -= deltaE
            if abs(deltaE) < tolerance { break }
        }
        return E
    }

    /// 時刻 T (J2000 からのユリウス世紀) における要素を線形外挿し、
    /// 木星以遠の場合は平均近点角の追加摂動項を加える
    private static func meanAnomalyDegrees(elements el: OrbitalElements, T: Double) -> Double {
        let L_t = el.L + el.LRate * T
        let pi_t = el.longPeri + el.longPeriRate * T
        var M = L_t - pi_t

        // 外惑星の長周期摂動項 (JPL Table 2b の補足項)
        if el.b != 0.0 || el.c != 0.0 || el.s != 0.0 {
            let fT_rad = deg2rad(el.f * T)
            M += el.b * T * T + el.c * cos(fT_rad) + el.s * sin(fT_rad)
        }
        return M
    }

    /// 内部用: 軌道面 → 黄道面の変換に使う三角関数値をまとめた構造体
    private struct OrbitalFrame {
        let a: Double
        let e: Double
        let cw, sw, cn, sn, ci, si: Double
    }

    /// 時刻 T で軌道要素を評価し、回転行列の係数も準備する
    private static func makeFrame(elements el: OrbitalElements, T: Double) -> OrbitalFrame {
        let a = el.a + el.aRate * T
        let e = el.e + el.eRate * T
        let I = el.I + el.IRate * T
        let longPeri = el.longPeri + el.longPeriRate * T
        let longNode = el.longNode + el.longNodeRate * T

        // ω = ϖ - Ω (昇交点からの近日点引数)
        let w_rad = deg2rad(longPeri - longNode)
        let node_rad = deg2rad(longNode)
        let I_rad = deg2rad(I)

        return OrbitalFrame(
            a: a, e: e,
            cw: cos(w_rad), sw: sin(w_rad),
            cn: cos(node_rad), sn: sin(node_rad),
            ci: cos(I_rad), si: sin(I_rad)
        )
    }

    /// 軌道面上の (x', y') を回転行列で黄道面 (x, y) に変換する
    private static func eclipticXY(frame f: OrbitalFrame, xPrime: Double, yPrime: Double) -> CGPoint {
        // P・Q ベクトル (Murray & Dermott Solar System Dynamics, eq. 2.122)
        let Px = f.cw * f.cn - f.sw * f.sn * f.ci
        let Py = f.cw * f.sn + f.sw * f.cn * f.ci
        let Qx = -f.sw * f.cn - f.cw * f.sn * f.ci
        let Qy = -f.sw * f.sn + f.cw * f.cn * f.ci

        let x = Px * xPrime + Qx * yPrime
        let y = Py * xPrime + Qy * yPrime
        return CGPoint(x: x, y: y)
    }

    /// 指定時刻における天体の黄道面上の 2D 座標 (x, y) [AU]
    static func position(for body: CelestialBody, at date: Date) -> CGPoint {
        let T = julianCenturies(from: date)
        let el = body.elements

        let frame = makeFrame(elements: el, T: T)

        let M_deg = normalizeDegrees(meanAnomalyDegrees(elements: el, T: T))
        let M = deg2rad(M_deg)
        let E = solveKepler(M: M, e: frame.e)

        let xPrime = frame.a * (cos(E) - frame.e)
        let yPrime = frame.a * sqrt(1.0 - frame.e * frame.e) * sin(E)

        return eclipticXY(frame: frame, xPrime: xPrime, yPrime: yPrime)
    }

    /// 軌道を描画するためのポイント列。短期間では軌道形は不変なので
    /// 指定日 (デフォルトは現在) の要素で楕円を 1 周描く
    static func orbitPoints(for body: CelestialBody, at date: Date = Date(), segments: Int = 360) -> [CGPoint] {
        let T = julianCenturies(from: date)
        let frame = makeFrame(elements: body.elements, T: T)

        var points: [CGPoint] = []
        points.reserveCapacity(segments + 1)

        for i in 0...segments {
            let E = Double(i) / Double(segments) * 2.0 * .pi
            let xPrime = frame.a * (cos(E) - frame.e)
            let yPrime = frame.a * sqrt(1.0 - frame.e * frame.e) * sin(E)
            points.append(eclipticXY(frame: frame, xPrime: xPrime, yPrime: yPrime))
        }
        return points
    }
}
