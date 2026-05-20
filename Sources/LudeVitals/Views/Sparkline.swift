import SwiftUI

struct Sparkline: View {
    let values: [Double]
    var width: CGFloat = 48
    var height: CGFloat = 14
    var color: Color = .accentColor
    var lineWidth: CGFloat = 1.2

    var body: some View {
        if values.isEmpty {
            Color.clear.frame(width: width, height: height)
        } else {
            Canvas { ctx, size in
                let clamped = values.map { max(0, min(1, $0)) }
                let n = clamped.count
                guard n > 1 else { return }
                let stepX = size.width / CGFloat(n - 1)
                var path = Path()
                for (i, v) in clamped.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = size.height - CGFloat(v) * size.height
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else      { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
            .frame(width: width, height: height)
        }
    }
}
