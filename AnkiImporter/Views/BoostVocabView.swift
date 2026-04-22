import SwiftUI

struct BoostVocabView: View {
    @Binding var selectedFeature: String?
    @State private var wordPairs: [WordPair] = []
    @State private var currentWord: String = ""
    @State private var currentMeaning: String = ""
    @State private var paragraph: String = ""
    @State private var submitMessage: String?
    @State private var submitError = false
    @State private var isSubmitting = false
    @State private var isSendingToAnki = false
    @State private var showSavedBatches = false
    @State private var editingWordPairID: UUID?

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

                Button(action: { showSavedBatches = true }) {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.background)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.card)
                        .overlay(
                            Rectangle()
                                .stroke(AppTheme.primary, lineWidth: 4)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(AppTheme.card)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.primary, lineWidth: 4),
                alignment: .bottom
            )

            HStack(alignment: .top, spacing: 24) {
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

                    HStack(spacing: 16) {
                        Button(action: addWordPair) {
                            Text(editingWordPairID == nil ? "+ Add Word" : "Update Word")
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
                        .disabled(isSubmitting || isSendingToAnki)

                        Button(action: submitBatch) {
                            Text(isSubmitting ? "Submitting..." : "Submit")
                                .font(AppTheme.displayFont(size: 16))
                                .foregroundColor(AppTheme.background)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(AppTheme.secondary)
                                .overlay(
                                    Rectangle()
                                        .stroke(AppTheme.primary, lineWidth: 4)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isSubmitting || isSendingToAnki || wordPairs.isEmpty)

                        Button(action: sendToAnki) {
                            Text(isSendingToAnki ? "Anki…" : "Send to Anki")
                                .font(AppTheme.displayFont(size: 16))
                                .foregroundColor(AppTheme.background)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(AppTheme.card)
                                .overlay(
                                    Rectangle()
                                        .stroke(AppTheme.primary, lineWidth: 4)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isSubmitting || isSendingToAnki || wordPairs.isEmpty)
                    }

                    if let submitMessage {
                        Text(submitMessage)
                            .font(AppTheme.inputFont(size: 14))
                            .foregroundColor(submitError ? AppTheme.destructive : AppTheme.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

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

                                            Button(action: { beginEditingWordPair(pair) }) {
                                                Image(systemName: "pencil")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(AppTheme.background)
                                                    .frame(width: 32, height: 32)
                                                    .background(AppTheme.secondary)
                                                    .overlay(
                                                        Rectangle()
                                                            .stroke(AppTheme.primary, lineWidth: 2)
                                                    )
                                            }
                                            .buttonStyle(PlainButtonStyle())

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
                            .frame(maxHeight: .infinity, alignment: .top)
                        }
                        .padding(24)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .background(AppTheme.card)
                        .overlay(
                            Rectangle()
                                .stroke(AppTheme.primary, lineWidth: 4)
                                .allowsHitTesting(false)
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

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
                        .frame(height: 230)
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
                        .padding(16)
                        .frame(height: 230)
                        .background(AppTheme.background)
                        .overlay(
                            Rectangle()
                                .stroke(AppTheme.primary, lineWidth: 4)
                                .allowsHitTesting(false)
                        )
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
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
        .sheet(isPresented: $showSavedBatches) {
            SavedBatchesWindow()
        }
    }

    private func addWordPair() {
        let trimmedWord = currentWord.trimmingCharacters(in: .whitespaces)
        let trimmedMeaning = currentMeaning.trimmingCharacters(in: .whitespaces)

        guard !trimmedWord.isEmpty, !trimmedMeaning.isEmpty else {
            return
        }

        if let editingWordPairID,
            let index = wordPairs.firstIndex(where: { $0.id == editingWordPairID })
        {
            wordPairs[index].word = trimmedWord
            wordPairs[index].meaning = trimmedMeaning
            submitMessage = "Updated \(trimmedWord)"
            submitError = false
            self.editingWordPairID = nil
        } else {
            let newPair = WordPair(word: trimmedWord, meaning: trimmedMeaning)
            wordPairs.append(newPair)
        }

        currentWord = ""
        currentMeaning = ""
    }

    private func removeWordPair(_ id: UUID) {
        wordPairs.removeAll { $0.id == id }
        if editingWordPairID == id {
            editingWordPairID = nil
            currentWord = ""
            currentMeaning = ""
        }
    }

    private func beginEditingWordPair(_ pair: WordPair) {
        editingWordPairID = pair.id
        currentWord = pair.word
        currentMeaning = pair.meaning
        submitMessage = nil
    }

    private func submitBatch() {
        Task { @MainActor in
            isSubmitting = true
            submitMessage = nil
            submitError = false

            do {
                let words = wordPairs.map {
                    BatchWordInput(
                        word: $0.word,
                        meaning: $0.meaning,
                        wordType: "",
                        example1: "",
                        example2: ""
                    )
                }
                let batchID = try await SupabaseStore.shared.saveBatch(
                    words: words,
                    paragraph: paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                submitMessage = "Saved batch #\(batchID)"
                wordPairs = []
                paragraph = ""
            } catch {
                submitError = true
                submitMessage = error.localizedDescription
            }

            isSubmitting = false
        }
    }

    private func sendToAnki() {
        Task { @MainActor in
            isSendingToAnki = true
            submitMessage = "Starting…"
            submitError = false
            defer { isSendingToAnki = false }

            let pairs = wordPairs

            // Open Anki first
            submitMessage = "Opening Anki…"
            AnkiConnectClient.openAnki()

            var successCount = 0
            var failedWords: [String] = []

            for (index, pair) in pairs.enumerated() {
                submitMessage = "Processing \(index + 1)/\(pairs.count): \(pair.word)…"

                do {
                    // Call Python agent to enrich the word data
                    let enriched = try await VocabAgentClient.enrichWord(
                        word: pair.word,
                        meaning: pair.meaning
                    )

                    // Send enriched data to Anki
                    _ = try await AnkiConnectClient.addNote(
                        word: enriched.word,
                        meaning: enriched.meaning,
                        wordType: enriched.wordType,
                        example1: enriched.example1,
                        example2: enriched.example2
                    )

                    successCount += 1
                } catch {
                    failedWords.append(pair.word)
                    print("Failed to process '\(pair.word)': \(error.localizedDescription)")
                    // Continue with next word
                }
            }

            if failedWords.isEmpty {
                submitMessage = "Sent \(successCount) note(s) to Anki ✓"
            } else {
                submitMessage =
                    "Sent \(successCount), failed: \(failedWords.joined(separator: ", "))"
                submitError = true
            }
        }
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

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        else {
            return attributedString
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)

        for match in matches.reversed() {
            if let range = Range(match.range, in: text) {
                if let start = AttributedString.Index(range.lowerBound, within: attributedString),
                    let end = AttributedString.Index(range.upperBound, within: attributedString)
                {
                    let attrRange = start..<end
                    attributedString[attrRange].inlinePresentationIntent = .stronglyEmphasized
                    attributedString[attrRange].foregroundColor = AppTheme.text
                }
            }
        }

        return attributedString
    }
}
