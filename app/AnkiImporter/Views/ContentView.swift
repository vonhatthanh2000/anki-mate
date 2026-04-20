import SwiftUI

struct ContentView: View {
    @State private var selectedFeature: String?

    var body: some View {
        Group {
            if selectedFeature == "boost-vocab" {
                BoostVocabView(selectedFeature: $selectedFeature)
            } else {
                HomeView(selectedFeature: $selectedFeature)
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
}
