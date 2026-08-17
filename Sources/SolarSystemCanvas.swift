import Cocoa

/// アプリ全体で共有する表示状態
class AppState {
    var date: Date = Date()
    var zoom: CGFloat = 0.1
    var pan: CGSize = .zero
    var rotation: CGFloat = 0.0
    var fixedBodyName: String? = nil
    var isPlaying = false
    var speed: Double = 1.0
    var showsInnerPlanetPanel = true
}

extension Notification.Name {
    /// キャンバス側の操作をコントロールパネルへ知らせる
    static let updateControls = Notification.Name("UpdateControls")
}

/// 太陽系の俯瞰描画ビュー
///
/// 座標系:
///   - `OrbitalMechanics.position()` は J2000.0 黄道座標
///     (x: 春分点方向、y: 黄経 +90° 方向) を返す。
///     これは北黄極側から見下ろした状態で、公転は反時計回りになる。
///   - このビューは isFlipped = true (Y 軸下向き) なので、描画時に y を反転して
///     北黄極側から見下ろした天文慣例に一致させる。
class SolarSystemCanvas: NSView {
    var state: AppState!
    let baseAUSize: CGFloat = 100.0
    private var lastDragLocation: NSPoint?

    override var acceptsFirstResponder: Bool { return true }
    override var isFlipped: Bool { return true }

    private func screenPoint(au: CGPoint) -> CGPoint {
        return CGPoint(x: au.x * baseAUSize, y: -au.y * baseAUSize)
    }

    /// 天体固定モードのときは、注目天体が画面真下に来る回転角を返す
    private func effectiveRotation() -> CGFloat {
        guard let fixedName = state.fixedBodyName,
              let fixedBody = NASAElements.body(named: fixedName) else {
            return state.rotation
        }

        let pos = OrbitalMechanics.position(for: fixedBody, at: state.date)
        let currentAngleOnScreen = atan2(-pos.y, pos.x)
        return CGFloat(Double.pi / 2.0 - currentAngleOnScreen)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        guard NSGraphicsContext.current?.cgContext != nil else { return }
        let ctx = NSGraphicsContext.current!.cgContext

        ctx.translateBy(x: bounds.width / 2.0 + state.pan.width,
                        y: bounds.height / 2.0 + state.pan.height)

        let rotation = effectiveRotation()
        ctx.rotate(by: rotation)
        ctx.scaleBy(x: state.zoom, y: state.zoom)

        NSColor.yellow.setFill()
        let sunRadius: CGFloat = 10.0 / state.zoom
        let sunRect = NSRect(x: -sunRadius, y: -sunRadius,
                             width: sunRadius * 2.0, height: sunRadius * 2.0)
        NSBezierPath(ovalIn: sunRect).fill()

        for body in NASAElements.planets {
            let auPoint = OrbitalMechanics.position(for: body, at: state.date)
            let p = screenPoint(au: auPoint)

            // 軌道
            let orbitPoints = OrbitalMechanics.orbitPoints(for: body, at: state.date)
            let path = NSBezierPath()
            if let first = orbitPoints.first {
                let firstPoint = screenPoint(au: first)
                path.move(to: NSPoint(x: firstPoint.x, y: firstPoint.y))
                for au in orbitPoints.dropFirst() {
                    let point = screenPoint(au: au)
                    path.line(to: NSPoint(x: point.x, y: point.y))
                }
                path.close()
            }
            NSColor(white: 0.5, alpha: 0.4).setStroke()
            path.lineWidth = 1.0 / state.zoom
            path.stroke()

            // 惑星本体
            let bodyRadius = max(2.0 / state.zoom, (8.0 * body.radiusMultiplier) / sqrt(state.zoom))
            body.color.setFill()
            let bodyRect = NSRect(x: p.x - bodyRadius, y: p.y - bodyRadius,
                                  width: bodyRadius * 2.0, height: bodyRadius * 2.0)
            NSBezierPath(ovalIn: bodyRect).fill()

            // 天体名 (ズームに依らず一定サイズ、回転も打ち消す)
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: p.x, yBy: p.y + bodyRadius + (16.0 / state.zoom))
            transform.rotate(byRadians: -rotation)
            transform.concat()

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16.0 / state.zoom, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
            let labelSize = (body.name as NSString).size(withAttributes: attrs)
            (body.name as NSString).draw(
                at: NSPoint(x: -labelSize.width / 2.0, y: -labelSize.height / 2.0),
                withAttributes: attrs
            )
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private func requestControlUpdate() {
        NotificationCenter.default.post(name: .updateControls, object: nil)
    }

    // MARK: - 視点操作

    /// マウスホイールでは視点を動かさない。
    ///
    /// ホイールの空回しで意図せず視点がずれるのを避けるため、意図的に何もしない。
    /// 視点の移動はドラッグ、拡大縮小はスライダーかピンチ操作で行う。
    override func scrollWheel(with event: NSEvent) {
        // 何もしない
    }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if event.clickCount == 2 {
            hitTestForTarget(location: loc)
        } else {
            lastDragLocation = loc
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if let last = lastDragLocation {
            state.pan.width += loc.x - last.x
            state.pan.height += loc.y - last.y
        }
        lastDragLocation = loc
        needsDisplay = true
        requestControlUpdate()
    }

    override func mouseUp(with event: NSEvent) {
        lastDragLocation = nil
    }

    override func magnify(with event: NSEvent) {
        state.zoom *= (1.0 + event.magnification)
        state.zoom = max(0.02, min(30.0, state.zoom))
        needsDisplay = true
        requestControlUpdate()
    }

    override func rotate(with event: NSEvent) {
        state.rotation -= CGFloat(event.rotation * .pi / 180.0)
        needsDisplay = true
        requestControlUpdate()
    }

    /// ダブルクリック位置から最寄りの天体を探して固定する
    func hitTestForTarget(location: NSPoint) {
        let center = NSPoint(x: bounds.width / 2.0 + state.pan.width,
                             y: bounds.height / 2.0 + state.pan.height)
        let dx = location.x - center.x
        let dy = location.y - center.y

        // 描画と逆の変換をたどって AU 座標へ戻す
        let rotation = effectiveRotation()
        let cosR = cos(-rotation)
        let sinR = sin(-rotation)
        let unrotatedX = dx * cosR - dy * sinR
        let unrotatedY = dx * sinR + dy * cosR

        let auX = (unrotatedX / state.zoom) / baseAUSize
        let auY = -(unrotatedY / state.zoom) / baseAUSize

        var closestBody: String?
        var minDistance: Double = .infinity
        for body in NASAElements.planets {
            let pos = OrbitalMechanics.position(for: body, at: state.date)
            let dist = hypot(pos.x - auX, pos.y - auY)
            // ズームしているほど判定を緻密にする
            let threshold = max(
                0.3 / state.zoom,
                (4.0 * body.radiusMultiplier) / sqrt(state.zoom) / baseAUSize * 3.0
            )

            if dist < threshold && dist < minDistance {
                minDistance = dist
                closestBody = body.name
            }
        }

        if let target = closestBody {
            state.fixedBodyName = target
            needsDisplay = true
            requestControlUpdate()
        }
    }
}
