import Cocoa

/// 黄道座標系の 3 次元ベクトル [AU]
///
/// J2000.0 平均黄道・平均分点を基準とし、
///   x: 春分点 (♈) 方向
///   y: 黄経 +90° 方向
///   z: 北黄極方向
struct Vector3 {
    var x: Double
    var y: Double
    var z: Double

    static let zero = Vector3(x: 0, y: 0, z: 0)

    var length: Double { return (x * x + y * y + z * z).squareRoot() }

    static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    static prefix func - (v: Vector3) -> Vector3 {
        return Vector3(x: -v.x, y: -v.y, z: -v.z)
    }

    func dot(_ other: Vector3) -> Double {
        return x * other.x + y * other.y + z * other.z
    }

    /// 黄経 λ [度] (0〜360)
    var eclipticLongitudeDeg: Double {
        return OrbitalMechanics.normalizeDegrees(atan2(y, x) * 180.0 / .pi)
    }

    /// 2 ベクトルのなす角 [度] (0〜180)
    func angleDeg(to other: Vector3) -> Double {
        let denom = length * other.length
        if denom == 0 { return 0 }
        // 丸め誤差で |cos| がわずかに 1 を超えることがあるためクランプする
        let c = max(-1.0, min(1.0, dot(other) / denom))
        return acos(c) * 180.0 / .pi
    }
}

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
///   6. ω, Ω, I による回転で黄道座標 (x, y, z) へ変換
struct OrbitalMechanics {

    /// 1 天文単位 [km] (IAU 2012 定義値)
    static let auInKm: Double = 149597870.7

    /// 1 ラジアンあたりの秒角
    static let arcsecPerRadian: Double = 180.0 * 3600.0 / .pi

    /// J2000.0 元期 (2000-01-01 12:00:00 UTC) の UNIX 時刻 [秒]
    ///
    /// 厳密な J2000.0 は TT (地球時) 基準で、UTC との差 ΔT ≈ 69 秒ある。
    /// これは惑星の平均黄経にすると水星でも 0.12″ 程度で、
    /// 本シミュレーターが依拠する低精度軌道要素の誤差 (数分角) に比べて無視できる。
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

    /// 角度 [度] を 0〜360 の範囲へ畳む
    static func normalizeDegrees(_ deg: Double) -> Double {
        var d = deg.truncatingRemainder(dividingBy: 360.0)
        if d < 0 { d += 360.0 }
        return d
    }

    /// 角度 [度] を (-180, 180] の範囲へ畳む
    static func normalizeDegreesSigned(_ deg: Double) -> Double {
        var d = normalizeDegrees(deg)
        if d > 180.0 { d -= 360.0 }
        return d
    }

    /// ケプラー方程式 M = E - e·sin(E) を E について解く (ラジアン)
    ///
    /// ニュートン・ラフソン法。離心率 e < 0.6 程度なら数回で収束する。
    /// 許容誤差 1e-12 rad ≈ 2e-7 秒角。
    static func solveKepler(M: Double, e: Double) -> Double {
        var E = M + e * sin(M) // 一次近似を初期値にして反復回数を減らす
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

    /// 時刻 T (J2000 からのユリウス世紀) における平均近点角 [度]。
    /// 木星以遠では JPL Table 2b の補正項を加える。
    private static func meanAnomalyDegrees(elements el: OrbitalElements, T: Double) -> Double {
        let L_t = el.L + el.LRate * T
        let pi_t = el.longPeri + el.longPeriRate * T
        var M = L_t - pi_t

        if el.b != 0.0 || el.c != 0.0 || el.s != 0.0 {
            let fT_rad = deg2rad(el.f * T)
            M += el.b * T * T + el.c * cos(fT_rad) + el.s * sin(fT_rad)
        }
        return M
    }

    /// 軌道面 → 黄道面の変換に使う三角関数値をまとめた内部構造体
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

        // ω = ϖ - Ω (昇交点から測った近日点引数)
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

    /// 軌道面上の (x', y') を回転行列で黄道座標 (x, y, z) に変換する
    ///
    /// P・Q ベクトル (Murray & Dermott, Solar System Dynamics, eq. 2.122)
    private static func eclipticXYZ(frame f: OrbitalFrame, xPrime: Double, yPrime: Double) -> Vector3 {
        let Px =  f.cw * f.cn - f.sw * f.sn * f.ci
        let Py =  f.cw * f.sn + f.sw * f.cn * f.ci
        let Pz =  f.sw * f.si
        let Qx = -f.sw * f.cn - f.cw * f.sn * f.ci
        let Qy = -f.sw * f.sn + f.cw * f.cn * f.ci
        let Qz =  f.cw * f.si

        return Vector3(
            x: Px * xPrime + Qx * yPrime,
            y: Py * xPrime + Qy * yPrime,
            z: Pz * xPrime + Qz * yPrime
        )
    }

    /// 指定時刻における天体の太陽中心黄道座標 (x, y, z) [AU]
    ///
    /// 離角・位相角など「面外成分が効く量」はすべてこちらを使うこと。
    /// 俯瞰図の描画だけが `position(for:at:)` の 2D 射影で足りる。
    static func position3D(for body: CelestialBody, at date: Date) -> Vector3 {
        let T = julianCenturies(from: date)
        let el = body.elements
        let frame = makeFrame(elements: el, T: T)

        let M = deg2rad(normalizeDegrees(meanAnomalyDegrees(elements: el, T: T)))
        let E = solveKepler(M: M, e: frame.e)

        let xPrime = frame.a * (cos(E) - frame.e)
        let yPrime = frame.a * (1.0 - frame.e * frame.e).squareRoot() * sin(E)

        return eclipticXYZ(frame: frame, xPrime: xPrime, yPrime: yPrime)
    }

    /// 指定時刻における天体の黄道面への射影 (x, y) [AU] (俯瞰図の描画用)
    static func position(for body: CelestialBody, at date: Date) -> CGPoint {
        let v = position3D(for: body, at: date)
        return CGPoint(x: v.x, y: v.y)
    }

    /// 軌道を描画するためのポイント列。短期間では軌道形はほぼ不変なので、
    /// 指定日の要素で楕円を 1 周分サンプリングする
    static func orbitPoints(for body: CelestialBody, at date: Date = Date(), segments: Int = 360) -> [CGPoint] {
        let T = julianCenturies(from: date)
        let frame = makeFrame(elements: body.elements, T: T)

        var points: [CGPoint] = []
        points.reserveCapacity(segments + 1)

        for i in 0...segments {
            let E = Double(i) / Double(segments) * 2.0 * .pi
            let xPrime = frame.a * (cos(E) - frame.e)
            let yPrime = frame.a * (1.0 - frame.e * frame.e).squareRoot() * sin(E)
            let v = eclipticXYZ(frame: frame, xPrime: xPrime, yPrime: yPrime)
            points.append(CGPoint(x: v.x, y: v.y))
        }
        return points
    }
}
