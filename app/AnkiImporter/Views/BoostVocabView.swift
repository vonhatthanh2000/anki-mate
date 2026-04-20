import SwiftUI

struct BoostVocabView: View {
    @Binding var selectedFeature: String?
    @State private var wordPairs: [WordPair] = []
    @State private var currentWord: String = ""
    @State private var currentMeaning: String = ""
    @State private var paragraph: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { selectedFeature = nil }) {
                    Text("← Back to Home")
                        .font(AppTheme.displayFont(size: 16))
                        .foregroundColor(AppTheme.background)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppTheme.primary)
                        .overlay(
                            Rectangle()
                                .stroke(AppTheme.primary, lineWidth: 4)
                        )
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Text("BoostVocab - Boost your vocabulary now!")
                    .font(AppTheme.displayFont(size: 32))
                    .foregroundColor(AppTheme.text)

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(AppTheme.card)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.primary, lineWidth: 4),
                alignment: .bottom
            )

            HStack(alignment: .top, spacing: 32) {
                VStack(spacing: 24) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Word")
                                .font(AppTheme.displayFont(size: 16))
                                .foregroundColor(AppTheme.text)

                            ZStack(alignment: .leading) {
                                if currentWord.isEmpty {
                                    Text("Enter a word...")
                                        .font(AppTheme.inputFont())
                                        .foregroundColor(AppTheme.text.opacity(0.5))
                                        .padding(.horizontal, 16)
                                        .allowsHitTesting(false)
                                }

                                TextField("", text: $currentWord)
                                    .font(AppTheme.inputFont())
                                    .foregroundStyle(AppTheme.text)
                                    .tint(AppTheme.primary)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(16)
                                    .onSubmit(addWordPair)
                            }
                            .background(AppTheme.background)
                            .overlay(
                                Rectangle()
                                    .stroke(AppTheme.primary, lineWidth: 4)
                                    .allowsHitTesting(false)
                            )
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Meaning")
                                .font(AppTheme.displayFont(size: 16))
                                .foregroundColor(AppTheme.text)

                            ZStack(alignment: .leading) {
                                if currentMeaning.isEmpty {
                                    Text("Enter meaning...")
                                        .font(AppTheme.inputFont())
                                        .foregroundColor(AppTheme.text.opacity(0.5))
                                        .padding(.horizontal, 16)
                                        .allowsHitTesting(false)
                                }

                                TextField("", text: $currentMeaning)
                                    .font(AppTheme.inputFont())
                                    .foregroundStyle(AppTheme.text)
                                    .tint(AppTheme.primary)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(16)
                                    .onSubmit(addWordPair)
                            }
                            .background(AppTheme.background)
                            .overlay(
                                Rectangle()
                                    .stroke(AppTheme.primary, lineWidth: 4)
                                    .allowsHitTesting(false)
                            )
                        }
                    }
                    .padding(24)
                    .background(AppTheme.card)
                    .overlay(
                        Rectangle()
                            .stroke(AppTheme.primary, lineWidth: 4)
                            .allowsHitTesting(false)
                    )

                    Button(action: addWordPair) {
                        Text("+ Add Word")
                            .font(AppTheme.displayFont(size: 16))
                            .foregroundColor(AppTheme.background)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(AppTheme.primary)
                            .overlay(
                                Rectangle()
                                    .stroke(AppTheme.primary, lineWidth: 4)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())

                    if !wordPairs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Vocabulary")
                                .font(AppTheme.displayFont(size: 20))
                                .foregroundColor(AppTheme.text)

                            ScrollView {
                                VStack(spacing: 12) {
                                    ForEach(wordPairs) { pair in
                                        HStack(alignment: .top, spacing: 12) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(pair.word)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(AppTheme.text)

                                                Text(pair.meaning)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(AppTheme.text)
                                                    .opacity(0.8)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                            Button(action: { removeWordPair(pair.id) }) {
                                                Text("×")
                                                    .font(.system(size: 20, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 32, height: 32)
                                                    .background(AppTheme.destructive)
                                                    .overlay(
                                                        Rectangle()
                                                            .stroke(AppTheme.primary, lineWidth: 2)
                                                    )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                        .padding(12)
                                        .background(AppTheme.background)
                                        .overlay(
                                            Rectangle()
                                                .stroke(AppTheme.primary, lineWidth: 2)
                                                .allowsHitTesting(false)
                                        )
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .background(AppTheme.card)
                        .overlay(
                            Rectangle()
                                .stroke(AppTheme.primary, lineWidth: 4)
                                .allowsHitTesting(false)
                        )
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 12) {
                    Text("Write Your Paragraph")
                        .font(AppTheme.displayFont(size: 16))
                        .foregroundColor(AppTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextEditor(text: $paragraph)
                        .font(AppTheme.inputFont())
                        .foregroundColor(AppTheme.text)
                        .tint(AppTheme.primary)
                        .scrollContentBackground(.hidden)
                        .padding(16)
                        .frame(height: 128)
                        .background(AppTheme.background)
                        .overlay(
                            Rectangle()
                                .stroke(AppTheme.primary, lineWidth: 4)
                                .allowsHitTesting(false)
                        )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview with Highlights")
                            .font(AppTheme.displayFont(size: 16))
                            .foregroundColor(AppTheme.text)

                        ScrollView {
                            if paragraph.isEmpty {
                                Text("Your highlighted text will appear here...")
                                    .font(AppTheme.inputFont())
                                    .foregroundColor(AppTheme.text)
                                    .opacity(0.5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                HighlightedText(text: paragraph, wordPairs: wordPairs)
                                    .font(AppTheme.inputFont())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .padding(24)
                    .frame(maxHeight: .infinity)
                    .background(AppTheme.background)
                    .overlay(
                        Rectangle()
                            .stroke(AppTheme.secondary, lineWidth: 4)
                            .allowsHitTesting(false)
                    )
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.card)
                .overlay(
                    Rectangle()
                        .stroke(AppTheme.primary, lineWidth: 4)
                        .allowsHitTesting(false)
                )
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.ignoresSafeArea())
    }

    private func addWordPair() {
        guard !currentWord.trimmingCharacters(in: .whitespaces).isEmpty,
              !currentMeaning.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        let newPair = WordPair(word: currentWord.trimmingCharacters(in: .whitespaces),
                               meaning: currentMeaning.trimmingCharacters(in: .whitespaces))
        wordPairs.append(newPair)
        currentWord = ""
        currentMeaning = ""
    }

    private func removeWordPair(_ id: UUID) {
        wordPairs.removeAll { $0.id == id }
    }
}

struct HighlightedText: View {
    let text: String
    let wordPairs: [WordPair]

    var body: some View {
        let attributedString = highlightWords(in: text)
        return Text(attributedString)
    }

    private func highlightWords(in text: String) -> AttributedString {
        var attributedString = AttributedString(text)

        // Set default text color for entire string
        attributedString.foregroundColor = AppTheme.text

        guard !wordPairs.isEmpty else {
            return attributedString
        }

        let words = wordPairs.map { $0.word.lowercased() }
        let pattern = "\\b(\(words.joined(separator: "|")))\\b"

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
                    attributedString[attrRange].backgroundColor = AppTheme.secondary
                    attributedString[attrRange].foregroundColor = AppTheme.text
                }
            }
        }

        return attributedString
    }
}
