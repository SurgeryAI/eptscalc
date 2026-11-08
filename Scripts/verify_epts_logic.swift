import Foundation

@main
struct VerifyEPTSLogic {
    static func main() {
        precondition(EPTSMappingTables.all.count == 10)
        precondition(EPTSMappingTables.current.referenceYear == 2025)
        precondition(EPTSMappingTables.current.publicationYear == 2026)
        precondition(EPTSCalculator.mappingTableYear == "2026")

        for table in EPTSMappingTables.all {
            precondition(table.upperBounds.count == 101)
            precondition(table.percentile(for: table.upperBounds[0]) == 0)
            precondition(table.percentile(for: table.upperBounds[0].nextUp) == 1)
            precondition(table.percentile(for: table.upperBounds[50]) == 50)
            precondition(table.percentile(for: table.upperBounds[100]) == 100)
            precondition(table.percentile(for: table.upperBounds[100].nextUp) == 100)
        }

        // Worked examples in the official April 2025 EPTS calculation guide.
        let reference2023 = EPTSMappingTables.all.first { $0.referenceYear == 2023 }!

        let example1 = EPTSCalculator.calculate(
            age: 23.5811088,
            diabetes: false,
            priorTransplant: true,
            dialysisYears: 5.0814511,
            mappingTable: reference2023
        )
        precondition(abs(example1.rawScore - 0.9666516) < 0.000001)
        precondition(example1.percentile == 9)

        let example2 = EPTSCalculator.calculate(
            age: 52.8788501,
            diabetes: false,
            priorTransplant: false,
            dialysisYears: 0,
            mappingTable: reference2023
        )
        precondition(abs(example2.rawScore - 1.440306) < 0.000001)
        precondition(example2.percentile == 18)

        let example3 = EPTSCalculator.calculate(
            age: 22.5215606,
            diabetes: true,
            priorTransplant: true,
            dialysisYears: 6.8720055,
            mappingTable: reference2023
        )
        precondition(abs(example3.rawScore - 1.8686756) < 0.000001)
        precondition(example3.percentile == 32)

        let zeroPercent = EPTSResult(rawScore: 0, percentile: 0)
        precondition(zeroPercent.isTopTwentyPercent)
        precondition(zeroPercent.riskTier == .low)

        let history = EPTSCalculator.historicalPercentiles(
            age: 45,
            diabetes: false,
            priorTransplant: false,
            dialysisYears: 0
        )
        precondition(history.count == EPTSMappingTables.all.count)
        precondition(history.last?.publicationYear == 2026)

        print("EPTS mapping verification passed")
    }
}
