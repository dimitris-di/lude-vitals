import SwiftUI

struct PressurePill: View {
    let label: String
    let tint: Color
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(label).font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.15)))
        .foregroundStyle(.primary)
    }
    static func memory(_ p: MemoryPressure) -> some View {
        switch p {
        case .normal:   return PressurePill(label: "Normal",   tint: .green)
        case .warning:  return PressurePill(label: "Warning",  tint: .orange)
        case .critical: return PressurePill(label: "Critical", tint: .red)
        }
    }
    static func thermal(_ p: ThermalPressure) -> some View {
        switch p {
        case .nominal:  return PressurePill(label: "Nominal",  tint: .green)
        case .fair:     return PressurePill(label: "Fair",     tint: .yellow)
        case .serious:  return PressurePill(label: "Serious",  tint: .orange)
        case .critical: return PressurePill(label: "Critical", tint: .red)
        }
    }
}
