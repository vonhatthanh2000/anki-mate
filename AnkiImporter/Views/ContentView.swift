import SwiftUI

struct ContentView: View {
    @State private var selectedFeature: FeatureID?

    var body: some View {
        Group {
            if selectedFeature == .boostVocab {
                BoostVocabView(selectedFeature: $selectedFeature)
            } else if selectedFeature == .transcriptInsight {
                TranscriptInsightView(selectedFeature: $selectedFeature)
            } else {
                HomeView(selectedFeature: $selectedFeature)
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
}
