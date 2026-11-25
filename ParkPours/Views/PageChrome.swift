import SwiftUI

/// Security-paper background: pale stock with two sets of fine concentric rings.
struct PaperBackground: View {
    var body: some View {
        Canvas { context, size in
            let color = Theme.guilloche.opacity(0.07)
            let maxRadius = hypot(size.width, size.height)

            var radius: CGFloat = 13
            while radius < maxRadius {
                let rect = CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 1)
                radius += 13
            }

            radius = 17
            while radius < maxRadius {
                let rect = CGRect(
                    x: size.width - radius,
                    y: size.height - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 1)
                radius += 17
            }
        }
        .background(Theme.paper)
        .ignoresSafeArea()
    }
}

/// The gutter shadow that sits over the fold: the centre of the whole
/// window, not of the safe area.
struct SpineShadow: View {
    var body: some View {
        Color.clear
            .overlay {
                gradient.frame(width: 60)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private var gradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0), location: 0),
                .init(color: Color.black.opacity(0.16), location: 0.48),
                .init(color: Color.black.opacity(0.22), location: 0.5),
                .init(color: Color.black.opacity(0.16), location: 0.52),
                .init(color: Color.black.opacity(0), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// One passport page: small running header, content, footer.
struct PageScaffold<Content: View, Footer: View>: View {
    private let leading: String
    private let trailing: String
    private let content: Content
    private let footer: Footer

    init(
        leading: String,
        trailing: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.leading = leading
        self.trailing = trailing
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(leading)
                Spacer(minLength: 8)
                Text(trailing)
            }
            .font(Theme.mono(11))
            .tracking(1.3)
            .lineLimit(1)
            .foregroundStyle(Theme.muted)
            .contentShape(Rectangle())
            .onLongPressGesture {
                // Same as a shake: start a bug report.
                NotificationCenter.default.post(name: .feedbackRequested, object: nil)
            }

            content

            footer
        }
        .padding(.horizontal, 26)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct DottedRule: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
            }
            .stroke(Theme.rule, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        }
        .frame(height: 1)
    }
}

struct SolidRule: View {
    var body: some View {
        Rectangle()
            .fill(Theme.ink)
            .frame(height: 1)
    }
}

struct ProgressRule: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .strokeBorder(Theme.muted, lineWidth: 1)
                Rectangle()
                    .fill(Theme.muted)
                    .frame(width: geo.size.width * CGFloat(min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

/// Small boxed tag marking a non-alcoholic drink.
struct ZeroProofTag: View {
    var body: some View {
        Text("ZERO PROOF")
            .font(Theme.mono(9, weight: .medium))
            .tracking(0.8)
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .overlay {
                Rectangle().strokeBorder(Theme.muted, lineWidth: 1)
            }
            .fixedSize()
            .accessibilityLabel("Non-alcoholic")
    }
}
