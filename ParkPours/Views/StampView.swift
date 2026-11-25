import SwiftUI

/// One inked stamp. Shape and tilt are derived from the drink id so a stamp
/// always looks the same; a "Denied" verdict always gets the heavy red box.
struct StampView: View {
    let drink: Drink
    let stamp: Stamp

    private var seed: Int {
        drink.id.unicodeScalars.reduce(7) { ($0 * 31 + Int($1.value)) % 9973 }
    }

    private var angle: Double {
        Double(seed % 19) - 9
    }

    private var areaLine: String {
        (drink.area.isEmpty ? drink.venue : drink.area).uppercased()
    }

    var body: some View {
        shape
            .foregroundStyle(stamp.verdict.ink)
            .rotationEffect(.degrees(angle))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(drink.name), \(stamp.verdict.label.capitalized)")
    }

    @ViewBuilder
    private var shape: some View {
        if stamp.verdict == .denied {
            deniedStamp
        } else if seed % 3 == 0 {
            roundStamp
        } else if seed % 3 == 1 {
            boxStamp
        } else {
            ovalStamp
        }
    }

    private var nameText: some View {
        Text(drink.name.uppercased())
            .font(Theme.stamp(15))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
    }

    private var areaText: some View {
        Text(areaLine)
            .font(Theme.stamp(10, weight: .medium))
            .tracking(1.6)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private var roundStamp: some View {
        VStack(spacing: 3) {
            areaText
            nameText
            Text(Formats.stamp(stamp.date))
                .font(Theme.mono(10))
            Text(stamp.verdict.label)
                .font(Theme.stamp(10))
                .tracking(0.9)
        }
        .padding(20)
        .frame(width: 146, height: 146)
        .overlay {
            Circle().strokeBorder(lineWidth: 3)
        }
        .overlay {
            Circle().strokeBorder(lineWidth: 1).padding(6)
        }
    }

    private var boxStamp: some View {
        VStack(spacing: 4) {
            areaText
            nameText
            Rectangle().frame(height: 1)
            HStack {
                Text(Formats.stamp(stamp.date))
                    .font(Theme.mono(10))
                Spacer(minLength: 4)
                Text(stamp.verdict.label)
                    .font(Theme.stamp(10))
                    .tracking(0.9)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 172)
        .overlay {
            Rectangle().strokeBorder(lineWidth: 2)
        }
        .overlay {
            Rectangle().strokeBorder(lineWidth: 1).padding(4)
        }
    }

    private var ovalStamp: some View {
        VStack(spacing: 3) {
            areaText
            nameText
            Text("\(Formats.stamp(stamp.date)) · \(stamp.verdict.label)")
                .font(Theme.mono(10))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .frame(width: 178, height: 112)
        .overlay {
            Ellipse().strokeBorder(lineWidth: 2.5)
        }
    }

    private var deniedStamp: some View {
        VStack(spacing: 2) {
            Text("DENIED")
                .font(Theme.stamp(26))
                .tracking(3.4)
            Text(drink.name.uppercased())
                .font(Theme.stamp(13, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text("\(areaLine) · \(Formats.stamp(stamp.date))")
                .font(Theme.mono(10))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: 174)
        .overlay {
            Rectangle().strokeBorder(lineWidth: 4)
        }
    }
}

/// A stamp scaled to fit the space it is given, with room for its tilt, so it
/// is never clipped on a narrow page. `maxScale` lets the editor show it large.
struct FittedStamp: View {
    let drink: Drink
    let stamp: Stamp
    var maxScale: CGFloat = 1

    /// The largest stamp shape plus the corners it swings out when tilted.
    static let designSize = CGSize(width: 200, height: 160)

    var body: some View {
        GeometryReader { geo in
            let scale = min(
                maxScale,
                geo.size.width / Self.designSize.width,
                geo.size.height / Self.designSize.height
            )
            StampView(drink: drink, stamp: stamp)
                .fixedSize()
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
