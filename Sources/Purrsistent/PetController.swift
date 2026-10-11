import AppKit

@MainActor
final class PetController: NSObject, PetViewDelegate {
    private let settings: Settings
    private let window: PetWindow
    private let view: PetView
    private let animator: SpriteAnimator
    private let machine = PetStateMachine()
    private let sound: SoundPlayer
    private let bubble = BubbleWindow()
    private let reminder = BreakReminder()
    private let mood: Mood
    private var treat: Treat?

    private var timer: Timer?
    private var lastTick: TimeInterval = 0
    private var facing: Facing = .right
    private var velocity: CGVector = .zero

    private var isPressing = false
    private var isDragging = false
    private var pressStart: NSPoint = .zero
    private var grabOffset: NSPoint = .zero
    private var dragSamples: [(time: TimeInterval, point: NSPoint)] = []

    private var lastMouse: NSPoint = .zero
    private var strokeAmount: CGFloat = 0
    private var lastStrokeTime: TimeInterval = 0

    private static let tickRate: TimeInterval = 1.0 / 30
    private static let baseWalkSpeed: CGFloat = 45
    private static let gravity: CGFloat = 2400
    private static let dragThreshold: CGFloat = 3
    private static let maxThrowSpeed: CGFloat = 2500
    private static let groundFriction: CGFloat = 1800
    private static let wallBounce: CGFloat = 0.5
    private static let cursorAwarenessRadius: CGFloat = 200
    private static let strokeToStartPetting: CGFloat = 60
    private static let strokeDecayPerSecond: CGFloat = 40
    private static let pettingTimeout: TimeInterval = 0.8
    private static let spontaneousMeowChance = 0.04
    private static let purrVolume: Float = 0.35
    private static let pokeMoodBoost = 0.05
    private static let pettingMoodPerSecond = 0.05
    private static let throwMoodBoost = 0.03
    private static let treatMoodBoost = 0.25

    var contextMenuProvider: (() -> NSMenu?)?

    private(set) var isVisible = false

    init(settings: Settings) {
        self.settings = settings
        let size = settings.size.points
        window = PetWindow(size: size)
        view = PetView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        animator = SpriteAnimator(coat: settings.coat)
        sound = SoundPlayer(voice: settings.voice)
        mood = Mood(settings: settings)
        super.init()

        view.autoresizingMask = [.width, .height]
        view.delegate = self
        window.contentView = view

        machine.allowWalking = !settings.stayStill
        sound.isEnabled = settings.soundEnabled
        sound.masterVolume = settings.soundVolume.level
        machine.mood = mood.value
        machine.onStateChange = { [weak self] old, new in
            self?.handleStateChange(from: old, to: new)
        }
        machine.onStateCompleted = { [weak self] finished in
            if finished == .eating { self?.finishTreat() }
        }
        reminder.interval = settings.breakInterval.seconds
        reminder.onRemind = { [weak self] message in self?.say(message, meow: true) }
        settings.onChange = { [weak self] in self?.applySettings() }
    }

    func previewSound() {
        sound.play(.meow)
    }

    func say(_ message: String, meow: Bool = false) {
        guard isVisible else { return }
        machine.perform(.yawn)
        if meow { sound.play(.meow) }
        bubble.show(message, above: window.frame)
    }

    var moodLabel: String { mood.label }

    var hasTreat: Bool { treat != nil }

    func saveState() {
        mood.save()
    }

    /// Drops a fish a little way from the pet, on whichever side has more room.
    func giveTreat() {
        guard treat == nil, isVisible else { return }
        let frame = window.frame
        let bounds = currentScreen()?.visibleFrame ?? frame
        let size = settings.size.points * 0.4
        let distance = frame.width * CGFloat.random(in: 1.5...2.5)
        let towardRight = bounds.maxX - frame.maxX > frame.minX - bounds.minX
        let centerX = min(max(frame.midX + (towardRight ? distance : -distance), bounds.minX + size / 2), bounds.maxX - size / 2)
        let y = min(bounds.maxY - size, frame.maxY + 120)
        treat = Treat(size: size, origin: NSPoint(x: centerX - size / 2, y: y))
        sound.play(.chirp, volume: 0.6)
    }

    private func finishTreat() {
        treat?.remove()
        treat = nil
        mood.boost(Self.treatMoodBoost)
        machine.poke()
        sound.play(.meow)
    }

    /// Once the treat lands, the pet heads over (waking up if needed) and eats it when close enough.
    private func updateTreat(_ dt: TimeInterval) {
        guard let treat else { return }
        treat.fall(CGFloat(dt), gravity: Self.gravity)
        guard treat.hasLanded else { return }

        switch machine.state {
        case .dragged, .falling, .petted, .happy, .eating:
            return
        default:
            break
        }

        let dx = treat.frame.midX - window.frame.midX
        if abs(dx) <= window.frame.width * 0.45 {
            facing = dx < 0 ? .left : .right
            machine.perform(.eating)
        } else {
            let direction: PetState = dx < 0 ? .walkLeft : .walkRight
            if machine.state != direction { machine.perform(direction) }
        }
    }

    private static func purrs(in state: PetState) -> Bool {
        state == .sleep || state == .petted
    }

    private func handleStateChange(from old: PetState, to new: PetState) {
        switch new {
        case .walkLeft: facing = .left
        case .walkRight: facing = .right
        default: break
        }

        if Self.purrs(in: old) && !Self.purrs(in: new) { sound.stopLoop() }

        switch new {
        case .dragged:
            sound.play(.chirp, volume: 0.8)
        case .sleep, .petted:
            sound.startLoop(.purr, volume: Self.purrVolume)
        case .idle, .sit:
            if old != .falling, old != .sleep, old != .petted, Double.random(in: 0..<1) < Self.spontaneousMeowChance {
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
        lastMouse = NSEvent.mouseLocation
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
            if Self.purrs(in: machine.state) { sound.startLoop(.purr, volume: Self.purrVolume) }
        } else {
            timer?.invalidate()
            timer = nil
            window.orderOut(nil)
            bubble.hide()
            treat?.remove()
            treat = nil
            sound.stopLoop()
            mood.save()
        }
    }

    private func applySettings() {
        machine.allowWalking = !settings.stayStill
        sound.isEnabled = settings.soundEnabled
        sound.masterVolume = settings.soundVolume.level
        sound.load(voice: settings.voice)
        reminder.interval = settings.breakInterval.seconds
        animator.load(coat: settings.coat)
        if isVisible, Self.purrs(in: machine.state) {
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

        let mouse = NSEvent.mouseLocation
        let mouseOverPet = window.frame.contains(mouse) && view.isOpaque(atScreenPoint: mouse)

        mood.tick(dt)
        if machine.state == .petted { mood.boost(Self.pettingMoodPerSecond * dt) }
        machine.mood = mood.value

        machine.tick(dt)
        updatePetting(mouse: mouse, overPet: mouseOverPet, now: now, dt: dt)
        updateTreat(dt)
        updatePosition(dt)
        faceCursor(mouse)
        bubble.follow(window.frame)

        animator.play(machine.state.animationKey)
        animator.advance(by: dt)
        view.image = animator.currentFrame(facing: facing)

        updateMousePassThrough(mouseOverPet: mouseOverPet)
    }

    // MARK: - Cursor

    private func faceCursor(_ mouse: NSPoint) {
        guard machine.state == .idle || machine.state == .sit else { return }
        let frame = window.frame
        let dx = mouse.x - frame.midX
        let dy = mouse.y - frame.midY
        guard abs(dx) > frame.width * 0.1, hypot(dx, dy) < Self.cursorAwarenessRadius else { return }
        facing = dx < 0 ? .left : .right
    }

    /// Stroking is detected as cursor movement over the pet's opaque pixels without a click.
    private func updatePetting(mouse: NSPoint, overPet: Bool, now: TimeInterval, dt: TimeInterval) {
        let moved = hypot(mouse.x - lastMouse.x, mouse.y - lastMouse.y)
        lastMouse = mouse

        if overPet, !isPressing, moved > 0.5 {
            strokeAmount += moved
            lastStrokeTime = now
        }
        strokeAmount = max(0, strokeAmount - Self.strokeDecayPerSecond * CGFloat(dt))

        if machine.state == .petted {
            if !overPet || isPressing || now - lastStrokeTime > Self.pettingTimeout {
                strokeAmount = 0
                machine.stopPetting()
            }
        } else if overPet, !isPressing, strokeAmount > Self.strokeToStartPetting, machine.canBePetted {
            machine.startPetting()
        }
    }

    // MARK: - Movement

    private func updatePosition(_ dt: TimeInterval) {
        guard machine.state != .dragged else { return }

        var frame = window.frame
        let screen = currentScreen()
        let bounds = screen?.visibleFrame ?? frame
        let ground = bounds.minY
        let dt = CGFloat(dt)

        switch machine.state {
        case .falling:
            velocity.dy -= Self.gravity * dt
            frame.origin.x += velocity.dx * dt
            frame.origin.y += velocity.dy * dt
            if frame.maxY > bounds.maxY, velocity.dy > 0 {
                frame.origin.y = bounds.maxY - frame.height
                velocity.dy = 0
            }
            if frame.origin.y <= ground {
                let impactSpeed = -velocity.dy
                frame.origin.y = ground
                velocity.dy = 0
                if abs(velocity.dx) > 60 { facing = velocity.dx < 0 ? .left : .right }
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
            if velocity.dx != 0 {
                frame.origin.x += velocity.dx * dt
                let slowdown = Self.groundFriction * dt
                velocity.dx = abs(velocity.dx) <= slowdown ? 0 : velocity.dx - slowdown * (velocity.dx > 0 ? 1 : -1)
            }
            if frame.origin.y > ground + 1 {
                velocity.dy = 0
                machine.startFalling()
            } else {
                frame.origin.y = ground
            }
        }

        if frame.minX < bounds.minX, !canCross(from: screen, towardRight: false, atY: frame.midY) {
            frame.origin.x = bounds.minX
            hitWall()
        } else if frame.maxX > bounds.maxX, !canCross(from: screen, towardRight: true, atY: frame.midY) {
            frame.origin.x = bounds.maxX - frame.width
            hitWall()
        }

        if frame.origin != window.frame.origin {
            window.setFrameOrigin(frame.origin)
        }
    }

    private func hitWall() {
        velocity.dx = -velocity.dx * Self.wallBounce
        if machine.state.isWalking { machine.turnAround() }
    }

    private var walkSpeed: CGFloat {
        Self.baseWalkSpeed * settings.speed.multiplier * (settings.size.points / PetSize.medium.points)
    }

    private func currentScreen() -> NSScreen? {
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// True when another display continues past this edge at the pet's height and nothing
    /// (like a side-mounted Dock) blocks the way. Once the pet's center crosses over,
    /// `currentScreen()` switches and that display's floor takes over.
    private func canCross(from screen: NSScreen?, towardRight: Bool, atY y: CGFloat) -> Bool {
        guard let screen else { return false }
        let visible = screen.visibleFrame
        let full = screen.frame
        let edgeIsOpen = towardRight ? visible.maxX >= full.maxX - 1 : visible.minX <= full.minX + 1
        guard edgeIsOpen else { return false }
        let probe = NSPoint(x: towardRight ? full.maxX + 1 : full.minX - 1, y: y)
        return NSScreen.screens.contains { $0 != screen && $0.frame.contains(probe) }
    }

    /// Transparent pixels must not swallow clicks meant for apps underneath, so the window only
    /// accepts mouse events while the cursor is over the pet itself.
    private func updateMousePassThrough(mouseOverPet: Bool) {
        let accepts = isPressing || machine.state == .dragged || mouseOverPet
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
        dragSamples.removeAll()
    }

    func petViewMouseDragged(_ view: PetView, to screenPoint: NSPoint) {
        guard isPressing else { return }
        if !isDragging {
            let distance = hypot(screenPoint.x - pressStart.x, screenPoint.y - pressStart.y)
            guard distance > Self.dragThreshold else { return }
            isDragging = true
            velocity = .zero
            machine.beginDrag()
        }
        window.setFrameOrigin(NSPoint(x: screenPoint.x - grabOffset.x, y: screenPoint.y - grabOffset.y))
        recordDragSample(screenPoint)
    }

    func petViewMouseUp(_ view: PetView, at screenPoint: NSPoint) {
        guard isPressing else { return }
        isPressing = false
        if isDragging {
            isDragging = false
            recordDragSample(screenPoint)
            velocity = throwVelocity()
            if hypot(velocity.dx, velocity.dy) > 400 { mood.boost(Self.throwMoodBoost) }
            machine.drop()
        } else {
            mood.boost(Self.pokeMoodBoost)
            machine.poke()
            sound.play(.meow)
        }
    }

    func petViewContextMenu(_ view: PetView) -> NSMenu? {
        machine.noteInteraction()
        return contextMenuProvider?()
    }

    private func recordDragSample(_ point: NSPoint) {
        let now = ProcessInfo.processInfo.systemUptime
        dragSamples.append((now, point))
        dragSamples.removeAll { now - $0.time > 0.1 }
    }

    private func throwVelocity() -> CGVector {
        guard let first = dragSamples.first, let last = dragSamples.last else { return .zero }
        let elapsed = last.time - first.time
        guard elapsed > 0.01 else { return .zero }
        var throwVelocity = CGVector(
            dx: (last.point.x - first.point.x) / elapsed,
            dy: (last.point.y - first.point.y) / elapsed
        )
        let speed = hypot(throwVelocity.dx, throwVelocity.dy)
        if speed > Self.maxThrowSpeed {
            throwVelocity.dx *= Self.maxThrowSpeed / speed
            throwVelocity.dy *= Self.maxThrowSpeed / speed
        }
        return throwVelocity
    }
}
