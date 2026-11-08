import Charts
import SwiftUI

struct TimeMachineView: View {
    private let rawScore: Double
    private let points: [EPTSHistoricalPoint]
    private let minimumPercentile: Int
    private let maximumPercentile: Int
    private let finalPointID: Int?
    private let currentPercentile: Int
    private let xDomain: ClosedRange<Double>
    private let axisYears: [Double]

    init(
        age: Double,
        diabetes: Bool,
        priorTransplant: Bool,
        dialysisYears: Double
    ) {
        let rawScore = EPTSCalculator.rawScore(
            age: age,
            diabetes: diabetes,
            priorTransplant: priorTransplant,
            dialysisYears: dialysisYears
        )
        let points = EPTSCalculator.historicalPercentiles(rawScore: rawScore)

        self.rawScore = rawScore
        self.points = points
        self.minimumPercentile = points.lazy.map(\.percentile).min() ?? 0
        self.maximumPercentile = points.lazy.map(\.percentile).max() ?? 100
        self.finalPointID = points.last?.id
        self.currentPercentile = points.last?.percentile ?? 0

        let firstYear = Double(points.first?.publicationYear ?? 0)
        let lastYear = Double(points.last?.publicationYear ?? 1)
        self.xDomain = (firstYear - 0.25)...max(firstYear + 1, lastYear + 0.25)

        let candidateYears = [
            points.first?.publicationYear,
            points.dropFirst(3).first?.publicationYear,
            points.dropFirst(6).first?.publicationYear,
            points.last?.publicationYear,
        ].compactMap { $0 }
        self.axisYears = Array(Set(candidateYears)).sorted().map(Double.init)
    }

    private var yDomain: ClosedRange<Double> {
        let spread = maximumPercentile - minimumPercentile
        let padding = max(2, Int(ceil(Double(spread) * 0.5)))
        let lower = max(0, minimumPercentile - padding)
        let upper = min(100, max(maximumPercentile + padding, lower + 2))
        return Double(lower)...Double(upper)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                scoreSummaryCard
                chartCard
                historyCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .contentMargins(.top, 12, for: .scrollContent)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("EPTS Time Machine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var scoreSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Fixed-score comparison", systemImage: "clock.arrow.circlepath")
                .font(.headline)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 28) {
                    currentScoreMetric
                    rawScoreMetric
                }

                VStack(alignment: .leading, spacing: 12) {
                    currentScoreMetric
                    rawScoreMetric
                }
            }

            Text("The raw score stays fixed. Only the annual OPTN reference mapping changes; the candidate does not age in this view.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var currentScoreMetric: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(currentPercentile)%")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.indigo)
                .monospacedDigit()
            Text("Current percentile")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var rawScoreMetric: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rawScore, format: .number.precision(.fractionLength(3)))
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .monospacedDigit()
            Text("Raw EPTS held constant")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("EPTS percentile over time")
                    .font(.headline)
                Text("Same raw score, each published mapping table")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Observed range: \(minimumPercentile)%–\(maximumPercentile)% · spread \(maximumPercentile - minimumPercentile) point\((maximumPercentile - minimumPercentile) == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)
            }

            Chart(points) { point in
                LineMark(
                    x: .value("Published year", Double(point.publicationYear)),
                    y: .value("EPTS percentile", point.percentile)
                )
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(.teal)

                PointMark(
                    x: .value("Published year", Double(point.publicationYear)),
                    y: .value("EPTS percentile", point.percentile)
                )
                .symbolSize(point.publicationYear == EPTSMappingTables.current.publicationYear ? 90 : 45)
                .foregroundStyle(point.publicationYear == EPTSMappingTables.current.publicationYear ? .indigo : .teal)
                .accessibilityLabel("\(point.publicationYear) mapping table")
                .accessibilityValue("EPTS \(point.percentile) percent")
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let percentile = value.as(Int.self) {
                            Text("\(percentile)%")
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: axisYears) { value in
                    AxisValueLabel {
                        if let year = value.as(Double.self) {
                            Text(verbatim: String(Int(year)))
                        }
                    }
                }
            }
            .frame(height: 230)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            ViewThatFits(in: .horizontal) {
                HStack {
                    Label("\(minimumPercentile)% lowest", systemImage: "arrow.down")
                    Spacer()
                    Label("\(maximumPercentile)% highest", systemImage: "arrow.up")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("\(minimumPercentile)% lowest", systemImage: "arrow.down")
                    Label("\(maximumPercentile)% highest", systemImage: "arrow.up")
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Annual mapping results", systemImage: "tablecells")
                .font(.headline)
                .padding(.bottom, 10)

            ForEach(points) { point in
                annualResultRow(point)

                if point.id != finalPointID {
                    Divider()
                }
            }
        }
        .glassCard()
    }

    private func annualResultRow(_ point: EPTSHistoricalPoint) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(verbatim: String(point.publicationYear))
                    .font(.headline)
                Spacer(minLength: 12)
                Text("\(point.percentile)%")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(point.publicationYear == EPTSMappingTables.current.publicationYear ? .indigo : .teal)
                    .monospacedDigit()
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    referenceLabel(for: point)
                    Spacer(minLength: 8)
                    sourceLink(for: point)
                }

                VStack(alignment: .leading, spacing: 7) {
                    referenceLabel(for: point)
                    sourceLink(for: point)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func referenceLabel(for point: EPTSHistoricalPoint) -> some View {
        Text("Dec. 31, \(String(point.referenceYear)) reference")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func sourceLink(for point: EPTSHistoricalPoint) -> some View {
        if let url = URL(string: point.sourceURL) {
            Link(destination: url) {
                Label("Official PDF", systemImage: "arrow.up.right.square")
                    .font(.caption.weight(.semibold))
            }
            .accessibilityLabel("Open the \(point.publicationYear) official source table")
        }
    }
}

#Preview {
    NavigationStack {
        TimeMachineView(
            age: 45,
            diabetes: false,
            priorTransplant: false,
            dialysisYears: 0
        )
    }
}

#Preview("Dark · Accessibility Text") {
    NavigationStack {
        TimeMachineView(
            age: 45,
            diabetes: true,
            priorTransplant: false,
            dialysisYears: 3
        )
    }
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}
