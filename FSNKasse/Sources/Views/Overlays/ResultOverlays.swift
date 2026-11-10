import SwiftUI

struct SuccessOverlay: View {
    let outcome: PaymentOutcome
    let onDone: () -> Void

    @State private var backdrop = false
    @State private var stripes = false
    @State private var badge = false
    @State private var check: CGFloat = 0
    @State private var ring = false
    @State private var content = false
    @State private var amount: Double = 0
    @State private var confetti = false

    private var subtitle: String {
        if outcome.isPreview {
            return "So sieht eine erfolgreiche Zahlung aus."
        }
        switch outcome.request.purpose {
        case .merch:
            return "Danke für deinen Einkauf."
        case .membership(_, let firstName):
            return "Willkommen im Verein, \(firstName)."
        }
    }

    var body: some View {
        GeometryReader { geo in
            let diameter = hypot(geo.size.width, geo.size.height) * 1.2

            ZStack {
                Color.black.opacity(backdrop ? 0.2 : 0)

                Circle()
                    .fill(Theme.primary)
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(backdrop ? 1 : 0.01)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.36)

                VStack(spacing: 0) {
                    FlagSweep(active: stripes)
                        .frame(height: geo.safeAreaInsets.top + 10)
                    Spacer()
                    FlagSweep(active: stripes, fromBottom: true)
                        .frame(height: 10)
                }

                if confetti {
                    ConfettiView()
                }

                VStack(spacing: 0) {
                    Spacer(minLength: geo.safeAreaInsets.top + 24)

                    ZStack {
                        Circle()
                            .stroke(Theme.accent, lineWidth: 3)
                            .frame(width: 150, height: 150)
                            .scaleEffect(ring ? 1.9 : 1)
                            .opacity(ring ? 0 : (badge ? 0.9 : 0))
                        Circle()
                            .fill(Color.white)
                            .frame(width: 150, height: 150)
                            .scaleEffect(badge ? 1 : 0.2)
                            .opacity(badge ? 1 : 0)
                        CheckmarkShape()
                            .trim(from: 0, to: check)
                            .stroke(Theme.primary, style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
                            .frame(width: 76, height: 76)
                    }
                    .padding(.bottom, 28)

                    VStack(spacing: 12) {
                        Text("Bezahlt")
                            .font(.fsn(46, bold: true))
                            .foregroundColor(.white)
                        CountingAmount(value: amount)
                            .font(.fsn(30, bold: true))
                            .foregroundColor(Theme.accent)
                        Text(subtitle)
                            .font(.fsn(18))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if let number = outcome.memberNumber {
                            VStack(spacing: 4) {
                                Text("MITGLIEDSNUMMER")
                                    .font(.fsn(12, bold: true))
                                    .tracking(1.2)
                                    .foregroundColor(Theme.accent)
                                Text(number)
                                    .font(.fsn(26, bold: true))
                                    .foregroundColor(.white)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 22)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radius)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                            .padding(.top, 8)
                        }

                        if outcome.isTest {
                            Text(outcome.isPreview ? "Vorschau, keine echte Zahlung." : "Testzahlung, es wurde kein Geld bewegt.")
                                .font(.fsn(14))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 4)
                        }
                    }
                    .opacity(content ? 1 : 0)
                    .offset(y: content ? 0 : 24)

                    Spacer()

                    Button("Fertig", action: onDone)
                        .buttonStyle(FSNButtonStyle(kind: .accent, fullWidth: true))
                        .frame(maxWidth: 420)
                        .opacity(content ? 1 : 0)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 28)
                }
                .padding(.horizontal, 24)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .onAppear(perform: run)
    }

    private func run() {
        let target = outcome.request.amount.doubleValue
        withAnimation(.easeOut(duration: 0.55)) { backdrop = true }
        stripes = true
        withAnimation(.spring(response: 0.45, dampingFraction: 0.58).delay(0.22)) { badge = true }
        withAnimation(.easeOut(duration: 0.35).delay(0.42)) { check = 1 }
        withAnimation(.easeOut(duration: 1.1).delay(0.5)) { ring = true }
        withAnimation(.easeOut(duration: 0.45).delay(0.55)) { content = true }
        withAnimation(.easeOut(duration: 0.9).delay(0.6)) { amount = target }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            confetti = true
        }
    }
}

struct DeclineOverlay: View {
    let outcome: PaymentOutcome
    let onRetry: () -> Void
    let onCancel: () -> Void

    @State private var backdrop = false
    @State private var card = false
    @State private var cross: CGFloat = 0
    @State private var shake: CGFloat = 0
    @State private var pulse = false
    @State private var flash = false

    private var message: String {
        outcome.message ?? "Die Zahlung wurde abgelehnt oder abgebrochen. Es wurde nichts abgebucht."
    }

    var body: some View {
        ZStack {
            Theme.text.opacity(backdrop ? 0.82 : 0)
                .ignoresSafeArea()

            Theme.danger.opacity(flash ? 0.28 : 0)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.danger.frame(height: 4)

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Theme.danger.opacity(0.22))
                            .frame(width: 118, height: 118)
                            .scaleEffect(pulse ? 1.45 : 0.85)
                            .opacity(pulse ? 0 : 1)
                        Circle()
                            .fill(Theme.danger)
                            .frame(width: 96, height: 96)
                        CrossShape()
                            .trim(from: 0, to: cross)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                            .frame(width: 36, height: 36)
                    }
                    .padding(.top, 8)

                    Text("Abgelehnt")
                        .font(.fsn(36, bold: true))
                        .foregroundColor(Theme.text)

                    Text(Format.euro(outcome.request.amount))
                        .font(.fsn(20, bold: true))
                        .foregroundColor(Theme.muted)
                        .strikethrough(true, color: Theme.danger)

                    Text(message)
                        .font(.fsn(16))
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 10) {
                        Button("Erneut versuchen", action: onRetry)
                            .buttonStyle(FSNButtonStyle(kind: .primary, fullWidth: true))
                        Button("Abbrechen", action: onCancel)
                            .buttonStyle(FSNButtonStyle(kind: .secondary, fullWidth: true))
                    }
                    .padding(.top, 8)
                }
                .padding(26)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .modifier(ShakeEffect(progress: shake))
            .scaleEffect(card ? 1 : 0.86)
            .opacity(card ? 1 : 0)
        }
        .onAppear(perform: run)
    }

    private func run() {
        withAnimation(.easeOut(duration: 0.25)) { backdrop = true }
        withAnimation(.easeOut(duration: 0.12)) { flash = true }
        withAnimation(.easeIn(duration: 0.5).delay(0.12)) { flash = false }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) { card = true }
        withAnimation(.easeInOut(duration: 0.35).delay(0.18)) { cross = 1 }
        withAnimation(.linear(duration: 0.55).delay(0.28)) { shake = 1 }
        withAnimation(.easeOut(duration: 1.0).delay(0.3)) { pulse = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            Haptics.thud()
        }
    }
}

struct ProcessingOverlay: View {
    let isTest: Bool
    @State private var bounce = false

    private let colors: [Color] = [Theme.flagBlue, Theme.flagPink, Theme.primary]

    var body: some View {
        ZStack {
            Color.white.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(colors[index])
                            .frame(width: 16, height: 16)
                            .offset(y: bounce ? -12 : 6)
                            .animation(
                                .easeInOut(duration: 0.42)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.14),
                                value: bounce
                            )
                    }
                }
                .frame(height: 40)

                Text("Zahlung läuft")
                    .font(.fsn(20, bold: true))
                    .foregroundColor(Theme.text)
                Text(isTest ? "Testzahlung wird durchgeführt." : "Karte an den Kartenleser halten oder einstecken.")
                    .font(.fsn(15))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        }
        .onAppear { bounce = true }
    }
}
