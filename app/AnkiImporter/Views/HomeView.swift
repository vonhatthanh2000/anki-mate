import SwiftUI

struct HomeView: View {
    @Binding var selectedFeature: String?

    let features = [
        Feature(
            id: "boost-vocab",
            name: "BoostVocab",
            imageURL: "https://images.unsplash.com/photo-1588912914017-923900a34710?w=800"
        )
    ]

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Anki Data Importer")
                        .font(AppTheme.displayFont(size: 32))
                        .foregroundColor(AppTheme.text)

                    Text("Choose a feature to get started!")
                        .font(AppTheme.displayFont(size: 20))
                        .foregroundColor(AppTheme.text)
                        .opacity(0.9)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(AppTheme.card)
                .overlay(
                    Rectangle()
                        .stroke(AppTheme.primary, lineWidth: 4)
                        .allowsHitTesting(false)
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 32)], spacing: 32) {
                    ForEach(features) { feature in
                        FeatureCard(feature: feature) {
                            selectedFeature = feature.id
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.vertical, 32)
        }
    }
}

struct FeatureCard: View {
    let feature: Feature
    let onClick: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onClick) {
            VStack(spacing: 24) {
                AsyncImage(url: URL(string: feature.imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        AppTheme.background
                            .overlay(
                                ProgressView()
                                    .tint(AppTheme.primary)
                            )
                    }
                }
                .frame(height: 192)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(
                    Rectangle()
                        .stroke(AppTheme.primary, lineWidth: 4)
                        .allowsHitTesting(false)
                )

                Text(feature.name)
                    .font(AppTheme.displayFont(size: 24))
                    .foregroundColor(AppTheme.text)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
            .background(AppTheme.card)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.primary, lineWidth: 4)
                    .allowsHitTesting(false)
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
