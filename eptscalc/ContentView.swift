import SwiftUI

// MARK: - ViewModel

@Observable
@MainActor
final class EPTSViewModel {
    var age: Double = 45 { didSet { recalculatePrimary() } }
    var hasDiabetes = false { didSet { recalculatePrimary() } }
    var hadPriorTransplant = false { didSet { recalculatePrimary() } }
    var isOnDialysis = false { didSet { recalculatePrimary() } }
    var dialysisYears: Double = 1 { didSet { recalculatePrimary() } }

    // Scenario comparison
    var showComparison = false
    var compAge: Double = 45 { didSet { recalculateComparison() } }
    var compDiabetes = false { didSet { recalculateComparison() } }
    var compPriorTransplant = false { didSet { recalculateComparison() } }
    var compOnDialysis = false { didSet { recalculateComparison() } }
    var compDialysisYears: Double = 1 { didSet { recalculateComparison() } }

    private(set) var result = EPTSCalculator.calculate(
        age: 45,
        diabetes: false,
        priorTransplant: false,
        dialysisYears: 0
    )
    private(set) var compResult = EPTSCalculator.calculate(
        age: 45,
        diabetes: false,
        priorTransplant: false,
        dialysisYears: 0
    )
    private var isSyncingComparison = false

    private func recalculatePrimary() {
        result = EPTSCalculator.calculate(
            age: age,
            diabetes: hasDiabetes,
            priorTransplant: hadPriorTransplant,
            dialysisYears: isOnDialysis ? dialysisYears : 0
        )
    }

    private func recalculateComparison() {
        guard !isSyncingComparison else { return }
        compResult = EPTSCalculator.calculate(
            age: compAge,
            diabetes: compDiabetes,
            priorTransplant: compPriorTransplant,
            dialysisYears: compOnDialysis ? compDialysisYears : 0
        )
    }

    func syncComparison() {
        isSyncingComparison = true
        compAge = age
        compDiabetes = hasDiabetes
        compPriorTransplant = hadPriorTransplant
        compOnDialysis = isOnDialysis
        compDialysisYears = dialysisYears
        isSyncingComparison = false
        recalculateComparison()
    }
}

// MARK: - Content View

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vm = EPTSViewModel()
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    gaugeSection
                    kdpiBadge
                    inputCard
                    timeMachineLink
                    if vm.showComparison { comparisonCard }
                    provenanceFooter
                }
                .padding()
            }
            .background(backgroundGradient)
            .navigationTitle("EPTS Calculator")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
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
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        Color(.systemGroupedBackground).ignoresSafeArea()
    }

    // MARK: - Gauge Section

    private var gaugeSection: some View {
        VStack(spacing: 4) {
            if vm.showComparison {
                HStack(spacing: 16) {
                    gaugeView(result: vm.result, label: "Current")
                    gaugeView(result: vm.compResult, label: "What-If")
                }
            } else {
                gaugeView(result: vm.result, label: nil)
            }

            HStack(spacing: 5) {
                Image(systemName: vm.result.riskTier.systemImage)
                    .foregroundStyle(tierColor(vm.result.riskTier))
                    .font(.caption)
                Text(vm.result.riskTier.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .compactGlassCard()
    }

    private func gaugeView(result: EPTSResult, label: String?) -> some View {
        VStack(spacing: 2) {
            if let label { Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase).tracking(0.5) }
            Gauge(value: Double(result.percentile), in: 0...100) {
                EmptyView()
            } currentValueLabel: {
                Text("\(result.percentile)%")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(percentileColor(result.percentile))
            } minimumValueLabel: {
                Text("0").font(.caption2).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("100").font(.caption2).foregroundStyle(.secondary)
            }
            .gaugeStyle(.accessoryCircular)
            .scaleEffect(1.4)
            .frame(height: 72)
            .tint(gaugeGradient(result.percentile))

            Text("Raw: \(String(format: "%.3f", result.rawScore))")
                .font(.caption2.weight(.medium).monospacedDigit())
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Top-20% EPTS Priority")
                        .font(.subheadline.weight(.bold))
                    Text("Prioritized for KDPI ≤20% kidney offers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.green.opacity(0.3), lineWidth: 1))
            .transition(.opacity)
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
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: vm.isOnDialysis)
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
                .accessibilityLabel("Patient age")
                .accessibilityValue("\(Int(vm.age)) years")
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
                .accessibilityLabel("Years on dialysis")
                .accessibilityValue(vm.dialysisYears.formatted(.number.precision(.fractionLength(1))) + " years")
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

    // MARK: - Time Machine

    private var timeMachineLink: some View {
        NavigationLink {
            TimeMachineView(
                age: vm.age,
                diabetes: vm.hasDiabetes,
                priorTransplant: vm.hadPriorTransplant,
                dialysisYears: vm.isOnDialysis ? vm.dialysisYears : 0
            )
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                    .frame(width: 38, height: 38)
                    .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text("EPTS Time Machine")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Compare this raw score across 10 annual OPTN tables")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityHint("Shows this candidate's percentile under each annual OPTN mapping table")
        .glassCard()
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
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: vm.compOnDialysis)
        .glassCard()
        .transition(reduceMotion ? .identity : .opacity)
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
                .accessibilityLabel("Comparison patient age")
                .accessibilityValue("\(Int(vm.compAge)) years")
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
                .accessibilityLabel("Comparison years on dialysis")
                .accessibilityValue(vm.compDialysisYears.formatted(.number.precision(.fractionLength(1))) + " years")
        }
    }

    // MARK: - Provenance Footer

    private var provenanceFooter: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("OPTN mapping: \(EPTSCalculator.mappingTableYear) publication (Dec. 31, \(EPTSCalculator.mappingTableCohort) reference)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text("Pinned from the current official table. Verify against HRSA/OPTN before clinical use.")
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
        case 0...20:  return .green
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

// MARK: - Card Surface Modifiers

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color(.separator).opacity(0.25), lineWidth: 0.5)
            )
    }
}

struct CompactGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(.separator).opacity(0.25), lineWidth: 0.5)
            )
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
    func compactGlassCard() -> some View {
        modifier(CompactGlassCardModifier())
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
                refItem("OPTN Policy 8.4 — Allocation of Kidneys")
                refItem("OPTN EPTS Mapping Table — \(EPTSCalculator.mappingTableYear) publication (December 31, \(EPTSCalculator.mappingTableCohort) reference population).")
                refItem("HRSA EPTS Calculator: hrsa.gov/optn/data-calculators/allocation-calculators/epts-calculator")
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
            Text("This calculator is for educational and clinical reference purposes only. It should not be used as the sole basis for clinical decision-making. OPTN updates the mapping annually; always verify against the current official table before clinical use. This tool is not affiliated with HRSA, OPTN, UNOS, or SRTR.")
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
