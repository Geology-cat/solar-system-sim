import SwiftUI

/// 太陽系の俯瞰描画ビュー
///
/// 座標系:
///   - OrbitalMechanics.position() は J2000.0 黄道座標 (x: 春分点方向, y: 黄経 +90°方向)
///     を返す。これは「北黄極側から見下ろした」状態 = 公転は反時計回り
///   - Canvas は Y 軸が下向きなので、そのまま描くと公転方向が画面上で反時計回りに
///     見えない (時計回りに反転する)。
///     → 描画時に y を反転し、北黄極側から見下ろした天文慣例 (例: stdkmd.net/ssg/) に
///       一致させる
struct SolarSystemCanvas: View {
    let date: Date
    let bodies: [CelestialBody] = NASAElements.planets

    @Binding var zoom: CGFloat
    @Binding var pan: CGSize
    @Binding var rotation: Angle
    @Binding var fixedBodyName: String?

    // 1 AU を画面上の何ポイントにするか
    let baseAUSize: CGFloat = 100.0

    /// 黄道座標 (AU) を Canvas のローカル座標 (ポイント) に変換 (y を反転)
    private func screenPoint(au: CGPoint) -> CGPoint {
        return CGPoint(x: au.x * baseAUSize, y: -au.y * baseAUSize)
    }

    var body: some View {
        Canvas { context, size in
            // 中心を画面中央へ
            context.translateBy(x: size.width / 2 + pan.width, y: size.height / 2 + pan.height)

            // 天体固定モード: 注目天体を画面真下に向ける
            var effectiveRotation = rotation
            if let fixedName = fixedBodyName,
               let fixedBody = bodies.first(where: { $0.name == fixedName }) {
                let pos = OrbitalMechanics.position(for: fixedBody, at: date)
                // 描画系の真下は (0, +1) (Canvas 座標)。 y 反転後の天体方向は atan2(-pos.y, pos.x)
                let currentAngleOnScreen = atan2(-pos.y, pos.x)
                effectiveRotation = Angle(radians: .pi / 2 - currentAngleOnScreen)
            }
            context.rotate(by: effectiveRotation)

            // ズーム
            context.scaleBy(x: zoom, y: zoom)

            // 太陽
            let sunRadius: CGFloat = 10.0 / zoom
            let sunRect = CGRect(x: -sunRadius, y: -sunRadius, width: sunRadius * 2, height: sunRadius * 2)
            context.fill(Path(ellipseIn: sunRect), with: .color(.yellow))

            for celestialBody in bodies {
                // 現在位置 (Canvas 座標)
                let auPoint = OrbitalMechanics.position(for: celestialBody, at: date)
                let p = screenPoint(au: auPoint)

                // 軌道
                let orbitAU = OrbitalMechanics.orbitPoints(for: celestialBody, at: date)
                var path = Path()
                if let first = orbitAU.first {
                    path.move(to: screenPoint(au: first))
                    for au in orbitAU.dropFirst() {
                        path.addLine(to: screenPoint(au: au))
                    }
                    path.closeSubpath()
                }
                context.stroke(path, with: .color(.gray.opacity(0.4)), lineWidth: 1.0 / zoom)

                // 惑星本体
                let bodyRadius = max(2.0 / zoom, (8.0 * celestialBody.radiusMultiplier) / sqrt(zoom))
                let bodyRect = CGRect(x: p.x - bodyRadius, y: p.y - bodyRadius,
                                      width: bodyRadius * 2, height: bodyRadius * 2)
                context.fill(Path(ellipseIn: bodyRect), with: .color(celestialBody.color))

                // 天体名 (ズームに依らず一定サイズ、回転も打ち消す)
                let fontSize = 16.0 / zoom
                let text = context.resolve(
                    Text(celestialBody.name)
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundColor(.white)
                )
                var textContext = context
                textContext.translateBy(x: p.x, y: p.y + bodyRadius + (16.0 / zoom))
                textContext.rotate(by: -effectiveRotation)
                textContext.draw(text, at: .zero)
            }
        }
        .background(Color.black)
    }
}
