import AppKit
import Testing
@testable import Purrsistent

@MainActor
@Suite struct AnimeCatRendererTests {
    private let size = NSSize(width: 128, height: 128)

    @Test func measuresVisibleChange() {
        let pose = Pose()
        #expect(AnimeCatRenderer.visibleChange(from: pose, to: pose) == 0)

        var breath = pose
        breath.arch += 0.02
        breath.head.y += 0.01
        #expect(AnimeCatRenderer.visibleChange(from: pose, to: breath) < 0.05)

        var blink = pose
        blink.lid = 0.5
        #expect(AnimeCatRenderer.visibleChange(from: pose, to: blink) > 1)

        var squint = pose
        squint.eyes = .happy
        #expect(AnimeCatRenderer.visibleChange(from: pose, to: squint) == .infinity)
    }

    @Test func skipsFramesThatWouldLookTheSame() {
        let animator = AnimeCatAnimator(random: seeded())
        animator.start(.loaf)
        let renderer = AnimeCatRenderer()
        #expect(renderer.renderCat(animator, appearance: .orange, size: size, scale: 2) != nil)
        #expect(renderer.renderCat(animator, appearance: .orange, size: size, scale: 2) == nil)

        renderer.invalidate()
        #expect(renderer.renderCat(animator, appearance: .orange, size: size, scale: 2) != nil)

        // A change of size or backing scale always redraws.
        #expect(renderer.renderCat(animator, appearance: .orange, size: size, scale: 1) != nil)
    }

    @Test func aRestingCatIsRedrawnOnlyAsOftenAsItVisiblyMoves() {
        let animator = AnimeCatAnimator(random: seeded(3))
        animator.start(.loaf)
        let renderer = AnimeCatRenderer()
        var drawn = 0
        for _ in 0..<300 {
            animator.update(by: 1.0 / 30)
            if renderer.renderCat(animator, appearance: .orange, size: size, scale: 2) != nil { drawn += 1 }
        }
        #expect(drawn > 20)
        #expect(drawn < 200)
    }

    @Test func particlesAreDrawnSeparately() {
        let animator = AnimeCatAnimator(random: seeded())
        animator.start(.idle)
        let renderer = AnimeCatRenderer()
        #expect(renderer.renderParticles(animator, appearance: .orange, size: size, scale: 2) == nil)

        animator.drowsiness = 1
        animator.setMotion(.sleep)
        run(animator, for: 4)
        #expect(!animator.particles.isEmpty)
        #expect(renderer.renderParticles(animator, appearance: .orange, size: size, scale: 2) != nil)
    }

    @Test func petViewHandsItsImagesToCoreAnimation() throws {
        let animator = AnimeCatAnimator(random: seeded())
        animator.start(.sit)
        let view = PetView(frame: NSRect(origin: .zero, size: size))
        view.image = AnimeCatRenderer().renderCat(animator, appearance: .orange, size: size, scale: 2)
        view.updateLayer()
        let layer = try #require(view.layer)
        #expect(layer.contents != nil)
        #expect(view.isOpaque(at: NSPoint(x: 64, y: 40)))
        #expect(!view.isOpaque(at: NSPoint(x: 2, y: 126)))
    }
}
