import AppKit

@MainActor
final class PetController: NSObject, PetViewDelegate {
    private let settings: Settings
    private let window: PetWindow
    private let view: PetView
    private let animator = SpriteAnimator()
    private let machine = PetStateMachine()
    private let sound = SoundPlayer()

    private var timer: Timer?
    private var lastTick: TimeInterval = 0
    private var facing: Facing = .right
    private var velocityY: CGFloat = 0

    private var isPressing = false
    private var isDragging = false
    private var pressStart: NSPoint = .zero
    private var grabOffset: NSPoint = .zero

    private static let tickRate: TimeInterval = 1.0 / 30
    private static let baseWalkSpeed: CGFloat = 45
    private static let gravity: CGFloat = 2400
    private static let dragThreshold: CGFloat = 3
    private static let spontaneousMeowChance = 0.04
    private static let purrVolume: Float = 0.35

    var contextMenuProvider: (() -> NSMenu?)?

    private(set) var isVisible = false

    init(settings: Settings) {
        self.settings = settings
        let size = settings.size.points
        window = PetWindow(size: size)
        view = PetView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        super.init()

        view.autoresizingMask = [.width, .height]
        view.delegate = self
        window.contentView = view

        machine.allowWalking = !settings.stayStill
        sound.isEnabled = settings.soundEnabled
        sound.masterVolume = settings.soundVolume.level
        machine.onStateChange = { [weak self] old, new in
            self?.handleStateChange(from: old, to: new)
        }
        settings.onChange = { [weak self] in self?.applySettings() }
    }

    func previewSound() {
        sound.play(.meow)
    }

    private func handleStateChange(from old: PetState, to new: PetState) {
        switch new {
        case .walkLeft: facing = .left
        case .walkRight: facing = .right
        default: break
        }

        if old == .sleep { sound.stopLoop() }

        switch new {
        case .happy:
            sound.play(.meow)
        case .dragged:
            sound.play(.chirp, volume: 0.8)
        case .sleep:
            sound.startLoop(.purr, volume: Self.purrVolume)
        case .idle, .sit:
            if old != .falling, old != .sleep, Double.random(in: 0..<1) < Self.spontaneousMeowChance {
                sound.play(.meow, volume: 0.5)
            }
        default:
            break
        }
    }

    func start() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        if let bounds = screen?.visibleFrame {
            let size = window.frame.width
            let x = CGFloat.random(in: bounds.minX...(max(bounds.minX, bounds.maxX - size)))
            window.setFrameOrigin(NSPoint(x: x, y: bounds.minY))
        }
        setVisible(true)
    }

    func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        if visible {
            window.orderFrontRegardless()
            lastTick = ProcessInfo.processInfo.systemUptime
            let timer = Timer(timeInterval: Self.tickRate, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
            tick()
            if machine.state == .sleep { sound.startLoop(.purr, volume: Self.purrVolume) }
        } else {
            timer?.invalidate()
            timer = nil
            window.orderOut(nil)
            sound.stopLoop()
        }
    }

    private func applySettings() {
        machine.allowWalking = !settings.stayStill
        sound.isEnabled = settings.soundEnabled
        sound.masterVolume = settings.soundVolume.level
        if isVisible, machine.state == .sleep {
            sound.startLoop(.purr, volume: Self.purrVolume)
        }

        let size = settings.size.points
        var frame = window.frame
        guard frame.width != size else { return }
        let centerX = frame.midX
        frame.size = NSSize(width: size, height: size)
        frame.origin.x = centerX - size / 2
        window.setFrame(frame, display: true)
    }

    @objc private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(now - lastTick, 0.1)
        lastTick = now

        machine.tick(dt)
        updatePosition(dt)

        animator.play(machine.state.animationKey)
        animator.advance(by: dt)
        view.image = animator.currentFrame(facing: facing)

        updateMousePassThrough()
    }

    private func updatePosition(_ dt: TimeInterval) {
        guard machine.state != .dragged else { return }

        var frame = window.frame
        let bounds = currentScreen()?.visibleFrame ?? frame
        let ground = bounds.minY
        let dt = CGFloat(dt)

        switch machine.state {
        case .falling:
            velocityY -= Self.gravity * dt
            frame.origin.y += velocityY * dt
            if frame.origin.y <= ground {
                let impactSpeed = -velocityY
                frame.origin.y = ground
                velocityY = 0
                machine.land()
                sound.play(.thud, volume: Float(min(1, max(0.15, impactSpeed / 1500))))
            }
        case .walkLeft, .walkRight:
            let direction: CGFloat = machine.state == .walkLeft ? -1 : 1
            frame.origin.x += direction * walkSpeed * dt
        default:
            break
        }

        if machine.state != .falling {
            if frame.origin.y > ground + 1 {
                velocityY = 0
                machine.startFalling()
            } else {
                frame.origin.y = ground
            }
        }

        if frame.minX < bounds.minX {
            frame.origin.x = bounds.minX
            if machine.state == .walkLeft { machine.turnAround() }
        } else if frame.maxX > bounds.maxX {
            frame.origin.x = bounds.maxX - frame.width
            if machine.state == .walkRight { machine.turnAround() }
        }

        if frame.origin != window.frame.origin {
            window.setFrameOrigin(frame.origin)
        }
    }

    private var walkSpeed: CGFloat {
        Self.baseWalkSpeed * settings.speed.multiplier * (settings.size.points / PetSize.medium.points)
    }

    private func currentScreen() -> NSScreen? {
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// Transparent pixels must not swallow clicks meant for apps underneath, so the window only
    /// accepts mouse events while the cursor is over the pet itself.
    private func updateMousePassThrough() {
        let accepts: Bool
        if isPressing || machine.state == .dragged {
            accepts = true
        } else {
            let mouse = NSEvent.mouseLocation
            accepts = window.frame.contains(mouse) && view.isOpaque(atScreenPoint: mouse)
        }
        if window.ignoresMouseEvents == accepts {
            window.ignoresMouseEvents = !accepts
        }
    }

    // MARK: - PetViewDelegate

    func petViewMouseDown(_ view: PetView, at screenPoint: NSPoint) {
        isPressing = true
        isDragging = false
        pressStart = screenPoint
        grabOffset = NSPoint(x: screenPoint.x - window.frame.minX, y: screenPoint.y - window.frame.minY)
    }

    func petViewMouseDragged(_ view: PetView, to screenPoint: NSPoint) {
        guard isPressing else { return }
        if !isDragging {
            let distance = hypot(screenPoint.x - pressStart.x, screenPoint.y - pressStart.y)
            guard distance > Self.dragThreshold else { return }
            isDragging = true
            machine.beginDrag()
        }
        window.setFrameOrigin(NSPoint(x: screenPoint.x - grabOffset.x, y: screenPoint.y - grabOffset.y))
    }

    func petViewMouseUp(_ view: PetView, at screenPoint: NSPoint) {
        guard isPressing else { return }
        isPressing = false
        if isDragging {
            isDragging = false
            velocityY = 0
            machine.drop()
        } else {
            machine.poke()
        }
    }

    func petViewContextMenu(_ view: PetView) -> NSMenu? {
        machine.noteInteraction()
        return contextMenuProvider?()
    }
}
