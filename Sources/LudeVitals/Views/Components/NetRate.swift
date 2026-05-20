import SwiftUI

struct NetRate: View {
    let symbol: String
    let color: Color
    let bps: UInt64

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .imageScale(.medium)
                .foregroundStyle(color)
                .frame(width: 18, height: 18)
                .background(Circle().fill(color.opacity(0.15)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(Fmt.rate(bps))
                    .font(.callout.weight(.semibold).monospacedDigit())
                Text(symbol.contains("down") ? "download" : "upload")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}
