import Cocoa

/// 内惑星 1 つ分の表示ブロック
///
/// 縦に「概形 → 数値 → 今後の現象」の順で積む。
private class InnerPlanetSection: NSView {
    let planet: CelestialBody

    let headerLabel = NSTextField(labelWithString: "")
    let diskView = PhaseDiskView()
    let statusLabel = NSTextField(labelWithString: "")
    let eventsHeaderLabel = NSTextField(labelWithString: "今後の現象（日本標準時・概算値）")
    let eventsLabel = NSTextField(labelWithString: "")

    // 各パーツの高さ
    private let headerHeight: CGFloat = 26
    private let diskHeight: CGFloat = 190
    private let statusHeight: CGFloat = 126
    private let eventsHeaderHeight: CGFloat = 24
    private let eventsHeight: CGFloat = 92

    /// このブロックを描くのに必要な高さ
    static let preferredHeight: CGFloat = 26 + 190 + 126 + 24 + 92 + 26

    override var isFlipped: Bool { return true }

    init(planet: CelestialBody) {
        self.planet = planet
        super.init(frame: .zero)

        headerLabel.stringValue = planet.name
        headerLabel.font = NSFont.boldSystemFont(ofSize: 17)
        headerLabel.textColor = NSColor(calibratedWhite: 0.08, alpha: 1.0)
        addSubview(headerLabel)

        diskView.planetColor = planet.color
        // 円盤が描画領域いっぱいになる視直径。その惑星の最大視直径より少し大きく取る。
        // (水星は最大 13″、金星は最大 66″)
        diskView.fullScaleArcsec = (planet.name == "金星") ? 68.0 : 14.0
        addSubview(diskView)

        configureBlockLabel(statusLabel, size: 13)
        addSubview(statusLabel)

        eventsHeaderLabel.font = NSFont.boldSystemFont(ofSize: 12)
        eventsHeaderLabel.textColor = NSColor(calibratedWhite: 0.30, alpha: 1.0)
        addSubview(eventsHeaderLabel)

        configureBlockLabel(eventsLabel, size: 13)
        addSubview(eventsLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) は未対応です")
    }

    private func configureBlockLabel(_ label: NSTextField, size: CGFloat) {
        label.font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
        label.textColor = NSColor(calibratedWhite: 0.14, alpha: 1.0)
        label.usesSingleLineMode = false
        label.lineBreakMode = .byWordWrapping
        label.cell?.wraps = true
        label.cell?.isScrollable = false
    }

    // Auto Layout に依存せず、どの macOS でも確実に呼ばれる経路で再配置する
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutContents()
    }

    func layoutContents() {
        let w = bounds.width
        let inset: CGFloat = 14
        var y: CGFloat = 6

        headerLabel.frame = NSRect(x: inset, y: y, width: w - inset * 2, height: headerHeight)
        y += headerHeight

        diskView.frame = NSRect(x: inset, y: y, width: w - inset * 2, height: diskHeight)
        y += diskHeight + 10

        statusLabel.frame = NSRect(x: inset, y: y, width: w - inset * 2, height: statusHeight)
        y += statusHeight

        eventsHeaderLabel.frame = NSRect(x: inset, y: y, width: w - inset * 2,
                                         height: eventsHeaderHeight)
        y += eventsHeaderHeight

        eventsLabel.frame = NSRect(x: inset, y: y, width: w - inset * 2, height: eventsHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        // ブロック下端の区切り線
        NSColor(calibratedWhite: 0.78, alpha: 1.0).setStroke()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 14, y: bounds.height - 0.5))
        line.line(to: NSPoint(x: bounds.width - 14, y: bounds.height - 0.5))
        line.lineWidth = 1.0
        line.stroke()
    }

    /// 現在の状態を反映する
    func apply(status: InnerPlanetStatus) {
        diskView.status = status
        statusLabel.stringValue = [
            String(format: "離　　角　  %.2f°（%@）", status.elongationDeg, status.directionLabel),
            String(format: "視 直 径　  %.1f″", status.apparentDiameterArcsec),
            String(format: "輝 面 比　  %.3f　%@", status.illuminatedFraction, status.phaseName),
            String(format: "位 相 角　  %.1f°", status.phaseAngleDeg),
            String(format: "地心距離　  %.4f au", status.geocentricDistanceAU),
            String(format: "日心距離　  %.4f au", status.heliocentricDistanceAU)
        ].joined(separator: "\n")
    }

    /// 今後の現象を反映する
    func apply(events: [InnerPlanetEvent], formatter: DateFormatter) {
        if events.isEmpty {
            eventsLabel.stringValue = "　（探索範囲内に該当なし）"
            return
        }
        var lines: [String] = []
        for e in events {
            let stamp = formatter.string(from: e.date)
            switch e.kind {
            case .greatestEasternElongation, .greatestWesternElongation:
                lines.append(String(format: "%@ %@  %.1f°",
                                    padded(e.kind.label, to: 6), stamp, e.elongationDeg))
            case .inferiorConjunction, .superiorConjunction:
                lines.append(String(format: "%@ %@",
                                    padded(e.kind.label, to: 6), stamp))
            }
        }
        eventsLabel.stringValue = lines.joined(separator: "\n")
    }

    /// 全角文字数を揃えるための簡易パディング
    private func padded(_ s: String, to width: Int) -> String {
        let need = max(0, width - s.count)
        return s + String(repeating: "　", count: need)
    }
}

/// 内惑星 (水星・金星) の見え方を示すサイドパネル
///
/// 「水星の概形 → 数値 → 今後の現象 → 金星の概形 → 数値 → 今後の現象」
/// の順に縦へ積む。全体はスクロールビューに収める。
class InnerPlanetPanel: NSView {

    /// パネルの標準幅
    static let preferredWidth: CGFloat = 380

    private var sections: [InnerPlanetSection] = []
    private let noticeLabel = NSTextField(labelWithString: "")

    /// 現象時刻の再計算を間引くための最終計算時刻 (実時間)
    private var lastEventComputeTime: TimeInterval = -.infinity
    /// 現象時刻を再計算した対象日時
    private var lastEventBaseDate: Date?

    /// 現象探索は 3000 点規模の位置計算を伴うので、
    /// 再生中に毎フレーム走らせないよう実時間で間引く
    private let eventRecomputeInterval: TimeInterval = 0.25

    private let noticeHeight: CGFloat = 108

    private let jstFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        // 低精度軌道要素に由来する誤差が数時間あるため秒は出さない
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    override var isFlipped: Bool { return true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        for planet in NASAElements.innerPlanets {
            let section = InnerPlanetSection(planet: planet)
            addSubview(section)
            sections.append(section)
        }

        noticeLabel.font = NSFont.systemFont(ofSize: 11)
        noticeLabel.textColor = NSColor(calibratedWhite: 0.42, alpha: 1.0)
        noticeLabel.usesSingleLineMode = false
        noticeLabel.lineBreakMode = .byWordWrapping
        noticeLabel.cell?.wraps = true
        noticeLabel.stringValue =
            "概形は「天の北が上・東が左」の星図の向きで描画し、明縁は常に太陽の方向を向く。"
            + "円盤の下の物差しは円盤と同じ縮尺の角度スケールで、視直径を直接読み取れる。"
            + "水星と金星は縮尺が異なるので、両者を比べるときもこの物差しを基準にすること。\n"
            + "位置計算は JPL の低精度軌道要素によるため、現象時刻には数時間程度の"
            + "誤差がある。光行差・光路時間・大気差の補正は行っていない。"
        addSubview(noticeLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) は未対応です")
    }

    /// スクロールビューに入れるための必要高さ
    var preferredHeight: CGFloat {
        return CGFloat(sections.count) * InnerPlanetSection.preferredHeight + noticeHeight + 20
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.98, alpha: 1.0).setFill()
        NSBezierPath(rect: bounds).fill()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutContents()
    }

    func layoutContents() {
        var y: CGFloat = 8
        for section in sections {
            section.frame = NSRect(x: 0, y: y,
                                   width: bounds.width,
                                   height: InnerPlanetSection.preferredHeight)
            section.layoutContents()
            y += InnerPlanetSection.preferredHeight
        }
        noticeLabel.frame = NSRect(x: 14, y: y + 8, width: bounds.width - 28, height: noticeHeight)
    }

    /// 表示を指定日時の内容に更新する
    ///
    /// - Parameter force: 現象時刻の間引きを無視して必ず再計算する
    func update(date: Date, force: Bool = false) {
        for section in sections {
            section.apply(status: InnerPlanetPhenomena.status(for: section.planet, at: date))
        }

        let now = Date().timeIntervalSince1970
        let dueByTime = now - lastEventComputeTime >= eventRecomputeInterval
        let dateMoved = lastEventBaseDate.map { abs($0.timeIntervalSince(date)) > 1.0 } ?? true
        guard force || (dueByTime && dateMoved) else { return }

        lastEventComputeTime = now
        lastEventBaseDate = date
        for section in sections {
            let events = InnerPlanetPhenomena.upcomingEvents(for: section.planet, from: date)
            section.apply(events: events, formatter: jstFormatter)
        }
    }
}
