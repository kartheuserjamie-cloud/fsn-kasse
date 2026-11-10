import SwiftUI

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.54))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.41, y: rect.minY + rect.height * 0.78))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.minY + rect.height * 0.26))
        return path
    }
}

struct CrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

/// Horizontal shake that fades out towards the end of the animation.
struct ShakeEffect: GeometryEffect {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = sin(progress * .pi * 8) * 16 * (1 - progress)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

/// Text that counts up to its value while animating.
struct CountingAmount: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(Format.euro(Decimal(value).rounded()))
            .monospacedDigit()
    }
}

/// Flag stripes that drop in one after another.
struct FlagSweep: View {
    let active: Bool
    var fromBottom = false

    private let colors: [Color] = [Theme.flagBlue, Theme.flagPink, .white, Theme.flagPink, Theme.flagBlue]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                color
                    .scaleEffect(x: 1, y: active ? 1 : 0, anchor: fromBottom ? .bottom : .top)
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.7)
                            .delay(0.15 + Double(fromBottom ? colors.count - 1 - index : index) * 0.06),
                        value: active
                    )
            }
        }
        .accessibilityHidden(true)
    }
}
