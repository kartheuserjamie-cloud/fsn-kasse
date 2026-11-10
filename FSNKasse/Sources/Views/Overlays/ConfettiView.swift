import SwiftUI

/// Confetti in the flag colours: one burst from the badge, two from the lower corners.
struct ConfettiView: View {
    @State private var start = Date()
    @State private var finished = false
    @State private var pieces: [Piece] = ConfettiView.makePieces()

    private static let lifetime: Double = 4.2
    private static let gravity: Double = 620

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: finished)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    draw(piece, at: elapsed - piece.delay, in: size, context: context)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            start = Date()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64((Self.lifetime + 0.6) * 1_000_000_000))
                finished = true
            }
        }
    }

    private func draw(_ piece: Piece, at t: Double, in size: CGSize, context: GraphicsContext) {
        guard t > 0, t < Self.lifetime else { return }

        let originX = Double(piece.origin.x * size.width)
        let originY = Double(piece.origin.y * size.height)
        let drag: Double = (1 - exp(-t * 1.7)) / 1.7
        let travel: Double = piece.speed * drag
        let sway: Double = sin(t * piece.wobbleSpeed) * piece.wobble
        let fall: Double = 0.5 * Self.gravity * t * t * 0.55
        let x: Double = originX + cos(piece.angle) * travel + sway
        let y: Double = originY + sin(piece.angle) * travel + fall
        guard y < Double(size.height) + 40 else { return }

        let fade: Double = min(1, (Self.lifetime - t) / 0.8)
        let flip: Double = max(0.15, abs(cos(t * piece.flipSpeed)))
        var ctx = context
        ctx.opacity = fade
        ctx.translateBy(x: CGFloat(x), y: CGFloat(y))
        ctx.rotate(by: .radians(piece.spin + t * piece.spinSpeed))
        ctx.scaleBy(x: 1, y: CGFloat(flip))

        let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2, width: piece.size.width, height: piece.size.height)
        let path = piece.isRound ? Path(ellipseIn: rect) : Path(rect)
        ctx.fill(path, with: .color(piece.color))
    }

    private struct Piece {
        var origin: CGPoint
        var angle: Double
        var speed: Double
        var delay: Double
        var size: CGSize
        var color: Color
        var spin: Double
        var spinSpeed: Double
        var flipSpeed: Double
        var wobble: Double
        var wobbleSpeed: Double
        var isRound: Bool
    }

    private static func makePieces() -> [Piece] {
        func piece(origin: CGPoint, angle: ClosedRange<Double>, speed: ClosedRange<Double>, delay: ClosedRange<Double>) -> Piece {
            let width = Double.random(in: 6...10)
            let isRound = Int.random(in: 0..<6) == 0
            return Piece(
                origin: origin,
                angle: Double.random(in: angle) * .pi / 180,
                speed: Double.random(in: speed),
                delay: Double.random(in: delay),
                size: CGSize(width: width, height: isRound ? width : width * Double.random(in: 1.4...2.0)),
                color: Theme.confettiColors.randomElement() ?? Theme.flagPink,
                spin: Double.random(in: 0...(2 * .pi)),
                spinSpeed: Double.random(in: -7...7),
                flipSpeed: Double.random(in: 3...9),
                wobble: Double.random(in: 4...18),
                wobbleSpeed: Double.random(in: 2...5),
                isRound: isRound
            )
        }

        let burst = (0..<110).map { _ in
            piece(origin: CGPoint(x: 0.5, y: 0.34), angle: -170 ... -10, speed: 420...1050, delay: 0...0.08)
        }
        let left = (0..<45).map { _ in
            piece(origin: CGPoint(x: 0, y: 0.92), angle: -75 ... -45, speed: 700...1250, delay: 0.1...0.3)
        }
        let right = (0..<45).map { _ in
            piece(origin: CGPoint(x: 1, y: 0.92), angle: -135 ... -105, speed: 700...1250, delay: 0.1...0.3)
        }
        return burst + left + right
    }
}
