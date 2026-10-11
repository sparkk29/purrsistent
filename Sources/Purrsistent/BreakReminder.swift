import Foundation

@MainActor
final class BreakReminder: NSObject {
    private static let messages = [
        "Stretch break?",
        "Drink some water!",
        "Look away from the screen for a bit.",
        "Roll those shoulders.",
        "Time to stand up and stretch, human.",
        "Blink a few times. Like this: -_-",
        "Maybe a short walk?",
    ]

    private var timer: Timer?

    var onRemind: ((String) -> Void)?

    var interval: TimeInterval? {
        didSet {
            if interval != oldValue { reschedule() }
        }
    }

    private func reschedule() {
        timer?.invalidate()
        timer = nil
        guard let interval, interval > 0 else { return }
        let timer = Timer(timeInterval: interval, target: self, selector: #selector(fire), userInfo: nil, repeats: true)
        timer.tolerance = min(30, interval * 0.05)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func fire() {
        onRemind?(Self.messages.randomElement() ?? "Break time!")
    }
}
