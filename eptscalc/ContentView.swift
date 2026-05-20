import SwiftUI

// MARK: - ViewModel

@Observable
final class EPTSViewModel {
    var age: Double = 45
    var hasDiabetes = false
    var hadPriorTransplant = false
    var isOnDialysis = false
    var dialysisYears: Double = 1

    // Scenario comparison
    var showComparison = false
    var compAge: Double = 45
    var compDiabetes = false
    var compPriorTransplant = false
    var compOnDialysis = false
    var compDialysisYears: Double = 1

    var result: EPTSResult {
        EPTSCalculator.calculate(
            age: age,
            diabetes: hasDiabetes,
            priorTransplant: hadPriorTransplant,
            dialysisYears: isOnDialysis ? dialysisYears : 0
        )
    }

    var compResult: EPTSResult {
        EPTSCalculator.calculate(
            age: compAge,
            diabetes: compDiabetes,
            priorTransplant: compPriorTransplant,
            dialysisYears: compOnDialysis ? compDialysisYears : 0
        )
    }

    func syncComparison() {
        compAge = age
        compDiabetes = hasDiabetes
        compPriorTransplant = hadPriorTransplant
        compOnDialysis = isOnDialysis
        compDialysisYears = dialysisYears
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var vm = EPTSViewModel()
    @State private var showInfo = false
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    gaugeSection
                    kdpiBadge
                    inputCard
                    if vm.showComparison { comparisonCard }
                    provenanceFooter
                }
                .padding()
            }
            .background(backgroundGradient)
            .navigationTitle("EPTS Calculator")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { vm.showComparison.toggle(); if vm.showComparison { vm.syncComparison() } } label: {
                        Image(systemName: vm.showComparison ? "arrow.2.squarepath" : "arrow.triangle.branch")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Toggle scenario comparison")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showInfo = true } label: {
                        Image(systemName: "info.circle")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .sheet(isPresented: $showInfo) { InfoSheet() }
            .onChange(of: vm.result.percentile) { haptic.impactOccurred() }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color.teal.opacity(0.07), Color.indigo.opacity(0.05)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Gauge Section

    private var gaugeSection: some View {
        VStack(spacing: 8) {
            if vm.showComparison {
                HStack(spacing: 24) {
                    gaugeView(result: vm.result, label: "Current")
                    gaugeView(result: vm.compResult, label: "What-If")
                }
            } else {
                gaugeView(result: vm.result, label: nil)
            }

            if vm.result.percentile > 0 {
                HStack(spacing: 6) {
                    Image(systemName: vm.result.riskTier.systemImage)
                        .foregroundStyle(tierColor(vm.result.riskTier))
                        .font(.subheadline)
                    Text(vm.result.riskTier.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
                .contentTransition(.identity)
                .animation(.spring(duration: 0.3), value: vm.result.riskTier)
            }
        }
        .glassCard()
    }

    private func gaugeView(result: EPTSResult, label: String?) -> some View {
        VStack(spacing: 6) {
            if let label { Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase).tracking(0.5) }
            Gauge(value: Double(result.percentile), in: 0...100) {
                EmptyView()
            } currentValueLabel: {
                Text(result.percentile > 0 ? "\(result.percentile)%" : "—")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(percentileColor(result.percentile))
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.25), value: result.percentile)
            } minimumValueLabel: {
                Text("0").font(.caption2).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("100").font(.caption2).foregroundStyle(.secondary)
            }
            .gaugeStyle(.accessoryCircular)
            .scaleEffect(1.8)
            .frame(height: 100)
            .tint(gaugeGradient(result.percentile))

            Text("Raw: \(String(format: "%.3f", result.rawScore))")
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func gaugeGradient(_ pct: Int) -> Gradient {
        Gradient(colors: [.green, .teal, .blue, .orange, .red])
    }

    // MARK: - KDPI Badge

    @ViewBuilder
    private var kdpiBadge: some View {
        if vm.result.isTopTwentyPercent {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse, options: .repeating.speed(0.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text("KDPI ≤20% Eligible")
                        .font(.subheadline.weight(.bold))
                    Text("Priority for highest-longevity donor kidneys")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.green.opacity(0.3), lineWidth: 1))
            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
            .animation(.spring(duration: 0.4), value: vm.result.isTopTwentyPercent)
        }
    }

    // MARK: - Input Card

    private var inputCard: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Recipient Characteristics", systemImage: "person.fill")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 12)

            ageRow
            Divider().padding(.vertical, 4)
            toggleRow("Diabetes", icon: "drop.fill", isOn: $vm.hasDiabetes)
            Divider().padding(.vertical, 4)
            toggleRow("Prior Organ Transplant", icon: "arrow.triangle.2.circlepath", isOn: $vm.hadPriorTransplant)
            Divider().padding(.vertical, 4)
            toggleRow("On Dialysis", icon: "cross.vial.fill", isOn: $vm.isOnDialysis)

            if vm.isOnDialysis {
                Divider().padding(.vertical, 4)
                dialysisYearsRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(duration: 0.3), value: vm.isOnDialysis)
        .glassCard()
    }

    private var ageRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Patient Age", systemImage: "calendar")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(vm.age)) yrs")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.teal)
                    .monospacedDigit()
            }
            Slider(value: $vm.age, in: 18...100, step: 1)
                .tint(.teal)
        }
    }

    private var dialysisYearsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Years on Dialysis", systemImage: "clock.fill")
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.1f yrs", vm.dialysisYears))
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.teal)
                    .monospacedDigit()
            }
            Slider(value: $vm.dialysisYears, in: 0...30, step: 0.5)
                .tint(.teal)
        }
    }

    private func toggleRow(_ label: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(label, systemImage: icon)
                .font(.subheadline)
        }
        .tint(.teal)
        .padding(.vertical, 4)
    }

    // MARK: - Comparison Card

    private var comparisonCard: some View {
        VStack(spacing: 0) {
            HStack {
                Label("What-If Scenario", systemImage: "arrow.triangle.branch")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 12)

            compAgeRow
            Divider().padding(.vertical, 4)
            toggleRow("Diabetes", icon: "drop.fill", isOn: $vm.compDiabetes)
            Divider().padding(.vertical, 4)
            toggleRow("Prior Organ Transplant", icon: "arrow.triangle.2.circlepath", isOn: $vm.compPriorTransplant)
            Divider().padding(.vertical, 4)
            toggleRow("On Dialysis", icon: "cross.vial.fill", isOn: $vm.compOnDialysis)

            if vm.compOnDialysis {
                Divider().padding(.vertical, 4)
                compDialysisRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if vm.compResult.percentile > 0 && vm.result.percentile > 0 {
                Divider().padding(.vertical, 8)
                let diff = vm.compResult.percentile - vm.result.percentile
                HStack(spacing: 6) {
                    Image(systemName: diff > 0 ? "arrow.up.right" : diff < 0 ? "arrow.down.right" : "equal")
                        .foregroundStyle(diff > 0 ? .red : diff < 0 ? .green : .secondary)
                    Text(diff == 0 ? "No change" : "\(abs(diff))% \(diff > 0 ? "worse" : "better")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(diff > 0 ? .red : diff < 0 ? .green : .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background((diff > 0 ? Color.red : diff < 0 ? Color.green : Color.secondary).opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: diff)
            }
        }
        .animation(.spring(duration: 0.3), value: vm.compOnDialysis)
        .glassCard()
        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
    }

    private var compAgeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Patient Age", systemImage: "calendar")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(vm.compAge)) yrs")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.indigo)
                    .monospacedDigit()
            }
            Slider(value: $vm.compAge, in: 18...100, step: 1)
                .tint(.indigo)
        }
    }

    private var compDialysisRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Years on Dialysis", systemImage: "clock.fill")
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.1f yrs", vm.compDialysisYears))
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.indigo)
                    .monospacedDigit()
            }
            Slider(value: $vm.compDialysisYears, in: 0...30, step: 0.5)
                .tint(.indigo)
        }
    }

    // MARK: - Provenance Footer

    private var provenanceFooter: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("Mapping table: \(EPTSCalculator.mappingTableYear) (\(EPTSCalculator.mappingTableCohort) cohort)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text("OPTN updates this table annually. Verify against the current OPTN EPTS Calculator before clinical use.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func percentileColor(_ percentile: Int) -> Color {
        switch percentile {
        case 0:       return .secondary
        case 1...20:  return .green
        case 21...50: return .teal
        case 51...80: return .orange
        default:      return .red
        }
    }

    private func tierColor(_ tier: EPTSResult.RiskTier) -> Color {
        switch tier {
        case .unknown:  return .secondary
        case .low:      return .green
        case .moderate: return .teal
        case .elevated: return .orange
        case .high:     return .red
        }
    }
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}

// MARK: - Info Sheet

struct InfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    formulaSection
                    allocationSection
                    referencesSection
                    disclaimerSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("About EPTS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var formulaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Formula", systemImage: "function")
                .font(.headline)
            Text("The Estimated Post-Transplant Survival (EPTS) score predicts a kidney transplant candidate's expected graft longevity using four factors:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                formulaRow("Age", "0.047 × max(Age − 25, 0)")
                formulaRow("Diabetes", "+1.262 (with interaction terms)")
                formulaRow("Prior Transplant", "+0.398 (with interaction)")
                formulaRow("Dialysis", "+0.315 × ln(Years + 1)")
            }
            .font(.caption)
            .padding(12)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func formulaRow(_ label: String, _ formula: String) -> some View {
        HStack(alignment: .top) {
            Text(label).fontWeight(.semibold).frame(width: 80, alignment: .leading)
            Text(formula).foregroundStyle(.secondary)
        }
    }

    private var allocationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Kidney Allocation", systemImage: "arrow.left.arrow.right")
                .font(.headline)
            Text("Candidates with EPTS ≤ 20% receive priority for kidneys from donors with KDPI ≤ 20% (highest expected graft longevity). This \"longevity matching\" is defined in OPTN Policy 8.4.B.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var referencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("References", systemImage: "book.closed.fill")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                refItem("OPTN Policy 8.4.B — Allocation of Kidneys (2016, coefficients unchanged through 2025)")
                refItem("SRTR EPTS Mapping Table — \(EPTSCalculator.mappingTableYear) release (\(EPTSCalculator.mappingTableCohort) cohort). Latest available: \(EPTSCalculator.latestAvailableYear).")
                refItem("OPTN EPTS Calculator: optn.transplant.hrsa.gov/data/allocation-calculators/epts-calculator/")
            }
        }
    }

    private func refItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").foregroundStyle(.teal)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Disclaimer", systemImage: "exclamationmark.shield.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("This calculator is for educational and clinical reference purposes only. It should not be used as the sole basis for clinical decision-making. The percentile mapping table may be outdated — always verify against the current OPTN/SRTR tables before clinical use. This tool is not affiliated with OPTN, UNOS, or SRTR.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.orange.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
