import SwiftUI

struct ProgressBar: View {
    let value: Double
    let tint: Color
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let trackOpacity = contrast == .increased ? 0.2 : 0.08
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(trackOpacity))
                Capsule().fill(tint).frame(width: geo.size.width * CGFloat(max(0, min(1, value))))
            }
        }
        .frame(height: 6)
    }
}
