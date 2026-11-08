import Foundation

// MARK: - Result

struct EPTSResult: Equatable {
    let rawScore: Double
    let percentile: Int

    var riskTier: RiskTier {
        switch percentile {
        case 0...20:  return .low
        case 21...50: return .moderate
        case 51...80: return .elevated
        case 81...100: return .high
        default:      return .unknown
        }
    }

    /// Whether this candidate qualifies for KDPI <=20% kidney priority (EPTS <=20%).
    var isTopTwentyPercent: Bool {
        (0...20).contains(percentile)
    }

    enum RiskTier: Equatable {
        case unknown, low, moderate, elevated, high

        var label: String {
            switch self {
            case .unknown:  return "Score Outside Reference Range"
            case .low:      return "Top 20% — Priority Candidate"
            case .moderate: return "Moderate Expected Survival"
            case .elevated: return "Elevated Risk"
            case .high:     return "High Risk"
            }
        }

        var systemImage: String {
            switch self {
            case .unknown:  return "questionmark.circle"
            case .low:      return "checkmark.seal.fill"
            case .moderate: return "circle.fill"
            case .elevated: return "exclamationmark.triangle.fill"
            case .high:     return "exclamationmark.octagon.fill"
            }
        }
    }
}

struct EPTSHistoricalPoint: Identifiable, Equatable, Sendable {
    let referenceYear: Int
    let publicationYear: Int
    let percentile: Int
    let sourceURL: String

    var id: Int { publicationYear }
}

// MARK: - Calculator

enum EPTSCalculator {
    /// The currently published OPTN table uses the prior December 31 waitlist snapshot.
    static var mappingTableYear: String { String(EPTSMappingTables.current.publicationYear) }
    static var mappingTableCohort: String { String(EPTSMappingTables.current.referenceYear) }
    static var latestAvailableYear: String { mappingTableYear }

    // Formula: OPTN Policy 8.4. Fractional years and natural logarithm are required.
    static func calculate(
        age: Double,
        diabetes: Bool,
        priorTransplant: Bool,
        dialysisYears: Double,
        mappingTable: EPTSMappingTable = EPTSMappingTables.current
    ) -> EPTSResult {
        let raw = rawScore(
            age: age,
            diabetes: diabetes,
            priorTransplant: priorTransplant,
            dialysisYears: dialysisYears
        )
        return EPTSResult(rawScore: raw, percentile: mappingTable.percentile(for: raw))
    }

    static func rawScore(
        age: Double,
        diabetes: Bool,
        priorTransplant: Bool,
        dialysisYears: Double
    ) -> Double {
        precondition(
            age.isFinite && age >= 18 && dialysisYears.isFinite && dialysisYears >= 0,
            "EPTS requires adult age and nonnegative, finite dialysis duration"
        )

        // Use a threshold comparison instead of exact == 0 because callers may
        // derive fractional years from dates.
        let notOnDialysis = dialysisYears < 0.0001

        var score = 0.047 * max(age - 25, 0)
                  + 0.315 * log(dialysisYears + 1)

        if diabetes {
            score += -0.015 * max(age - 25, 0)
                   + (-0.099) * log(dialysisYears + 1)
                   + 1.262
            if notOnDialysis {
                score += -0.348
            }
        }

        if priorTransplant {
            score += 0.398
        }

        if diabetes && priorTransplant {
            score += -0.237
        }

        if notOnDialysis {
            score += 0.130
        }

        return score
    }

    /// Applies the same current candidate inputs to every annual mapping table.
    /// This isolates mapping drift; it does not simulate the candidate aging.
    static func historicalPercentiles(
        age: Double,
        diabetes: Bool,
        priorTransplant: Bool,
        dialysisYears: Double
    ) -> [EPTSHistoricalPoint] {
        let raw = rawScore(
            age: age,
            diabetes: diabetes,
            priorTransplant: priorTransplant,
            dialysisYears: dialysisYears
        )

        return historicalPercentiles(rawScore: raw)
    }

    /// Maps one fixed raw EPTS value through every annual reference table.
    static func historicalPercentiles(rawScore: Double) -> [EPTSHistoricalPoint] {
        precondition(rawScore.isFinite, "Historical EPTS requires a finite raw score")

        return EPTSMappingTables.all.map { table in
            EPTSHistoricalPoint(
                referenceYear: table.referenceYear,
                publicationYear: table.publicationYear,
                percentile: table.percentile(for: rawScore),
                sourceURL: table.sourceURL
            )
        }
    }
}
