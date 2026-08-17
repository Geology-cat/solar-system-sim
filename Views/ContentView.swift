import SwiftUI

struct ContentView: View {
    @State private var targetDate: Date = Date()
    
    // ジェスチャー・視点操作用の状態
    // 初期ズーム 0.1: baseAUSize 100pt/AU × 0.1 = 10pt/AU で
    // 冥王星 (約 40 AU) まで全体が画面に収まる
    @State private var zoom: CGFloat = 0.1
    @State private var lastZoom: CGFloat = 0.1
    @State private var pan: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    @State private var rotation: Angle = .zero
    @State private var lastRotation: Angle = .zero
    
    // 天体固定モード
    @State private var fixedBodyName: String? = nil
    
    // アニメーション再生用
    @State private var isPlaying = false
    @State private var simulationSpeed: Double = 1.0 // 1秒 = x日進む
    let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                SolarSystemCanvas(date: targetDate, zoom: $zoom, pan: $pan, rotation: $rotation, fixedBodyName: $fixedBodyName)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                pan = CGSize(
                                    width: lastPan.width + value.translation.width,
                                    height: lastPan.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastPan = pan
                            }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                zoom = lastZoom * value
                            }
                            .onEnded { _ in
                                lastZoom = zoom
                            }
                    )
                    .simultaneousGesture(
                        RotationGesture()
                            .onChanged { value in
                                rotation = lastRotation + value
                            }
                            .onEnded { _ in
                                lastRotation = rotation
                            }
                    )
                    .onTapGesture(count: 2, coordinateSpace: .local) { location in
                        hitTestForTarget(location: location, size: geo.size)
                    }
            }
            
            // コントロールパネル
            VStack {
                if let fixed = fixedBodyName {
                    HStack {
                        Image(systemName: "scope")
                        Text("\(fixed) を真下に固定中")
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: {
                            fixedBodyName = nil
                            rotation = .zero
                            lastRotation = .zero
                        }) {
                            Text("固定解除")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)
                }
                
                HStack {
                    DatePicker("シミュレーション日時", selection: $targetDate)
                        .datePickerStyle(.field)
                        .frame(width: 250)
                        
                    Button("現在") {
                        targetDate = Date()
                    }
                    Button("-1年") {
                        if let date = Calendar.current.date(byAdding: .year, value: -1, to: targetDate) { targetDate = date }
                    }
                    Button("+1年") {
                        if let date = Calendar.current.date(byAdding: .year, value: 1, to: targetDate) { targetDate = date }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        isPlaying.toggle()
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title)
                            .foregroundColor(isPlaying ? .red : .blue)
                    }
                    .buttonStyle(.plain)
                    
                    Text("速さ:")
                    Slider(value: $simulationSpeed, in: 0.1...100.0)
                        .frame(width: 150)
                    Text("\(Int(simulationSpeed)) 日/秒")
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.top, fixedBodyName == nil ? 10 : 4)
                
                HStack {
                    Text("表示スケール:")
                    
                    Button(action: {
                        withAnimation {
                            zoom = max(0.02, zoom / 1.5)
                            lastZoom = zoom
                        }
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    
                    Slider(value: Binding(
                        get: { self.zoom },
                        set: {
                            self.zoom = $0
                            self.lastZoom = $0
                        }
                    ), in: 0.02...30.0)
                    
                    Button(action: {
                        withAnimation {
                            zoom = min(30.0, zoom * 1.5)
                            lastZoom = zoom
                        }
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    
                    Button("視点リセット") {
                        withAnimation {
                            zoom = 0.1
                            lastZoom = 0.1
                            pan = .zero
                            lastPan = .zero
                            rotation = .zero
                            lastRotation = .zero
                            fixedBodyName = nil
                        }
                    }
                }
                .padding(.bottom)
            }
            .padding(.horizontal)
            .background(.ultraThinMaterial)
        }
        .onReceive(timer) { _ in
            if isPlaying {
                // 1フレームあたり (simulationSpeed / 60) 日分進める
                targetDate = targetDate.addingTimeInterval(86400.0 * (simulationSpeed / 60.0))
            }
        }
        .edgesIgnoringSafeArea(.top)
    }
    
    // ダブルクリックした位置から最寄りの天体を探して固定する
    private func hitTestForTarget(location: CGPoint, size: CGSize) {
        let baseAUSize: Double = 100.0 // SolarSystemCanvas と一致させる
        let center = CGPoint(x: size.width / 2 + pan.width, y: size.height / 2 + pan.height)
        let dx = location.x - center.x
        let dy = location.y - center.y

        // Canvas での描画と同様、Y 軸を反転した画面座標上で固定天体の方向を計算
        var effectiveRotation = rotation
        if let fixedName = fixedBodyName,
           let b = NASAElements.planets.first(where: { $0.name == fixedName }) {
            let pos = OrbitalMechanics.position(for: b, at: targetDate)
            let currentAngleOnScreen = atan2(-pos.y, pos.x)
            effectiveRotation = Angle(radians: .pi / 2 - currentAngleOnScreen)
        }

        // 逆回転
        let cosR = cos(-effectiveRotation.radians)
        let sinR = sin(-effectiveRotation.radians)
        let unrotatedX = dx * cosR - dy * sinR
        let unrotatedY = dx * sinR + dy * cosR

        // ズーム解除 → Y 反転を取り消して天文標準の AU 座標へ
        let auX = (unrotatedX / zoom) / baseAUSize
        let auY = -(unrotatedY / zoom) / baseAUSize

        var closestBody: String? = nil
        var minDistance: Double = .infinity
        for body in NASAElements.planets {
            let pos = OrbitalMechanics.position(for: body, at: targetDate)
            let dist = hypot(pos.x - auX, pos.y - auY)

            // 当たり判定 (ズームしているほど狭く・判定を緻密に)
            let threshold = max(0.3 / zoom, (4.0 * body.radiusMultiplier) / sqrt(zoom) / baseAUSize * 3)

            if dist < threshold && dist < minDistance {
                minDistance = dist
                closestBody = body.name
            }
        }

        if let target = closestBody {
            withAnimation {
                fixedBodyName = target
            }
        }
    }
}
