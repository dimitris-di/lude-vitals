import SwiftUI

struct ProcessListView: View {
    let processes: [ProcessUsage]
    @State private var sort: SortMode = .cpu
    enum SortMode: String, CaseIterable, Identifiable { case cpu = "CPU"; case ram = "RAM"; var id: String { rawValue } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Sort processes", selection: $sort) {
                ForEach(SortMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Sort processes")

            let rows = (sort == .cpu
                ? processes.sorted { $0.cpu > $1.cpu }
                : processes.sorted { $0.memoryBytes > $1.memoryBytes }
            ).prefix(5)

            if rows.isEmpty {
                Text("No process samples yet").font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(rows)) { p in
                        HStack(spacing: 8) {
                            Text(p.name)
                                .font(.callout.weight(.medium))
                                .lineLimit(1).truncationMode(.tail)
                            Spacer()
                            Text(String(format: "%.1f%%", p.cpu * 100))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(sort == .cpu ? .primary : .secondary)
                                .frame(minWidth: 52, alignment: .trailing)
                                .fixedSize(horizontal: true, vertical: false)
                            Text(Fmt.bytes(p.memoryBytes))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(sort == .ram ? .primary : .secondary)
                                .frame(minWidth: 60, alignment: .trailing)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Process \(p.name)")
                        .accessibilityValue("CPU \(String(format: "%.1f", p.cpu * 100)) percent, memory \(Fmt.bytes(p.memoryBytes))")
                    }
                }
            }
        }
    }
}
