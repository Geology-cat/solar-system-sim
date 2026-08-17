import Cocoa

/// 内惑星の概形 (満ち欠け) を描くビュー
///
/// 描画の規約:
///   星図の慣例にならい「天の北が上、東が左」に取る。すなわち黄経は
///   左向きに増える。したがって
///     東方離角 (Δλ > 0, 夕方の空) → 太陽は惑星より西 = 画面右 → 明縁は右
///     西方離角 (Δλ < 0, 明け方の空) → 明縁は左
///   明縁は常に太陽の方向を向く。
///
/// 形状の幾何:
///   半径 R の円盤のうち、明縁側の半円と、
///   x 半軸 R·cos(i)、y 半軸 R の半楕円 (欠け際 = ターミネータ) で囲まれた領域が
///   輝いて見える。位相角 i が 90° を超えると cos(i) < 0 となり、
///   ターミネータが明縁側へ回り込んで自動的に三日月形になる。
///   この領域の面積は πR²(1 + cos i)/2 で、輝面比 k = (1 + cos i)/2 と一致する。
class PhaseDiskView: NSView {

    /// 表示中の状態。nil のときは何も描かない。
    var status: InnerPlanetStatus? {
        didSet { needsDisplay = true }
    }

    /// 惑星の地色 (影の側もうっすらこの色で描く)
    var planetColor: NSColor = .orange {
        didSet { needsDisplay = true }
    }

    /// 視直径をこのビュー内でどう縮尺するか。
    /// 表示上の半径 = baseRadius × (視直径 / referenceArcsec) をクランプしたもの。
    var referenceArcsec: Double = 60.0

    override var isFlipped: Bool { return true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.06, alpha: 1.0).setFill()
        NSBezierPath(rect: bounds).fill()

        guard let s = status else { return }

        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let maxRadius = min(bounds.width, bounds.height) / 2.0 - 10.0

        // 視直径に比例させるが、小さすぎ / 大きすぎを避けるためクランプする。
        // (水星の視直径は 4.5″〜13″、金星は 9.7″〜66″ と大きく変わる)
        let scaled = maxRadius * (s.apparentDiameterArcsec / referenceArcsec)
        let R = max(6.0, min(maxRadius, scaled))

        // 影の側を含む円盤全体 (地色をごく暗く)
        planetColor.withAlphaComponent(0.16).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - R, y: center.y - R,
                                    width: R * 2, height: R * 2)).fill()

        // 輝いている領域
        let brightOnRight = s.isEastern
        planetColor.setFill()
        illuminatedPath(center: center, radius: R,
                        phaseAngleDeg: s.phaseAngleDeg,
                        brightOnRight: brightOnRight).fill()

        // 円盤の輪郭
        NSColor(calibratedWhite: 0.55, alpha: 1.0).setStroke()
        let outline = NSBezierPath(ovalIn: NSRect(x: center.x - R, y: center.y - R,
                                                  width: R * 2, height: R * 2))
        outline.lineWidth = 1.0
        outline.stroke()

        drawScaleHint(center: center, radius: R)
    }

    /// 輝面のパスを作る
    ///
    /// 明縁側の半円を θ ∈ [-90°, +90°] でたどり、
    /// 続いてターミネータの半楕円を逆向きにたどって閉じる。
    private func illuminatedPath(center: NSPoint, radius R: CGFloat,
                                 phaseAngleDeg: Double,
                                 brightOnRight: Bool) -> NSBezierPath {
        let cosPhase = CGFloat(cos(OrbitalMechanics.deg2rad(phaseAngleDeg)))
        // 明縁が左のときは x を反転させる
        let sign: CGFloat = brightOnRight ? 1.0 : -1.0

        let path = NSBezierPath()
        let segments = 180

        // 明縁 (半円): 上端 → 明縁側 → 下端
        for i in 0...segments {
            let t = -CGFloat.pi / 2 + CGFloat(i) / CGFloat(segments) * CGFloat.pi
            let p = NSPoint(x: center.x + sign * R * cos(t), y: center.y + R * sin(t))
            if i == 0 { path.move(to: p) } else { path.line(to: p) }
        }
        // ターミネータ (半楕円): 下端 → 中央寄り → 上端
        for i in 0...segments {
            let t = CGFloat.pi / 2 - CGFloat(i) / CGFloat(segments) * CGFloat.pi
            let p = NSPoint(x: center.x - sign * R * cosPhase * cos(t),
                            y: center.y + R * sin(t))
            path.line(to: p)
        }
        path.close()
        return path
    }

    /// 「東 ←」「→ 西」の向きを小さく添える
    private func drawScaleHint(center: NSPoint, radius R: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9.0),
            .foregroundColor: NSColor(calibratedWhite: 0.45, alpha: 1.0)
        ]
        ("東" as NSString).draw(at: NSPoint(x: 4, y: bounds.height / 2 - 6), withAttributes: attrs)
        ("西" as NSString).draw(at: NSPoint(x: bounds.width - 16, y: bounds.height / 2 - 6),
                               withAttributes: attrs)
    }
}
