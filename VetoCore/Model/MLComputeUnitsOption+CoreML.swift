import CoreML

extension MLComputeUnitsOption {
    var mlValue: MLComputeUnits {
        switch self {
        case .all: return .all
        case .cpuOnly: return .cpuOnly
        case .cpuAndNeuralEngine: return .cpuAndNeuralEngine
        }
    }
}
