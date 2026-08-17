import Cocoa

private extension Notification.Name {
    static let updateControls = Notification.Name("UpdateControls")
}

class AppState {
    var date: Date = Date()
    var zoom: CGFloat = 0.1
    var pan: CGSize = .zero
    var rotation: CGFloat = 0.0
    var fixedBodyName: String? = nil
    var isPlaying = false
    var speed: Double = 1.0
}

class SolarSystemCanvas: NSView {
    var state: AppState!
    let baseAUSize: CGFloat = 100.0
    private var lastDragLocation: NSPoint?

    override var acceptsFirstResponder: Bool { return true }
    override var isFlipped: Bool { return true }

    private func screenPoint(au: CGPoint) -> CGPoint {
        return CGPoint(x: au.x * baseAUSize, y: -au.y * baseAUSize)
    }

    private func effectiveRotation() -> CGFloat {
        guard let fixedName = state.fixedBodyName,
              let fixedBody = NASAElements.planets.first(where: { $0.name == fixedName }) else {
            return state.rotation
        }

        let pos = OrbitalMechanics.position(for: fixedBody, at: state.date)
        let currentAngleOnScreen = atan2(-pos.y, pos.x)
        return CGFloat(Double.pi / 2.0 - currentAngleOnScreen)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

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

            let bodyRadius = max(2.0 / state.zoom, (8.0 * body.radiusMultiplier) / sqrt(state.zoom))
            body.color.setFill()
            let bodyRect = NSRect(x: p.x - bodyRadius, y: p.y - bodyRadius,
                                  width: bodyRadius * 2.0, height: bodyRadius * 2.0)
            NSBezierPath(ovalIn: bodyRect).fill()

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

    override func scrollWheel(with event: NSEvent) {
        state.pan.width += event.scrollingDeltaX
        state.pan.height += event.scrollingDeltaY
        needsDisplay = true
        requestControlUpdate()
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

    func hitTestForTarget(location: NSPoint) {
        let center = NSPoint(x: bounds.width / 2.0 + state.pan.width,
                             y: bounds.height / 2.0 + state.pan.height)
        let dx = location.x - center.x
        let dy = location.y - center.y

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

class MainContainerView: NSView {
    private let controlHeight: CGFloat = 110.0

    let appState = AppState()
    let canvas = SolarSystemCanvas()
    let controlPanel = ControlPanelView()

    let datePicker = NSDatePicker()
    let btnNow = NSButton(title: "現在", target: nil, action: nil)
    let btnMinusYear = NSButton(title: "-1年", target: nil, action: nil)
    let btnPlusYear = NSButton(title: "+1年", target: nil, action: nil)
    let btnToggle = NSButton(title: "▶", target: nil, action: nil)
    let sliderSpeed = NSSlider(value: 1.0, minValue: 0.1, maxValue: 100.0, target: nil, action: nil)
    let lblSpeed = NSTextField(labelWithString: "1 日/秒")

    let lblScale = NSTextField(labelWithString: "表示スケール:")
    let btnZoomOut = NSButton(title: "−", target: nil, action: nil)
    let sliderZoom = NSSlider(value: 0.1, minValue: 0.02, maxValue: 30.0, target: nil, action: nil)
    let btnZoomIn = NSButton(title: "+", target: nil, action: nil)
    let btnReset = NSButton(title: "視点リセット", target: nil, action: nil)

    let lockLabel = NSTextField(labelWithString: "")
    let btnUnlock = NSButton(title: "固定解除", target: nil, action: nil)

    var timer: Timer?

    override var isFlipped: Bool { return true }

    override init(frame: NSRect) {
        super.init(frame: frame)

        canvas.state = appState
        addSubview(canvas)
        addSubview(controlPanel)

        setupDateControls()
        setupPlaybackControls()
        setupViewControls()
        setupLockControls()

        NotificationCenter.default.addObserver(self, selector: #selector(updateControls), name: .updateControls, object: nil)
        timer = Timer.scheduledTimer(timeInterval: 1.0 / 60.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)

        layoutControls()
        updateControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) は未対応です")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }

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
    }

    private func setupViewControls() {
        configureLabel(lblScale)
        controlPanel.addSubview(lblScale)

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
        lockLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        lockLabel.textColor = NSColor(calibratedRed: 0.70, green: 0.08, blue: 0.07, alpha: 1.0)
        controlPanel.addSubview(lockLabel)
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutControls()
    }

    private func layoutControls() {
        let canvasHeight = max(0, bounds.height - controlHeight)
        canvas.frame = NSRect(x: 0, y: 0, width: bounds.width, height: canvasHeight)
        controlPanel.frame = NSRect(x: 0, y: canvasHeight, width: bounds.width, height: controlHeight)

        datePicker.frame = NSRect(x: 20, y: 16, width: 230, height: 26)
        btnNow.frame = NSRect(x: 260, y: 14, width: 62, height: 30)
        btnMinusYear.frame = NSRect(x: 328, y: 14, width: 62, height: 30)
        btnPlusYear.frame = NSRect(x: 396, y: 14, width: 62, height: 30)
        btnToggle.frame = NSRect(x: 472, y: 14, width: 46, height: 30)
        sliderSpeed.frame = NSRect(x: 532, y: 17, width: 150, height: 25)
        lblSpeed.frame = NSRect(x: 690, y: 20, width: 90, height: 20)

        lblScale.frame = NSRect(x: 20, y: 66, width: 95, height: 20)
        btnZoomOut.frame = NSRect(x: 120, y: 61, width: 40, height: 30)
        sliderZoom.frame = NSRect(x: 170, y: 65, width: min(270, max(170, bounds.width - 570)), height: 25)
        btnZoomIn.frame = NSRect(x: sliderZoom.frame.maxX + 8, y: 61, width: 40, height: 30)
        btnReset.frame = NSRect(x: btnZoomIn.frame.maxX + 12, y: 61, width: 110, height: 30)

        let unlockX = max(btnReset.frame.maxX + 14, bounds.width - 112)
        lockLabel.frame = NSRect(x: btnReset.frame.maxX + 14, y: 67, width: max(120, unlockX - btnReset.frame.maxX - 22), height: 20)
        btnUnlock.frame = NSRect(x: unlockX, y: 61, width: 90, height: 30)
    }

    @objc func dateChanged() {
        appState.date = datePicker.dateValue
        canvas.needsDisplay = true
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

    @objc func tick() {
        if appState.isPlaying {
            appState.date = appState.date.addingTimeInterval(86400.0 * (appState.speed / 60.0))
            datePicker.dateValue = appState.date
            canvas.needsDisplay = true
        }
    }

    @objc func updateControls() {
        sliderZoom.doubleValue = Double(appState.zoom)
        sliderSpeed.doubleValue = appState.speed
        lblSpeed.stringValue = "\(Int(appState.speed)) 日/秒"

        if let fixedName = appState.fixedBodyName {
            lockLabel.stringValue = "\(fixedName) を真下に固定中"
            btnUnlock.isHidden = false
        } else {
            lockLabel.stringValue = ""
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
        appMenu.addItem(NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = menu

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "太陽系シミュレーター"
        window.minSize = NSSize(width: 780, height: 520)
        window.center()

        let container = MainContainerView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(container.canvas)
        NSApp.activate(ignoringOtherApps: true)
    }
}
