import AVFoundation

/// Synthesises the payment sounds at runtime, so no audio files are bundled.
@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    var isEnabled = true

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let sampleRate: Double = 44_100

    private lazy var successBuffer = render(length: 1.7, tones: SoundEngine.successTones)
    private lazy var declineBuffer = render(length: 0.75, tones: SoundEngine.declineTones)
    private lazy var tapBuffer = render(length: 0.1, tones: SoundEngine.tapTones)

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func playSuccess() { play(successBuffer) }
    func playDecline() { play(declineBuffer) }
    func playTap() { play(tapBuffer) }

    private func play(_ buffer: AVAudioPCMBuffer?) {
        guard isEnabled, let buffer else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                return
            }
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
    }

    // MARK: Synthesis

    private enum Timbre {
        case bell, reed, pluck
    }

    private struct Tone {
        var start: Double
        var frequency: Double
        var endFrequency: Double? = nil
        var duration: Double
        var gain: Double
        var decay: Double
        var pan: Double = 0
        var timbre: Timbre
    }

    /// Rising E major arpeggio with a soft bell sound and a little sparkle on top.
    private static let successTones: [Tone] = [
        Tone(start: 0.00, frequency: 329.63, duration: 1.1, gain: 0.10, decay: 3.2, timbre: .bell),
        Tone(start: 0.00, frequency: 659.25, duration: 1.2, gain: 0.20, decay: 3.4, pan: -0.25, timbre: .bell),
        Tone(start: 0.09, frequency: 830.61, duration: 1.2, gain: 0.19, decay: 3.2, pan: 0.25, timbre: .bell),
        Tone(start: 0.18, frequency: 987.77, duration: 1.2, gain: 0.19, decay: 3.0, pan: -0.15, timbre: .bell),
        Tone(start: 0.30, frequency: 1318.51, duration: 1.35, gain: 0.23, decay: 2.5, pan: 0.15, timbre: .bell),
        Tone(start: 0.42, frequency: 2637.02, duration: 0.7, gain: 0.05, decay: 6, pan: 0.4, timbre: .bell),
        Tone(start: 0.50, frequency: 1975.53, duration: 0.6, gain: 0.04, decay: 7, pan: -0.4, timbre: .bell)
    ]

    /// Low thud followed by two falling, slightly detuned notes.
    private static let declineTones: [Tone] = [
        Tone(start: 0.00, frequency: 110, endFrequency: 62, duration: 0.28, gain: 0.45, decay: 10, timbre: .pluck),
        Tone(start: 0.00, frequency: 349.23, endFrequency: 338, duration: 0.2, gain: 0.13, decay: 6, pan: -0.15, timbre: .reed),
        Tone(start: 0.19, frequency: 261.63, endFrequency: 240, duration: 0.5, gain: 0.15, decay: 4.2, pan: 0.15, timbre: .reed),
        Tone(start: 0.19, frequency: 130.81, endFrequency: 120, duration: 0.5, gain: 0.09, decay: 4.2, timbre: .reed)
    ]

    private static let tapTones: [Tone] = [
        Tone(start: 0, frequency: 1200, endFrequency: 1750, duration: 0.07, gain: 0.16, decay: 38, timbre: .pluck)
    ]

    private func render(length: Double, tones: [Tone]) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(length * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buffer.floatChannelData else { return nil }
        buffer.frameLength = frameCount

        let left = channels[0]
        let right = channels[1]
        let total = Int(frameCount)
        for index in 0..<total {
            left[index] = 0
            right[index] = 0
        }

        for tone in tones {
            let first = Int(tone.start * sampleRate)
            let count = min(Int(tone.duration * sampleRate), total - first)
            guard count > 0 else { continue }

            let leftGain = tone.gain * min(1, 1 - tone.pan)
            let rightGain = tone.gain * min(1, 1 + tone.pan)
            var phase = 0.0

            for n in 0..<count {
                let t = Double(n) / sampleRate
                let progress = t / tone.duration
                let frequency = tone.endFrequency.map { tone.frequency + ($0 - tone.frequency) * progress } ?? tone.frequency
                phase += 2 * .pi * frequency / sampleRate

                let attack = min(1, t / 0.004)
                let release = min(1, (tone.duration - t) / 0.03)
                let envelope = attack * release * exp(-t * tone.decay)

                let sample: Double
                switch tone.timbre {
                case .bell:
                    sample = sin(phase)
                        + 0.32 * sin(2 * phase) * exp(-t * 5)
                        + 0.12 * sin(3.98 * phase) * exp(-t * 9)
                case .reed:
                    sample = sin(phase)
                        + 0.45 * sin(2 * phase + 0.3)
                        + 0.22 * sin(3 * phase)
                        + 0.10 * sin(5 * phase)
                case .pluck:
                    sample = sin(phase) + 0.4 * sin(1.5 * phase) * exp(-t * 20)
                }

                let value = sample * envelope
                left[first + n] += Float(value * leftGain)
                right[first + n] += Float(value * rightGain)
            }
        }

        for index in 0..<total {
            left[index] = tanhf(left[index])
            right[index] = tanhf(right[index])
        }
        return buffer
    }
}
