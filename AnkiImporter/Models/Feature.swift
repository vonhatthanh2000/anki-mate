import Foundation

enum FeatureID: String {
    case boostVocab = "boost-vocab"
    case transcriptInsight = "transcript-insight"
}

struct Feature: Identifiable {
    let id: FeatureID
    let name: String
    let imageURL: String
}
