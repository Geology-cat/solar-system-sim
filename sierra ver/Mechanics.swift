import Cocoa

/// 軌道力学の計算ユーティリティ
struct OrbitalMechanics {
    private static let j2000UnixTime: TimeInterval = 946728000

    static func julianCenturies(from date: Date) -> Double {
        let daysSinceJ2000 = (date.timeIntervalSince1970 - j2000UnixTime) / 86400.0
        return daysSinceJ2000 / 36525.0
    }

    static func deg2rad(_ deg: Double) -> Double {
        return deg * .pi / 180.0
    }

    static func normalizeDegrees(_ deg: Double) -> Double {
        var d = deg.truncatingRemainder(dividingBy: 360.0)
        if d < 0 { d += 360.0 }
        return d
    }

    static func solveKepler(M: Double, e: Double) -> Double {
        var E = M + e * sin(M)
        let tolerance = 1e-12
        for _ in 0..<60 {
            let f = E - e * sin(E) - M
            let fp = 1.0 - e * cos(E)
            let deltaE = f / fp
            E -= deltaE
            if abs(deltaE) < tolerance { break }
        }
        return E
    }

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

    private struct OrbitalFrame {
        let a: Double
        let e: Double
        let cw: Double
        let sw: Double
        let cn: Double
        let sn: Double
        let ci: Double
        let si: Double
    }

    private static func makeFrame(elements el: OrbitalElements, T: Double) -> OrbitalFrame {
        let a = el.a + el.aRate * T
        let e = el.e + el.eRate * T
        let I = el.I + el.IRate * T
        let longPeri = el.longPeri + el.longPeriRate * T
        let longNode = el.longNode + el.longNodeRate * T

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

    private static func eclipticXY(frame f: OrbitalFrame, xPrime: Double, yPrime: Double) -> CGPoint {
        let Px = f.cw * f.cn - f.sw * f.sn * f.ci
        let Py = f.cw * f.sn + f.sw * f.cn * f.ci
        let Qx = -f.sw * f.cn - f.cw * f.sn * f.ci
        let Qy = -f.sw * f.sn + f.cw * f.cn * f.ci

        let x = Px * xPrime + Qx * yPrime
        let y = Py * xPrime + Qy * yPrime
        return CGPoint(x: x, y: y)
    }

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
