import SwiftUI

struct HeroTile: View {
    let title: String
    let value: String
    let tint: Color
    let spark: [Double]
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let gradStart = contrast == .increased ? tint.opacity(0.35) : tint.opacity(0.20)
        let gradEnd   = contrast == .increased ? tint.opacity(0.20) : tint.opacity(0.05)
        let stroke    = contrast == .increased ? tint.opacity(0.45) : tint.opacity(0.22)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold).monospaced())
                .tracking(0.6)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Sparkline(values: spark, height: 16, color: tint, lineWidth: 1.6)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(
                    colors: [gradStart, gradEnd],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(stroke)
        )
    }
}
