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

    /// 円盤の大きさを決める基準の視直径 [秒角]。
    ///
    /// 水星と金星で同じ値を使うことで、両者の視直径を直接見比べられるようにする。
    /// 金星の最大視直径 (約 66″) を円盤の最大サイズに対応させる。
    var referenceArcsec: Double = 66.0

    /// 円盤が小さくなりすぎて満ち欠けが読めなくなる下限の半径 [pt]。
    /// これを下回るときは拡大して描き、倍率を図中に明記する。
    private let minimumLegibleRadius: CGFloat = 13.0

    override var isFlipped: Bool { return true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.06, alpha: 1.0).setFill()
        let bg = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        bg.fill()

        guard let s = status else { return }

        let center = NSPoint(x: bounds.midX, y: bounds.midY - 4)
        let maxRadius = min(bounds.width, bounds.height) / 2.0 - 14.0

        // 水星と金星で共通の縮尺。水星 (4.5″〜13″) は金星 (9.7″〜66″) に比べて
        // ずっと小さく、そのまま描くと満ち欠けが判別できない。
        // その場合だけ拡大し、倍率を図中に書いて誤解を防ぐ。
        let trueRadius = maxRadius * CGFloat(s.apparentDiameterArcsec / referenceArcsec)
        let R: CGFloat
        let magnification: CGFloat
        if trueRadius < minimumLegibleRadius {
            R = minimumLegibleRadius
            magnification = minimumLegibleRadius / max(trueRadius, 0.001)
        } else {
            R = min(maxRadius, trueRadius)
            magnification = 1.0
        }

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

        drawScaleHint(magnification: magnification)
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

    /// 方位 (東が左・西が右) と、拡大している場合はその倍率を小さく添える
    private func drawScaleHint(magnification: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9.0),
            .foregroundColor: NSColor(calibratedWhite: 0.45, alpha: 1.0)
        ]
        ("東" as NSString).draw(at: NSPoint(x: 4, y: bounds.height / 2 - 10), withAttributes: attrs)
        ("西" as NSString).draw(at: NSPoint(x: bounds.width - 16, y: bounds.height / 2 - 10),
                               withAttributes: attrs)

        // 縮尺は水星・金星で共通。小さすぎて拡大したときだけ倍率を明記する。
        let note = magnification > 1.05
            ? String(format: "×%.0f 拡大", magnification)
            : "実スケール"
        let noteAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9.0),
            .foregroundColor: NSColor(calibratedWhite: 0.52, alpha: 1.0)
        ]
        let size = (note as NSString).size(withAttributes: noteAttrs)
        (note as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                                            y: bounds.height - size.height - 3),
                                withAttributes: noteAttrs)
    }
}
