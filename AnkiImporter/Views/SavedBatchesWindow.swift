import SwiftUI

struct SavedBatchesWindow: View {
    @Environment(\.dismiss) private var dismiss
    @State private var batches: [SavedBatch] = []
    @State private var selectedBatch: SavedBatch?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var dateFilter: DateFilter = .all
    @State private var sendingBatchID: Int64?
    @State private var sendStatusMessage: String?

    private var displayBatches: [SavedBatch] {
        batches
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Text("← Back")
                        .font(AppTheme.displayFont(size: 16))
                        .foregroundColor(AppTheme.background)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(AppTheme.primary)
                        .overlay(
                            Rectangle()
                                .stroke(AppTheme.primary, lineWidth: 4)
                        )
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Text("Saved Batches")
                    .font(AppTheme.displayFont(size: 28))
                    .foregroundColor(AppTheme.text)

                Spacer()

                Picker("Filter", selection: Binding(
                    get: { dateFilter },
                    set: { newValue in
                        dateFilter = newValue
                        reload()
                    }
                )) {
                    ForEach(DateFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
                .tint(AppTheme.primary)

                Spacer()

                Button(action: reload) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.background)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.secondary)
                        .overlay(
                            Rectangle()
                                .stroke(AppTheme.primary, lineWidth: 4)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(20)
            .background(AppTheme.card)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.primary, lineWidth: 4),
                alignment: .bottom
            )

            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(AppTheme.primary)
                Spacer()
            } else if let errorMessage {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.destructive)
                    Text(errorMessage)
                        .font(AppTheme.inputFont(size: 16))
                        .foregroundColor(AppTheme.destructive)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                Spacer()
            } else if displayBatches.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 56))
                        .foregroundColor(AppTheme.text.opacity(0.4))
                    if dateFilter == .all {
                        Text("No saved batches yet")
                            .font(AppTheme.displayFont(size: 20))
                            .foregroundColor(AppTheme.text.opacity(0.6))
                        Text("Create your first batch by adding words and clicking Submit")
                            .font(AppTheme.inputFont(size: 14))
                            .foregroundColor(AppTheme.text.opacity(0.5))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("No batches in \(dateFilter.rawValue.lowercased())")
                            .font(AppTheme.displayFont(size: 20))
                            .foregroundColor(AppTheme.text.opacity(0.6))
                        Text("Try selecting a different time range")
                            .font(AppTheme.inputFont(size: 14))
                            .foregroundColor(AppTheme.text.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(32)
                Spacer()
            } else {
                HStack(spacing: 0) {
                    List(displayBatches, selection: $selectedBatch) { batch in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Batch #\(batch.id)")
                                    .font(AppTheme.displayFont(size: 16))
                                    .foregroundColor(selectedBatch?.id == batch.id ? AppTheme.background : AppTheme.text)
                                Text(batch.createdAt)
                                    .font(AppTheme.inputFont(size: 12))
                                    .foregroundColor(selectedBatch?.id == batch.id ? AppTheme.background.opacity(0.8) : AppTheme.text.opacity(0.7))
                                Text("\(batch.words.count) words")
                                    .font(AppTheme.inputFont(size: 12))
                                    .foregroundColor(selectedBatch?.id == batch.id ? AppTheme.background.opacity(0.7) : AppTheme.text.opacity(0.6))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(selectedBatch?.id == batch.id ? AppTheme.background : AppTheme.primary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(selectedBatch?.id == batch.id ? AppTheme.primary : Color.clear)
                        .tag(batch)
                    }
                    .frame(width: 260)
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.background)

                    Rectangle()
                        .fill(AppTheme.primary)
                        .frame(width: 4)

                    if let batch = selectedBatch ?? displayBatches.first {
                        batchDetailView(batch)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear(perform: reload)
    }

    @ViewBuilder
    private func batchDetailView(_ batch: SavedBatch) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Batch #\(batch.id)")
                            .font(AppTheme.displayFont(size: 26))
                            .foregroundColor(AppTheme.text)
                        Text("Created: \(batch.createdAt)")
                            .font(AppTheme.inputFont(size: 14))
                            .foregroundColor(AppTheme.text.opacity(0.7))
                    }
                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        if let sendingBatchID, sendingBatchID == batch.id {
                            Text("Sending…")
                                .font(AppTheme.inputFont(size: 13))
                                .foregroundColor(AppTheme.secondary)
                        } else if let sendStatusMessage, sendingBatchID == nil {
                            Text(sendStatusMessage)
                                .font(AppTheme.inputFont(size: 13))
                                .foregroundColor(AppTheme.primary)
                        }

                        Button(action: { sendBatchToAnki(batch) }) {
                            Text(sendingBatchID == batch.id ? "Sending…" : "Send to Anki")
                                .font(AppTheme.displayFont(size: 14))
                                .foregroundColor(AppTheme.background)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(batch.words.isEmpty ? AppTheme.text.opacity(0.3) : AppTheme.card)
                                .overlay(
                                    Rectangle()
                                        .stroke(AppTheme.primary, lineWidth: 3)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(batch.words.isEmpty || sendingBatchID != nil)
                    }
                }
                .padding(24)
                .background(AppTheme.card)
                .overlay(
                    Rectangle()
                        .stroke(AppTheme.primary, lineWidth: 4)
                        .allowsHitTesting(false)
                )

                VStack(alignment: .leading, spacing: 16) {
                    Text("Words (\(batch.words.count))")
                        .font(AppTheme.displayFont(size: 20))
                        .foregroundColor(AppTheme.text)

                    if batch.words.isEmpty {
                        Text("No words in this batch")
                            .font(AppTheme.inputFont())
                            .foregroundColor(AppTheme.text.opacity(0.5))
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(batch.words) { word in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(word.word)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(AppTheme.text)
                                        if !word.wordType.isEmpty {
                                            Text("(\(word.wordType))")
                                                .font(AppTheme.inputFont(size: 13))
                                                .foregroundColor(AppTheme.secondary)
                                        }
                                        Spacer()
                                    }

                                    Text(word.meaning)
                                        .font(AppTheme.inputFont(size: 15))
                                        .foregroundColor(AppTheme.text.opacity(0.9))

                                    if !word.example1.isEmpty || !word.example2.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            if !word.example1.isEmpty {
                                                Text("Ex. 1: \(word.example1)")
                                                    .font(AppTheme.inputFont(size: 13))
                                                    .foregroundColor(AppTheme.text.opacity(0.7))
                                            }
                                            if !word.example2.isEmpty {
                                                Text("Ex. 2: \(word.example2)")
                                                    .font(AppTheme.inputFont(size: 13))
                                                    .foregroundColor(AppTheme.text.opacity(0.7))
                                            }
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.background)
                                .overlay(
                                    Rectangle()
                                        .stroke(AppTheme.primary, lineWidth: 3)
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

                VStack(alignment: .leading, spacing: 16) {
                    Text("Preview with Highlights")
                        .font(AppTheme.displayFont(size: 20))
                        .foregroundColor(AppTheme.text)

                    if batch.paragraph.isEmpty {
                        Text("No paragraph saved with this batch")
                            .font(AppTheme.inputFont())
                            .foregroundColor(AppTheme.text.opacity(0.5))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.background)
                            .overlay(
                                Rectangle()
                                    .stroke(AppTheme.primary, lineWidth: 3)
                                    .allowsHitTesting(false)
                            )
                    } else if batch.words.isEmpty {
                        Text(batch.paragraph)
                            .font(AppTheme.inputFont())
                            .foregroundColor(AppTheme.text)
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(AppTheme.background)
                            .overlay(
                                Rectangle()
                                    .stroke(AppTheme.primary, lineWidth: 3)
                                    .allowsHitTesting(false)
                            )
                    } else {
                        HighlightedParagraph(
                            text: batch.paragraph,
                            words: batch.words.map { $0.word }
                        )
                        .font(AppTheme.inputFont())
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(AppTheme.background)
                        .overlay(
                            Rectangle()
                                .stroke(AppTheme.primary, lineWidth: 3)
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
            }
            .padding(24)
        }
    }

    private func reload() {
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                batches = try BatchStore.shared.loadSavedBatches(dateFilter: dateFilter)
                if selectedBatch == nil || !batches.contains(where: { $0.id == selectedBatch?.id }) {
                    selectedBatch = batches.first
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func sendBatchToAnki(_ batch: SavedBatch) {
        Task { @MainActor in
            sendingBatchID = batch.id
            sendStatusMessage = "Starting…"
            defer {
                sendingBatchID = nil
            }

            do {
                // Open Anki first
                sendStatusMessage = "Opening Anki…"
                AnkiConnectClient.openAnki()

                var successCount = 0
                var failedWords: [String] = []

                for (index, word) in batch.words.enumerated() {
                    sendStatusMessage = "Processing \(index + 1)/\(batch.words.count): \(word.word)…"

                    do {
                        // Call Python agent to enrich the word data
                        let enriched = try await VocabAgentClient.enrichWord(
                            word: word.word,
                            meaning: word.meaning
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
                        failedWords.append(word.word)
                        print("Failed to process '\(word.word)': \(error.localizedDescription)")
                        // Continue with next word
                    }
                }

                if failedWords.isEmpty {
                    sendStatusMessage = "Sent \(successCount) note(s) ✓"
                } else {
                    sendStatusMessage = "Sent \(successCount), failed: \(failedWords.joined(separator: ", "))"
                }

            } catch {
                sendStatusMessage = "Failed: \(error.localizedDescription)"
            }
        }
    }
}