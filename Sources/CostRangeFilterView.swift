import SwiftUI

struct CostRangeFilterView: View {
    @Binding var costMin: Double?
    @Binding var costMax: Double?

    @State private var minText: String = ""
    @State private var maxText: String = ""
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle")
                if costMin != nil || costMax != nil {
                    Text(filterLabel)
                        .lineLimit(1)
                } else {
                    Text("Price")
                }
            }
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cost Range")
                    .font(.headline)

                HStack {
                    Text("Min")
                        .frame(width: 40, alignment: .leading)
                    TextField("0", text: $minText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: minText) { _, newValue in
                            updateCostMin(newValue)
                        }
                }

                HStack {
                    Text("Max")
                        .frame(width: 40, alignment: .leading)
                    TextField("Any", text: $maxText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: maxText) { _, newValue in
                            updateCostMax(newValue)
                        }
                }

                HStack {
                    Button("Clear") {
                        minText = ""
                        maxText = ""
                        costMin = nil
                        costMax = nil
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Done") {
                        showPopover = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 180)
        }
        .onAppear {
            // Sync state from bindings
            if let min = costMin {
                minText = String(format: "%.0f", min)
            }
            if let max = costMax {
                maxText = String(format: "%.0f", max)
            }
        }
    }

    private var filterLabel: String {
        if let min = costMin, let max = costMax {
            return "$\(Int(min))-\(Int(max))"
        } else if let min = costMin {
            return "$\(Int(min))+"
        } else if let max = costMax {
            return "<$\(Int(max))"
        }
        return "Price"
    }

    private func updateCostMin(_ text: String) {
        if text.isEmpty {
            costMin = nil
        } else if let value = Double(text), value >= 0 {
            costMin = value
        }
    }

    private func updateCostMax(_ text: String) {
        if text.isEmpty {
            costMax = nil
        } else if let value = Double(text), value >= 0 {
            costMax = value
        }
    }
}
