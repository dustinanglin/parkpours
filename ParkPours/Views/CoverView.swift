import SwiftUI

/// The closed passport. Shown on the cover screen (and on any slab iPhone)
/// until the book is opened.
struct CoverView: View {
    let stampCount: Int
    let onOpen: () -> Void
    let onStamp: () -> Void

    var body: some View {
        ZStack {
            Theme.cover.ignoresSafeArea()

            HStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0.38), Color.black.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 22)
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                titles
                Spacer(minLength: 12)
                emblem
                Spacer(minLength: 12)
                passportLine
                Spacer(minLength: 16)
                actions
            }
            .padding(.horizontal, 36)
            .padding(.top, 36)
            .padding(.bottom, 20)
        }
        .foregroundStyle(Theme.gold)
    }

    private var titles: some View {
        VStack(spacing: 6) {
            Text("THEME PARKS OF THE WORLD")
                .font(Theme.serif(12))
                .tracking(3.6)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("PARK POURS")
                .font(Theme.serif(34, weight: .bold))
                .tracking(5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var emblem: some View {
        Button(action: onOpen) {
            ZStack {
                Circle().strokeBorder(lineWidth: 2.5)
                Circle().strokeBorder(lineWidth: 1).padding(8)
                Image(systemName: "wineglass")
                    .font(.system(size: 78, weight: .light))
            }
            .frame(width: 180, height: 180)
            .foregroundStyle(Theme.gold)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open passport")
    }

    private var passportLine: some View {
        VStack(spacing: 8) {
            Text("PASSPORT")
                .font(Theme.serif(28, weight: .bold))
                .tracking(8)
            Text(stampCount == 1 ? "1 STAMP" : "\(stampCount) STAMPS")
                .font(Theme.mono(12))
                .tracking(1.2)
        }
    }

    private var actions: some View {
        VStack(spacing: 4) {
            Button(action: onStamp) {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("STAMP A DRINK")
                        .font(Theme.stamp(17, weight: .semibold))
                        .tracking(2.4)
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .overlay {
                    Rectangle().strokeBorder(lineWidth: 1.5)
                }
                .foregroundStyle(Theme.gold)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onOpen) {
                Text("OPEN PASSPORT")
                    .font(Theme.mono(12))
                    .tracking(1.2)
                    .foregroundStyle(Theme.gold)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
