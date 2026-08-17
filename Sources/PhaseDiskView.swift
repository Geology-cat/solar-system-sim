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
/// 縮尺の規約:
///   惑星ごとに「1 秒角あたり何ポイントか」を固定する。
///   したがって円盤の大きさは会合周期のなかで実際に伸び縮みし、
///   内合に近づくほど大きく描かれる。
///   絶対的な大きさは円盤の下に添えた角度スケール (物差し) で読む。
///   水星と金星は縮尺が異なるので、両者を見比べるときもこのスケールを使う。
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

    /// 円盤が描画領域いっぱいになる視直径 [秒角]。
    /// その惑星が取りうる最大の視直径より少し大きく取る。
    var fullScaleArcsec: Double = 68.0

    /// 角度スケールの刻みの候補 [秒角]
    private let tickCandidates: [Double] = [1, 2, 5, 10, 20, 30, 60, 120]

    /// スケール表示に使う下部の高さ
    private let scaleAreaHeight: CGFloat = 34.0

    override var isFlipped: Bool { return true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.06, alpha: 1.0).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()

        guard let s = status else { return }

        // 円盤を描ける領域 (下側はスケール用に空ける)
        let diskArea = NSRect(x: bounds.minX, y: bounds.minY,
                              width: bounds.width, height: bounds.height - scaleAreaHeight)
        let center = NSPoint(x: diskArea.midX, y: diskArea.midY)
        let maxRadius = min(diskArea.width, diskArea.height) / 2.0 - 12.0

        // 1 秒角あたりのポイント数。惑星ごとに固定なので、
        // 円盤の大きさがそのまま視直径の変化を表す。
        let pointsPerArcsec = maxRadius / CGFloat(fullScaleArcsec / 2.0)
        let R = max(3.0, CGFloat(s.apparentDiameterArcsec / 2.0) * pointsPerArcsec)

        // 影の側を含む円盤全体 (地色をごく暗く)
        planetColor.withAlphaComponent(0.16).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - R, y: center.y - R,
                                    width: R * 2, height: R * 2)).fill()

        // 輝いている領域
        planetColor.setFill()
        illuminatedPath(center: center, radius: R,
                        phaseAngleDeg: s.phaseAngleDeg,
                        brightOnRight: s.isEastern).fill()

        // 円盤の輪郭
        NSColor(calibratedWhite: 0.55, alpha: 1.0).setStroke()
        let outline = NSBezierPath(ovalIn: NSRect(x: center.x - R, y: center.y - R,
                                                  width: R * 2, height: R * 2))
        outline.lineWidth = 1.0
        outline.stroke()

        drawDirectionHints(diskArea: diskArea)
        drawAngularScale(pointsPerArcsec: pointsPerArcsec)
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
        let segments = 220

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

    /// 「東が左・西が右」の向きを小さく添える
    private func drawDirectionHints(diskArea: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11.0),
            .foregroundColor: NSColor(calibratedWhite: 0.48, alpha: 1.0)
        ]
        ("東" as NSString).draw(at: NSPoint(x: 8, y: diskArea.midY - 7), withAttributes: attrs)
        ("西" as NSString).draw(at: NSPoint(x: bounds.width - 22, y: diskArea.midY - 7),
                               withAttributes: attrs)
    }

    /// 円盤の下に角度の物差しを描く
    ///
    /// 円盤と同じ縮尺で描くので、物差しの長さと円盤の直径を見比べれば
    /// 視直径が直接読み取れる。水星と金星は縮尺が違うため、
    /// 両者を比較するときもこの物差しを基準にする。
    private func drawAngularScale(pointsPerArcsec: CGFloat) {
        // 描画幅のおよそ半分に収まる、いちばん大きい刻みを選ぶ
        let limit = bounds.width * 0.46
        var tick = tickCandidates.first ?? 1
        for candidate in tickCandidates {
            if CGFloat(candidate) * pointsPerArcsec <= limit { tick = candidate }
        }
        let barLength = CGFloat(tick) * pointsPerArcsec
        guard barLength > 8 else { return }

        let y = bounds.height - scaleAreaHeight + 13.0
        let x0 = (bounds.width - barLength) / 2.0
        let x1 = x0 + barLength

        let color = NSColor(calibratedWhite: 0.72, alpha: 1.0)
        color.setStroke()

        let bar = NSBezierPath()
        bar.move(to: NSPoint(x: x0, y: y))
        bar.line(to: NSPoint(x: x1, y: y))
        // 両端と中央の目盛
        bar.move(to: NSPoint(x: x0, y: y - 4)); bar.line(to: NSPoint(x: x0, y: y + 4))
        bar.move(to: NSPoint(x: x1, y: y - 4)); bar.line(to: NSPoint(x: x1, y: y + 4))
        bar.move(to: NSPoint(x: (x0 + x1) / 2, y: y - 2.5))
        bar.line(to: NSPoint(x: (x0 + x1) / 2, y: y + 2.5))
        bar.lineWidth = 1.0
        bar.stroke()

        let label = tick >= 1
            ? String(format: "%.0f″", tick)
            : String(format: "%.1f″", tick)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11.0, weight: .regular),
            .foregroundColor: color
        ]
        let size = (label as NSString).size(withAttributes: attrs)
        (label as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: y + 5),
                                 withAttributes: attrs)
    }
}
