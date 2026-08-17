import Cocoa

/// 下部コントロールパネルの背景
class ControlPanelView: NSView {
    override var isFlipped: Bool { return true }

    override func draw(_ dirtyRect: NSRect) {
        let background = NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1.0)
        background.setFill()
        NSBezierPath(rect: bounds).fill()

        let topLine = NSBezierPath()
        topLine.move(to: NSPoint(x: 0, y: 0.5))
        topLine.line(to: NSPoint(x: bounds.width, y: 0.5))
        NSColor(calibratedWhite: 0.62, alpha: 1.0).setStroke()
        topLine.lineWidth = 1.0
        topLine.stroke()
    }
}

/// ウインドウ全体のレイアウトとコントロールの取りまとめ
class MainContainerView: NSView {
    private let controlHeight: CGFloat = 122.0

    let appState = AppState()
    let canvas = SolarSystemCanvas()
    let controlPanel = ControlPanelView()

    // 内惑星サイドパネル (スクロール可能)
    let sidePanel = InnerPlanetPanel()
    let sideScrollView = NSScrollView()

    let datePicker = NSDatePicker()
    let btnNow = NSButton(title: "現在", target: nil, action: nil)
    let btnMinusYear = NSButton(title: "-1年", target: nil, action: nil)
    let btnPlusYear = NSButton(title: "+1年", target: nil, action: nil)
    let btnToggle = NSButton(title: "▶", target: nil, action: nil)
    let sliderSpeed = NSSlider(value: 1.0, minValue: 0.1, maxValue: 100.0, target: nil, action: nil)
    let lblSpeed = NSTextField(labelWithString: "1 日/秒")
    let btnSidePanel = NSButton(title: "内惑星パネル", target: nil, action: nil)

    let btnZoomOut = NSButton(title: "−", target: nil, action: nil)
    let sliderZoom = NSSlider(value: 0.1, minValue: 0.02, maxValue: 30.0, target: nil, action: nil)
    let btnZoomIn = NSButton(title: "+", target: nil, action: nil)
    let btnReset = NSButton(title: "視点リセット", target: nil, action: nil)

    let lockLabel = NSTextField(labelWithString: "（天体をダブルクリックで固定）")
    let btnUnlock = NSButton(title: "固定解除", target: nil, action: nil)

    // 各コントロールが何であるかを示す見出し
    let capDate = NSTextField(labelWithString: "シミュレーション日時")
    let capJump = NSTextField(labelWithString: "日時を動かす")
    let capPlay = NSTextField(labelWithString: "再生／停止")
    let capSpeed = NSTextField(labelWithString: "再生の速さ")
    let capPanel = NSTextField(labelWithString: "サイドパネル")
    let capScale = NSTextField(labelWithString: "表示スケール（拡大・縮小）")
    let capView = NSTextField(labelWithString: "視点")
    let capLock = NSTextField(labelWithString: "注目天体の固定")

    var timer: Timer?

    override var isFlipped: Bool { return true }

    override init(frame: NSRect) {
        super.init(frame: frame)

        canvas.state = appState
        addSubview(canvas)

        sideScrollView.hasVerticalScroller = true
        sideScrollView.hasHorizontalScroller = false
        sideScrollView.autohidesScrollers = true
        sideScrollView.borderType = .noBorder
        sideScrollView.drawsBackground = true
        sideScrollView.backgroundColor = NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        sideScrollView.documentView = sidePanel
        addSubview(sideScrollView)

        addSubview(controlPanel)

        setupCaptions()
        setupDateControls()
        setupPlaybackControls()
        setupViewControls()
        setupLockControls()

        NotificationCenter.default.addObserver(self, selector: #selector(updateControls),
                                               name: .updateControls, object: nil)
        timer = Timer.scheduledTimer(timeInterval: 1.0 / 60.0, target: self,
                                     selector: #selector(tick), userInfo: nil, repeats: true)

        layoutControls()
        updateControls()
        sidePanel.update(date: appState.date, force: true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) は未対応です")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }

    // MARK: - コントロールの生成

    /// macOS 10.14 以降のダークモードでもコントロールの見た目を揃える。
    /// (`NSAppearance.Name.aqua` は 10.14 で追加された定数なので、
    ///  10.12 でも通る生文字列から生成する)
    private func applyLightAppearance(_ view: NSView) {
        view.appearance = NSAppearance(named: NSAppearance.Name(rawValue: "NSAppearanceNameAqua"))
    }

    private func configureLabel(_ label: NSTextField) {
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.textColor = NSColor(calibratedWhite: 0.08, alpha: 1.0)
    }

    private func configureButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        applyLightAppearance(button)
    }

    private func setupDateControls() {
        datePicker.datePickerElements = [.yearMonthDay, .hourMinuteSecond]
        datePicker.dateValue = appState.date
        datePicker.target = self
        datePicker.action = #selector(dateChanged)
        datePicker.isBezeled = true
        datePicker.isBordered = true
        applyLightAppearance(datePicker)
        controlPanel.addSubview(datePicker)

        btnNow.target = self
        btnNow.action = #selector(doNow)
        btnMinusYear.target = self
        btnMinusYear.action = #selector(doMinusYear)
        btnPlusYear.target = self
        btnPlusYear.action = #selector(doPlusYear)
        for button in [btnNow, btnMinusYear, btnPlusYear] {
            configureButton(button)
            controlPanel.addSubview(button)
        }
    }

    private func setupPlaybackControls() {
        btnToggle.target = self
        btnToggle.action = #selector(togglePlay)
        configureButton(btnToggle)
        controlPanel.addSubview(btnToggle)

        sliderSpeed.target = self
        sliderSpeed.action = #selector(speedChanged)
        applyLightAppearance(sliderSpeed)
        controlPanel.addSubview(sliderSpeed)

        configureLabel(lblSpeed)
        lblSpeed.alignment = .right
        controlPanel.addSubview(lblSpeed)

        btnSidePanel.target = self
        btnSidePanel.action = #selector(toggleSidePanel)
        btnSidePanel.setButtonType(.pushOnPushOff)
        btnSidePanel.state = .on
        configureButton(btnSidePanel)
        controlPanel.addSubview(btnSidePanel)
    }

    /// コントロールの上に添える小さな見出し
    private func configureCaption(_ label: NSTextField) {
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.font = NSFont.systemFont(ofSize: 10)
        label.textColor = NSColor(calibratedWhite: 0.38, alpha: 1.0)
        controlPanel.addSubview(label)
    }

    private func setupCaptions() {
        for caption in [capDate, capJump, capPlay, capSpeed, capPanel,
                        capScale, capView, capLock] {
            configureCaption(caption)
        }
    }

    private func setupViewControls() {
        btnZoomOut.target = self
        btnZoomOut.action = #selector(zoomOut)
        btnZoomIn.target = self
        btnZoomIn.action = #selector(zoomIn)
        btnReset.target = self
        btnReset.action = #selector(resetView)
        sliderZoom.target = self
        sliderZoom.action = #selector(zoomChanged)
        configureButton(btnZoomOut)
        configureButton(btnZoomIn)
        configureButton(btnReset)
        applyLightAppearance(sliderZoom)
        for control in [btnZoomOut, sliderZoom, btnZoomIn, btnReset] as [NSView] {
            controlPanel.addSubview(control)
        }
    }

    private func setupLockControls() {
        btnUnlock.target = self
        btnUnlock.action = #selector(unlockTarget)
        configureButton(btnUnlock)
        controlPanel.addSubview(btnUnlock)

        configureLabel(lockLabel)
        lockLabel.font = NSFont.systemFont(ofSize: 11)
        lockLabel.textColor = NSColor(calibratedWhite: 0.45, alpha: 1.0)
        controlPanel.addSubview(lockLabel)
    }

    // MARK: - レイアウト

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutControls()
    }

    private func layoutControls() {
        let canvasHeight = max(0, bounds.height - controlHeight)
        let panelWidth = appState.showsInnerPlanetPanel ? InnerPlanetPanel.preferredWidth : 0
        // キャンバスが潰れないよう、狭いウインドウではパネル幅を譲る
        let effectivePanelWidth = min(panelWidth, max(0, bounds.width - 440))

        canvas.frame = NSRect(x: 0, y: 0,
                              width: bounds.width - effectivePanelWidth, height: canvasHeight)
        sideScrollView.isHidden = effectivePanelWidth <= 0
        sideScrollView.frame = NSRect(x: bounds.width - effectivePanelWidth, y: 0,
                                      width: effectivePanelWidth, height: canvasHeight)
        // ドキュメントビューはクリップ幅いっぱい・必要高さ分
        let docWidth = max(1, effectivePanelWidth - (sideScrollView.verticalScroller?.frame.width ?? 15))
        sidePanel.frame = NSRect(x: 0, y: 0, width: docWidth, height: sidePanel.preferredHeight)
        sidePanel.layoutContents()

        controlPanel.frame = NSRect(x: 0, y: canvasHeight, width: bounds.width, height: controlHeight)

        // --- 1 段目: 日時と再生 ---
        let capY1: CGFloat = 7
        let rowY1: CGFloat = 23

        capDate.frame = NSRect(x: 20, y: capY1, width: 220, height: 14)
        datePicker.frame = NSRect(x: 20, y: rowY1, width: 220, height: 26)

        capJump.frame = NSRect(x: 250, y: capY1, width: 180, height: 14)
        btnNow.frame = NSRect(x: 250, y: rowY1 - 2, width: 56, height: 30)
        btnMinusYear.frame = NSRect(x: 312, y: rowY1 - 2, width: 56, height: 30)
        btnPlusYear.frame = NSRect(x: 374, y: rowY1 - 2, width: 56, height: 30)

        capPlay.frame = NSRect(x: 444, y: capY1, width: 70, height: 14)
        btnToggle.frame = NSRect(x: 444, y: rowY1 - 2, width: 46, height: 30)

        capSpeed.frame = NSRect(x: 504, y: capY1, width: 220, height: 14)
        sliderSpeed.frame = NSRect(x: 504, y: rowY1 + 1, width: 140, height: 25)
        lblSpeed.frame = NSRect(x: 650, y: rowY1 + 4, width: 76, height: 20)

        let panelBtnX = max(748, bounds.width - 158)
        capPanel.frame = NSRect(x: panelBtnX, y: capY1, width: 140, height: 14)
        btnSidePanel.frame = NSRect(x: panelBtnX, y: rowY1 - 2, width: 140, height: 30)

        // --- 2 段目: 表示スケールと視点 ---
        let capY2: CGFloat = 66
        let rowY2: CGFloat = 82

        capScale.frame = NSRect(x: 20, y: capY2, width: 260, height: 14)
        btnZoomOut.frame = NSRect(x: 20, y: rowY2, width: 40, height: 28)
        let zoomWidth = min(260, max(150, bounds.width - 620))
        sliderZoom.frame = NSRect(x: 68, y: rowY2 + 2, width: zoomWidth, height: 25)
        btnZoomIn.frame = NSRect(x: sliderZoom.frame.maxX + 8, y: rowY2, width: 40, height: 28)

        let viewX = btnZoomIn.frame.maxX + 20
        capView.frame = NSRect(x: viewX, y: capY2, width: 120, height: 14)
        btnReset.frame = NSRect(x: viewX, y: rowY2, width: 110, height: 28)

        let lockX = btnReset.frame.maxX + 22
        let unlockX = max(lockX + 190, bounds.width - 100)
        capLock.frame = NSRect(x: lockX, y: capY2, width: 160, height: 14)
        lockLabel.frame = NSRect(x: lockX, y: rowY2 + 5,
                                 width: max(140, unlockX - lockX - 10), height: 18)
        btnUnlock.frame = NSRect(x: unlockX, y: rowY2, width: 88, height: 28)
    }

    // MARK: - アクション

    @objc func dateChanged() {
        appState.date = datePicker.dateValue
        canvas.needsDisplay = true
        sidePanel.update(date: appState.date, force: true)
    }

    @objc func doNow() {
        datePicker.dateValue = Date()
        dateChanged()
    }

    @objc func doMinusYear() {
        if let date = Calendar.current.date(byAdding: .year, value: -1, to: datePicker.dateValue) {
            datePicker.dateValue = date
            dateChanged()
        }
    }

    @objc func doPlusYear() {
        if let date = Calendar.current.date(byAdding: .year, value: 1, to: datePicker.dateValue) {
            datePicker.dateValue = date
            dateChanged()
        }
    }

    @objc func togglePlay() {
        appState.isPlaying.toggle()
        btnToggle.title = appState.isPlaying ? "⏸" : "▶"
    }

    @objc func speedChanged() {
        appState.speed = sliderSpeed.doubleValue
        lblSpeed.stringValue = "\(Int(appState.speed)) 日/秒"
    }

    @objc func zoomChanged() {
        appState.zoom = CGFloat(sliderZoom.doubleValue)
        canvas.needsDisplay = true
    }

    @objc func zoomOut() {
        appState.zoom = max(0.02, appState.zoom / 1.5)
        canvas.needsDisplay = true
        updateControls()
    }

    @objc func zoomIn() {
        appState.zoom = min(30.0, appState.zoom * 1.5)
        canvas.needsDisplay = true
        updateControls()
    }

    @objc func resetView() {
        appState.zoom = 0.1
        appState.pan = .zero
        appState.rotation = 0.0
        appState.fixedBodyName = nil
        canvas.needsDisplay = true
        updateControls()
    }

    @objc func unlockTarget() {
        appState.fixedBodyName = nil
        appState.rotation = 0.0
        canvas.needsDisplay = true
        updateControls()
    }

    @objc func toggleSidePanel() {
        appState.showsInnerPlanetPanel = (btnSidePanel.state == .on)
        layoutControls()
        needsDisplay = true
        if appState.showsInnerPlanetPanel {
            sidePanel.update(date: appState.date, force: true)
        }
    }

    @objc func tick() {
        if appState.isPlaying {
            appState.date = appState.date.addingTimeInterval(86400.0 * (appState.speed / 60.0))
            datePicker.dateValue = appState.date
            canvas.needsDisplay = true
            if appState.showsInnerPlanetPanel {
                sidePanel.update(date: appState.date)
            }
        }
    }

    @objc func updateControls() {
        sliderZoom.doubleValue = Double(appState.zoom)
        sliderSpeed.doubleValue = appState.speed
        lblSpeed.stringValue = "\(Int(appState.speed)) 日/秒"

        if let fixedName = appState.fixedBodyName {
            lockLabel.stringValue = "\(fixedName) を真下に固定中"
            lockLabel.textColor = NSColor(calibratedRed: 0.70, green: 0.08, blue: 0.07, alpha: 1.0)
            lockLabel.font = NSFont.boldSystemFont(ofSize: 12)
            btnUnlock.isHidden = false
        } else {
            lockLabel.stringValue = "（天体をダブルクリックで固定）"
            lockLabel.textColor = NSColor(calibratedWhite: 0.45, alpha: 1.0)
            lockLabel.font = NSFont.systemFont(ofSize: 11)
            btnUnlock.isHidden = true
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appMenuItem = NSMenuItem()
        menu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "終了",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = menu

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1320, height: 840),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "太陽系シミュレーター"
        window.minSize = NSSize(width: 1020, height: 600)
        window.center()

        let container = MainContainerView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(container.canvas)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
