import SwiftUI

struct CoreRow: View {
    let label: String
    var clusterName: String = "Cores"
    let cores: [CoreUsage]
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let trackOpacity = contrast == .increased ? 0.20 : 0.10
        let avg = average(cores)
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text("\(Int((avg * 100).rounded()))%")
                    .font(.callout.monospacedDigit().weight(.semibold))
            }
            .frame(width: 36, alignment: .leading)
            .accessibilityHidden(true)

            HStack(spacing: 3) {
                ForEach(cores) { c in
                    CoreBar(usage: c.usage, trackOpacity: trackOpacity)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(clusterName)
        .accessibilityValue("Average \(Int((avg * 100).rounded())) percent across \(cores.count) cores")
    }

    private func average(_ c: [CoreUsage]) -> Double {
        c.isEmpty ? 0 : c.map(\.usage).reduce(0, +) / Double(c.count)
    }
}

private struct CoreBar: View {
    let usage: Double
    let trackOpacity: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.primary.opacity(trackOpacity))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(barColor(usage))
                    .frame(height: max(2, geo.size.height * CGFloat(min(1, max(0, usage)))))
            }
        }
    }
    private func barColor(_ v: Double) -> Color {
        v < 0.6 ? .green : (v < 0.85 ? .yellow : .red)
    }
}
