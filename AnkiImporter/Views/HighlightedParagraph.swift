import SwiftUI

/// Highlights occurrences of given words in text (case-insensitive, word boundaries).
struct HighlightedParagraph: View {
    let text: String
    let words: [String]

    var body: some View {
        let attributedString = highlightWords(in: text)
        return Text(attributedString)
    }

    private func highlightWords(in text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        attributedString.foregroundColor = AppTheme.text

        guard !words.isEmpty else {
            return attributedString
        }

        let lowerWords = words.map { $0.lowercased() }
        let pattern = "\\b(\(lowerWords.joined(separator: "|")))\\b"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return attributedString
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)

        for match in matches.reversed() {
            if let range = Range(match.range, in: text) {
                if let start = AttributedString.Index(range.lowerBound, within: attributedString),
                   let end = AttributedString.Index(range.upperBound, within: attributedString) {
                    let attrRange = start..<end
                    // Bold the matched words instead of background color
                    attributedString[attrRange].inlinePresentationIntent = .stronglyEmphasized
                    attributedString[attrRange].foregroundColor = AppTheme.primary
                }
            }
        }

        return attributedString
    }
}
