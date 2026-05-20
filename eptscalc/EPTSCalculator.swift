import Foundation

// MARK: - Result

struct EPTSResult: Equatable {
    let rawScore: Double
    let percentile: Int

    var riskTier: RiskTier {
        switch percentile {
        case 0:       return .unknown
        case 1...20:  return .low
        case 21...50: return .moderate
        case 51...80: return .elevated
        default:      return .high
        }
    }

    /// Whether this candidate qualifies for KDPI ≤20% kidney priority (EPTS ≤ 20%).
    var isTopTwentyPercent: Bool {
        percentile > 0 && percentile <= 20
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

// MARK: - Calculator

enum EPTSCalculator {

    /// Mapping table data provenance.
    /// The percentile mapping is updated annually by OPTN/SRTR.
    /// Current table: 2019 release (2014 transplant cohort).
    /// Latest available: May 21, 2025 release (Dec 31, 2024 cohort).
    /// Verify table currency at: https://optn.transplant.hrsa.gov/data/allocation-calculators/epts-calculator/
    static let mappingTableYear = "2019"
    static let mappingTableCohort = "2014"
    static let latestAvailableYear = "2025"

    // Formula: OPTN Policy 8.4.B (2016). Coefficients verified unchanged through 2025.
    static func calculate(
        age: Double,
        diabetes: Bool,
        priorTransplant: Bool,
        dialysisYears: Double
    ) -> EPTSResult {
        let raw = rawScore(age: age, diabetes: diabetes, priorTransplant: priorTransplant, dialysisYears: dialysisYears)
        return EPTSResult(rawScore: raw, percentile: lookupPercentile(raw))
    }

    static func rawScore(
        age: Double,
        diabetes: Bool,
        priorTransplant: Bool,
        dialysisYears: Double
    ) -> Double {
        // Use threshold comparison instead of exact == 0 to avoid
        // floating-point fragility when dialysis years are computed from dates.
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

    private static func lookupPercentile(_ raw: Double) -> Int {
        for (lower, upper, pct) in percentileTable where raw >= lower && raw < upper {
            return pct
        }
        return 0
    }

    // SRTR EPTS percentile mapping (2019 release, 2014 cohort).
    // Source: OPTN/SRTR Annual Data Report.
    // ⚠️ This table is updated annually by OPTN. Verify against current tables at:
    // https://optn.transplant.hrsa.gov/data/allocation-calculators/epts-calculator/
    private static let percentileTable: [(Double, Double, Int)] = [
        (0.00257670148425817, 0.27600613860724200,  1),
        (0.27600613860724200, 0.43283228414272400,  2),
        (0.43283228414272400, 0.52869325308550700,  3),
        (0.52869325308550700, 0.62126420260095800,  4),
        (0.62126420260095800, 0.70971884573612800,  5),
        (0.70971884573612800, 0.78816084873374400,  6),
        (0.78816084873374400, 0.85849985622672600,  7),
        (0.85849985622672600, 0.92016715189253000,  8),
        (0.92016715189253000, 0.97819531323437300,  9),
        (0.97819531323437300, 1.03190135974636000, 10),
        (1.03190135974636000, 1.08237261915946000, 11),
        (1.08237261915946000, 1.12933347763736000, 12),
        (1.12933347763736000, 1.17657762389856000, 13),
        (1.17657762389856000, 1.22119151713318000, 14),
        (1.22119151713318000, 1.26319693191039000, 15),
        (1.26319693191039000, 1.30319696156446000, 16),
        (1.30319696156446000, 1.34139633112181000, 17),
        (1.34139633112181000, 1.37724914442163000, 18),
        (1.37724914442163000, 1.41163179545186000, 19),
        (1.41163179545186000, 1.44806233757340000, 20),
        (1.44806233757340000, 1.48324194366980000, 21),
        (1.48324194366980000, 1.51622726810197000, 22),
        (1.51622726810197000, 1.54666217485621000, 23),
        (1.54666217485621000, 1.57645818965175000, 24),
        (1.57645818965175000, 1.60621741542667000, 25),
        (1.60621741542667000, 1.63436071184120000, 26),
        (1.63436071184120000, 1.66181565856144000, 27),
        (1.66181565856144000, 1.69058658453114000, 28),
        (1.69058658453114000, 1.71734770704997000, 29),
        (1.71734770704997000, 1.74243816915220000, 30),
        (1.74243816915220000, 1.76715917087495000, 31),
        (1.76715917087495000, 1.79228804686200000, 32),
        (1.79228804686200000, 1.81797878165640000, 33),
        (1.81797878165640000, 1.84036481861739000, 34),
        (1.84036481861739000, 1.86355167693361000, 35),
        (1.86355167693361000, 1.88571817148296000, 36),
        (1.88571817148296000, 1.90929972641805000, 37),
        (1.90929972641805000, 1.93086134318746000, 38),
        (1.93086134318746000, 1.95259174469815000, 39),
        (1.95259174469815000, 1.97379418079341000, 40),
        (1.97379418079341000, 1.99439767282683000, 41),
        (1.99439767282683000, 2.01460755586835000, 42),
        (2.01460755586835000, 2.03480287474333000, 43),
        (2.03480287474333000, 2.05439234345840000, 44),
        (2.05439234345840000, 2.07303244911557000, 45),
        (2.07303244911557000, 2.09167898699521000, 46),
        (2.09167898699521000, 2.10976349531462000, 47),
        (2.10976349531462000, 2.12745174537988000, 48),
        (2.12745174537988000, 2.14518255841735000, 49),
        (2.14518255841735000, 2.16312841333468000, 50),
        (2.16312841333468000, 2.18085496975943000, 51),
        (2.18085496975943000, 2.19801405689050000, 52),
        (2.19801405689050000, 2.21563570431742000, 53),
        (2.21563570431742000, 2.23222297897455000, 54),
        (2.23222297897455000, 2.24847160112197000, 55),
        (2.24847160112197000, 2.26441440998692000, 56),
        (2.26441440998692000, 2.28039573400228000, 57),
        (2.28039573400228000, 2.29686281598644000, 58),
        (2.29686281598644000, 2.31339288158795000, 59),
        (2.31339288158795000, 2.33013641832398000, 60),
        (2.33013641832398000, 2.34617369792562000, 61),
        (2.34617369792562000, 2.36229089664613000, 62),
        (2.36229089664613000, 2.37770283782016000, 63),
        (2.37770283782016000, 2.39421023872010000, 64),
        (2.39421023872010000, 2.41131006831821000, 65),
        (2.41131006831821000, 2.42649345532755000, 66),
        (2.42649345532755000, 2.44352268944697000, 67),
        (2.44352268944697000, 2.46011318338170000, 68),
        (2.46011318338170000, 2.47634013644055000, 69),
        (2.47634013644055000, 2.49268744208924000, 70),
        (2.49268744208924000, 2.50857263799637000, 71),
        (2.50857263799637000, 2.52583778234086000, 72),
        (2.52583778234086000, 2.54390829670501000, 73),
        (2.54390829670501000, 2.56161054072553000, 74),
        (2.56161054072553000, 2.57894137399090000, 75),
        (2.57894137399090000, 2.59663231082328000, 76),
        (2.59663231082328000, 2.61388901051856000, 77),
        (2.61388901051856000, 2.63133443179758000, 78),
        (2.63133443179758000, 2.65054449620355000, 79),
        (2.65054449620355000, 2.66933473066496000, 80),
        (2.66933473066496000, 2.68890232248550000, 81),
        (2.68890232248550000, 2.70812617315422000, 82),
        (2.70812617315422000, 2.72780795446186000, 83),
        (2.72780795446186000, 2.74820970976818000, 84),
        (2.74820970976818000, 2.76906420988327000, 85),
        (2.76906420988327000, 2.78888558594797000, 86),
        (2.78888558594797000, 2.81146563326247000, 87),
        (2.81146563326247000, 2.83219421078201000, 88),
        (2.83219421078201000, 2.85531932264917000, 89),
        (2.85531932264917000, 2.87848390054667000, 90),
        (2.87848390054667000, 2.90297098761440000, 91),
        (2.90297098761440000, 2.92749267798889000, 92),
        (2.92749267798889000, 2.95479360567564000, 93),
        (2.95479360567564000, 2.98381273967826000, 94),
        (2.98381273967826000, 3.01691611323854000, 95),
        (3.01691611323854000, 3.05320066522380000, 96),
        (3.05320066522380000, 3.09584954793187000, 97),
        (3.09584954793187000, 3.15310429973011000, 98),
        (3.15310429973011000, 3.24144654837697000, 99),
        (3.24144654837697000, 3.83903189127001000, 100),
        (3.83903189127001000, .greatestFiniteMagnitude, 100),
    ]
}
