import SwiftUI

struct FanRow: View {
    let reading: FanReading
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "fanblades")
                .imageScale(.small)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(reading.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(reading.rpm)")
                .font(.callout.weight(.semibold).monospacedDigit())
            Text("RPM")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fan \(reading.label)")
        .accessibilityValue("\(reading.rpm) RPM")
    }
}
