import SwiftUI

// MARK: - ViewModel

@Observable
final class EPTSViewModel {
    var age: Double = 45
    var hasDiabetes = false
    var hadPriorTransplant = false
    var isOnDialysis = false
    var dialysisYears: Double = 1

    var result: EPTSResult {
        EPTSCalculator.calculate(
            age: age,
            diabetes: hasDiabetes,
            priorTransplant: hadPriorTransplant,
            dialysisYears: isOnDialysis ? dialysisYears : 0
        )
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var vm = EPTSViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    inputCard
                    resultsCard
                    disclaimer
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("EPTS Calculator")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: Input Card

    private var inputCard: some View {
        GroupBox {
            VStack(spacing: 0) {
                ageRow
                    .padding(.vertical, 12)
                Divider()
                toggleRow("Diabetes", isOn: $vm.hasDiabetes)
                Divider()
                toggleRow("Prior Transplant", isOn: $vm.hadPriorTransplant)
                Divider()
                toggleRow("On Dialysis", isOn: $vm.isOnDialysis)

                if vm.isOnDialysis {
                    Divider()
                    dialysisYearsRow
                        .padding(.vertical, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(duration: 0.3), value: vm.isOnDialysis)
        } label: {
            Label("Recipient Characteristics", systemImage: "person.fill")
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }

    private var ageRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Patient Age")
                Spacer()
                Text("\(Int(vm.age)) yrs")
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $vm.age, in: 18...100, step: 1)
                .tint(Color.stanfordCardinal)
        }
    }

    private var dialysisYearsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Years on Dialysis")
                Spacer()
                Text(String(format: "%.1f yrs", vm.dialysisYears))
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $vm.dialysisYears, in: 0...30, step: 0.5)
                .tint(Color.stanfordCardinal)
        }
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .padding(.vertical, 10)
    }

    // MARK: Results Card

    private var resultsCard: some View {
        GroupBox {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ResultTile(
                        label: "Raw EPTS",
                        value: String(format: "%.3f", vm.result.rawScore),
                        valueColor: .primary
                    )
                    ResultTile(
                        label: "EPTS Score",
                        value: vm.result.percentile > 0 ? "\(vm.result.percentile)%" : "—",
                        valueColor: percentileColor(vm.result.percentile)
                    )
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(percentileColor(vm.result.percentile))
                        .frame(width: 8, height: 8)
                    Text(vm.result.riskTier.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
                .contentTransition(.identity)
                .animation(.spring(duration: 0.3), value: vm.result.percentile)
            }
            .padding(.vertical, 4)
        } label: {
            Label("Results", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }

    private func percentileColor(_ percentile: Int) -> Color {
        switch percentile {
        case 1...20:  return .green
        case 21...50: return .blue
        case 51...80: return .orange
        default:      return percentile == 0 ? .secondary : .red
        }
    }

    // MARK: Disclaimer

    private var disclaimer: some View {
        Text("For educational and research use only. Percentile mapping based on 2014 SRTR cohort data (published 2019). Verify against current OPTN/SRTR tables before clinical use.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 4)
    }
}

// MARK: - ResultTile

struct ResultTile: View {
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.25), value: value)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Color Extension

extension Color {
    static let stanfordCardinal = Color(red: 0.549, green: 0.082, blue: 0.082)
}

// MARK: - Preview

#Preview {
    ContentView()
}
