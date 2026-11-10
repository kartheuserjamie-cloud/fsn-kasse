import SwiftUI
import UIKit

/// Blue, pink, grey, pink, blue bar from the top of the website.
struct FlagBar: View {
    var height: CGFloat = 6

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Theme.flagColors.enumerated()), id: \.offset) { _, color in
                color
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Horizontal stripes like the hero section of the website.
struct HeroStripes: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(Theme.heroColors.enumerated()), id: \.offset) { _, color in
                color
            }
        }
        .accessibilityHidden(true)
    }
}

/// White box on the striped hero background.
struct HeroHeader: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 40)
                .accessibilityLabel("Femboy Support Network e. V.")
            Text(title)
                .font(.fsn(28, bold: true))
                .foregroundColor(Theme.text)
            Text(text)
                .font(.fsn(16))
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .background(HeroStripes())
        .overlay(alignment: .bottom) {
            Theme.border.frame(height: 1)
        }
    }
}

struct FSNButtonStyle: ButtonStyle {
    enum Kind {
        case primary, accent, secondary, onDark
    }

    var kind: Kind = .primary
    var fullWidth = false
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        FSNButtonBody(configuration: configuration, kind: kind, fullWidth: fullWidth, compact: compact)
    }

    private struct FSNButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind
        let fullWidth: Bool
        let compact: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.fsn(compact ? 14 : 16, bold: true))
                .multilineTextAlignment(.center)
                .padding(.vertical, compact ? 9 : 15)
                .padding(.horizontal, compact ? 14 : 20)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .foregroundColor(foreground)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .stroke(borderColor, lineWidth: 1)
                )
                .opacity(isEnabled ? 1 : 0.5)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .contentShape(Rectangle())
        }

        private var foreground: Color {
            switch kind {
            case .primary: return .white
            case .accent: return Theme.text
            case .secondary: return Theme.text
            case .onDark: return .white
            }
        }

        private var background: Color {
            let pressed = configuration.isPressed
            switch kind {
            case .primary: return pressed ? Theme.primaryLight : Theme.primary
            case .accent: return pressed ? .white : Theme.accent
            case .secondary: return pressed ? Theme.border : .white
            case .onDark: return pressed ? Color.white.opacity(0.18) : .clear
            }
        }

        private var borderColor: Color {
            switch kind {
            case .secondary: return Theme.border
            case .onDark: return Color.white.opacity(0.4)
            default: return .clear
            }
        }
    }
}

/// Card with a violet underline under the heading, like the cards in the internal dispatcher.
struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.fsn(20, bold: true))
                    .foregroundColor(Theme.text)
                Theme.primary.frame(height: 2)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

/// Grey info box, like the crisis banner on the website.
struct InfoBanner: View {
    let title: String
    let text: String
    var accent: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.fsn(16, bold: true))
                .foregroundColor(Theme.text)
            Text(text)
                .font(.fsn(15))
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(alignment: .top) {
            if let accent {
                accent.frame(height: 4)
            }
        }
        .overlay(
            Rectangle().stroke(Theme.borderStrong, lineWidth: 1)
        )
    }
}

struct AlertBox: View {
    enum Style { case error, success }

    let style: Style
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(lines, id: \.self) { line in
                Text(line)
            }
        }
        .font(.fsn(15, bold: true))
        .foregroundColor(style == .error ? Theme.errorText : Theme.successText)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style == .error ? Theme.errorBackground : Theme.successBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
    }
}

/// Pill with a coloured dot, like the job status on the website.
struct StatusTag: View {
    let text: String
    let dot: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dot)
                .frame(width: 6, height: 6)
            Text(text.uppercased())
                .font(.fsn(11, bold: true))
                .tracking(0.6)
        }
        .foregroundColor(Color(hex: 0x4B5563))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(hex: 0xE5E7EB), lineWidth: 1))
    }
}

struct FSNField: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var capitalization: TextInputAutocapitalization = .sentences
    var invalid = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.fsn(15, bold: true))
                .foregroundColor(Theme.text)
            TextField(placeholder, text: $text)
                .font(.fsn(17))
                .foregroundColor(Theme.text)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled(keyboard == .emailAddress || capitalization == .never)
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .stroke(invalid ? Theme.danger : Theme.border, lineWidth: invalid ? 2 : 1)
                )
        }
    }
}

struct CheckRow: View {
    let text: String
    @Binding var isOn: Bool
    var invalid = false

    var body: some View {
        Button {
            isOn.toggle()
            Haptics.tap()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .fill(isOn ? Theme.primary : Color.white)
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .stroke(isOn ? Theme.primary : (invalid ? Theme.danger : Theme.borderStrong), lineWidth: invalid && !isOn ? 2 : 1.5)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 24, height: 24)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isOn)

                Text(text)
                    .font(.fsn(15))
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
