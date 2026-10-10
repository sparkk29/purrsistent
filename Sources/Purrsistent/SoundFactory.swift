import Foundation

/// Synthesizes the built-in placeholder sounds as 16-bit mono WAV data.
enum SoundFactory {
    private static let sampleRate: Double = 22050

    static func clips(for effect: SoundEffect) -> [Data] {
        switch effect {
        case .meow: [1.0, 0.88, 1.14].map { wav(meow(pitch: $0), peak: 0.8) }
        case .chirp: [1.0, 1.2].map { wav(chirp(pitch: $0), peak: 0.7) }
        case .thud: [wav(thud(), peak: 0.9)]
        case .purr: [wav(purr(), peak: 0.8)]
        }
    }

    static func exportWAVs(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for effect in SoundEffect.allCases {
            for (index, data) in clips(for: effect).enumerated() {
                try data.write(to: directory.appendingPathComponent("\(effect.rawValue)_\(index).wav"))
            }
        }
    }

    // MARK: - Voices

    private struct Formants {
        var f1: Double, f2: Double, f3: Double
    }

    private static func meow(pitch: Double) -> [Float] {
        let duration = 0.62
        return voice(
            duration: duration,
            pitch: { u in
                let contour = u < 0.3
                    ? lerp(520, 760, smoothstep(u / 0.3))
                    : lerp(760, 460, smoothstep((u - 0.3) / 0.7))
                return contour * pitch * (1 + 0.012 * sin(2 * .pi * 6 * u * duration))
            },
            formants: { u in
                interpolate([
                    (0.0, Formants(f1: 300, f2: 1900, f3: 2800)),
                    (0.15, Formants(f1: 450, f2: 2100, f3: 2900)),
                    (0.45, Formants(f1: 850, f2: 1500, f3: 2800)),
                    (1.0, Formants(f1: 400, f2: 800, f3: 2600)),
                ], at: u)
            },
            envelope: { u in
                let attack = smoothstep(min(1, u / 0.08))
                let release = u > 0.6 ? max(0, 1 - pow((u - 0.6) / 0.4, 1.5)) : 1
                return attack * release
            }
        )
    }

    private static func chirp(pitch: Double) -> [Float] {
        let duration = 0.28
        return voice(
            duration: duration,
            pitch: { u in lerp(560, 900, smoothstep(u)) * pitch },
            formants: { u in
                interpolate([
                    (0.0, Formants(f1: 350, f2: 1600, f3: 2700)),
                    (0.5, Formants(f1: 600, f2: 1900, f3: 2800)),
                    (1.0, Formants(f1: 400, f2: 2200, f3: 2900)),
                ], at: u)
            },
            envelope: { u in
                let attack = smoothstep(min(1, u / 0.1))
                let release = u > 0.7 ? max(0, 1 - (u - 0.7) / 0.3) : 1
                let trill = u < 0.5 ? 0.5 + 0.5 * cos(2 * .pi * 30 * u * duration) : 1
                return attack * release * trill
            }
        )
    }

    /// Additive voice: harmonics of `pitch`, shaped by moving formant resonances, plus a little breath noise.
    private static func voice(
        duration: Double,
        pitch: (Double) -> Double,
        formants: (Double) -> Formants,
        envelope: (Double) -> Double
    ) -> [Float] {
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var noise = Noise(seed: 7)
        var phase = 0.0

        for n in 0..<count {
            let u = Double(n) / Double(count)
            let f0 = pitch(u)
            phase = (phase + 2 * .pi * f0 / sampleRate).truncatingRemainder(dividingBy: 2 * .pi)
            let shape = formants(u)

            var value = 0.0
            var k = 1
            while Double(k) * f0 < 5000 {
                let frequency = Double(k) * f0
                let weight = resonance(frequency, shape.f1, 90)
                    + 0.7 * resonance(frequency, shape.f2, 130)
                    + 0.3 * resonance(frequency, shape.f3, 220)
                value += weight * sin(Double(k) * phase) / Double(k).squareRoot()
                k += 1
            }
            value += 0.03 * noise.next()
            samples[n] = Float(value * envelope(u))
        }
        return samples
    }

    // MARK: - Effects

    private static func thud() -> [Float] {
        let duration = 0.28
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var noise = Noise(seed: 11)
        var lowpassed = 0.0
        var phase = 0.0

        for n in 0..<count {
            let t = Double(n) / sampleRate
            let frequency = 45 + 90 * exp(-t / 0.04)
            phase += 2 * .pi * frequency / sampleRate
            lowpassed += 0.08 * (noise.next() - lowpassed)
            let attack = min(1, t / 0.002)
            let body = sin(phase) * exp(-t / 0.07)
            let impact = 2.5 * lowpassed * exp(-t / 0.012)
            samples[n] = Float(attack * (body + impact))
        }
        return samples
    }

    /// One breath cycle that loops seamlessly: pulses fall to silence exactly at both ends.
    private static func purr() -> [Float] {
        let duration = 2.4
        let pulseRate = 25.0
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var noise = Noise(seed: 3)
        var stage1 = 0.0
        var stage2 = 0.0

        for n in 0..<count {
            let t = Double(n) / sampleRate
            let breath = 0.6 - 0.4 * cos(2 * .pi * t / duration)
            let pulsePhase = (t * pulseRate).truncatingRemainder(dividingBy: 1)
            let pulse = pow(sin(.pi * pulsePhase), 4)
            stage1 += 0.1 * (noise.next() - stage1)
            stage2 += 0.1 * (stage1 - stage2)
            let rumble = 4 * stage2 + 0.3 * sin(2 * .pi * 75 * t)
            samples[n] = Float(rumble * pulse * breath)
        }
        return samples
    }

    // MARK: - Helpers

    private struct Noise {
        private var state: UInt32

        init(seed: UInt32) { state = seed }

        mutating func next() -> Double {
            state = state &* 1_664_525 &+ 1_013_904_223
            return Double(state) / Double(UInt32.max) * 2 - 1
        }
    }

    private static func resonance(_ frequency: Double, _ center: Double, _ bandwidth: Double) -> Double {
        let x = (frequency - center) / bandwidth
        return 1 / (1 + x * x)
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private static func smoothstep(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }

    private static func interpolate(_ keys: [(Double, Formants)], at u: Double) -> Formants {
        guard let next = keys.firstIndex(where: { $0.0 >= u }), next > 0 else {
            return u <= keys[0].0 ? keys[0].1 : keys[keys.count - 1].1
        }
        let (u0, a) = keys[next - 1]
        let (u1, b) = keys[next]
        let t = (u - u0) / (u1 - u0)
        return Formants(f1: lerp(a.f1, b.f1, t), f2: lerp(a.f2, b.f2, t), f3: lerp(a.f3, b.f3, t))
    }

    private static func wav(_ samples: [Float], peak: Float) -> Data {
        let loudest = samples.map(abs).max() ?? 0
        let gain = loudest > 0 ? peak / loudest : 0
        let rate = UInt32(sampleRate)
        let byteCount = UInt32(samples.count * 2)

        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8))
        append(36 + byteCount)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(rate)
        append(rate * 2)
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        append(byteCount)
        for sample in samples {
            append(Int16(max(-1, min(1, sample * gain)) * Float(Int16.max)))
        }
        return data
    }
}
