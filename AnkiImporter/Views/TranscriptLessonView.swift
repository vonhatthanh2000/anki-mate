import SwiftUI
import UniformTypeIdentifiers

struct TranscriptLessonView: View {
    @Binding var selectedFeature: String?
    @StateObject private var workflow: TranscriptLessonWorkflow
    @State private var isShowingHistory = false
    @State private var isShowingFileImporter = false
    @State private var acquisitionTask: Task<Void, Never>?

    init(selectedFeature: Binding<String?>) {
        _selectedFeature = selectedFeature
        _workflow = StateObject(wrappedValue: TranscriptLessonWorkflow())
    }

    init(selectedFeature: Binding<String?>, workflow: TranscriptLessonWorkflow) {
        _selectedFeature = selectedFeature
        _workflow = StateObject(wrappedValue: workflow)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()
                content
            }

            if [.acquiring, .transcribing, .analyzing].contains(workflow.snapshot.phase) {
                processingOverlay
            }
        }
        .sheet(isPresented: $isShowingHistory) {
            TranscriptLessonHistoryView(
                workflow: workflow,
                isPresented: $isShowingHistory
            )
            .frame(minWidth: 680, minHeight: 520)
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            acquisitionTask = Task {
                let didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess { url.stopAccessingSecurityScopedResource() }
                    acquisitionTask = nil
                }
                await workflow.transcribeLocalFile(url)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button {
                acquisitionTask?.cancel()
                workflow.reset()
                selectedFeature = nil
            } label: {
                Text("← Back to Home")
            }
            .buttonStyle(TranscriptLessonButtonStyle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Transcript Lessons")
                    .font(AppTheme.displayFont(size: 26))
                    .foregroundColor(AppTheme.text)
                Text("Understand one English video deeply before listening again.")
                    .font(AppTheme.inputFont(size: 14))
                    .foregroundColor(AppTheme.text.opacity(0.8))
            }

            Spacer()

            Button {
                Task {
                    await workflow.loadHistory()
                    if workflow.snapshot.phase != .failed {
                        isShowingHistory = true
                    }
                }
            } label: {
                Label("Saved lessons", systemImage: "books.vertical")
            }
            .buttonStyle(TranscriptLessonButtonStyle(fill: AppTheme.actionSecondary))

            Button {
                acquisitionTask?.cancel()
                workflow.reset()
            } label: {
                Label("New lesson", systemImage: "plus")
            }
            .buttonStyle(TranscriptLessonButtonStyle())
        }
        .padding(24)
        .background(AppTheme.card)
        .overlay(
            Rectangle().stroke(AppTheme.primary, lineWidth: 4),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private var content: some View {
        if let lesson = workflow.snapshot.lesson, workflow.snapshot.phase == .ready {
            TranscriptLessonResultView(workflow: workflow, lesson: lesson)
        } else {
            transcriptEditor
        }
    }

    private var transcriptEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Start from a short video")
                    .font(AppTheme.displayFont(size: 22))
                    .foregroundColor(AppTheme.text)
                    Text("Use a public YouTube or TikTok URL, upload an authorized local file, or paste a transcript.")
                        .font(AppTheme.inputFont(size: 15))
                        .foregroundColor(AppTheme.text.opacity(0.82))
                }

                HStack(spacing: 10) {
                    TextField(
                        "https://www.youtube.com/watch?v=…",
                        text: Binding(
                            get: { workflow.snapshot.sourceURL },
                            set: { workflow.updateSourceURL($0) }
                        )
                    )
                    .textFieldStyle(TranscriptLessonTextFieldStyle())
                    Button("Get transcript") {
                        acquisitionTask = Task {
                            await workflow.acquireFromSourceURL()
                            acquisitionTask = nil
                        }
                    }
                    .buttonStyle(TranscriptLessonButtonStyle())
                    .disabled(workflow.snapshot.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Choose local file…") { isShowingFileImporter = true }
                        .buttonStyle(TranscriptLessonButtonStyle(fill: AppTheme.actionSecondary))
                }

                if let warning = workflow.snapshot.durationWarning {
                    Label(warning, systemImage: "clock.badge.exclamationmark")
                        .foregroundColor(AppTheme.primary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("2. Review the transcript")
                        .font(AppTheme.displayFont(size: 22))
                    Text("Correct names, slang, or misheard phrases. Analysis uses exactly the text you approve here.")
                        .font(AppTheme.inputFont(size: 15))
                        .foregroundColor(AppTheme.text.opacity(0.82))
                }

                TextEditor(
                    text: Binding(
                        get: { workflow.snapshot.transcript },
                        set: { workflow.updateTranscript($0) }
                    )
                )
                .font(AppTheme.inputFont(size: 16))
                .foregroundStyle(AppTheme.text)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 360)
                .background(AppTheme.editField)
                .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: 2))

                if let error = workflow.snapshot.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(AppTheme.inputFont(size: 14))
                        .foregroundColor(AppTheme.destructive)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.editField)
                        .overlay(Rectangle().stroke(AppTheme.destructive, lineWidth: 2))
                }

                if workflow.snapshot.canUseManualFallback {
                    Text(
                        workflow.snapshot.canRetryAcquisition
                            ? "You can retry acquisition, choose an authorized local file, or paste the transcript below."
                            : "Choose an authorized local file or paste the transcript below."
                    )
                        .font(AppTheme.inputFont(size: 14))
                        .foregroundColor(AppTheme.text.opacity(0.82))
                }

                HStack {
                    Text("English only · best for 1–3 minute videos")
                        .font(AppTheme.inputFont(size: 13))
                        .foregroundColor(AppTheme.text.opacity(0.72))
                    Spacer()
                    Button {
                        Task { await workflow.analyze() }
                    } label: {
                        Label("Analyze transcript", systemImage: "sparkles")
                    }
                    .buttonStyle(TranscriptLessonButtonStyle())
                    .disabled(workflow.snapshot.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(28)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.22).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().controlSize(.large)
                Text(processingMessage)
                    .font(AppTheme.inputFont(size: 16))
                    .foregroundColor(AppTheme.text)
                if workflow.snapshot.phase == .acquiring || workflow.snapshot.phase == .transcribing {
                    Button("Cancel") { acquisitionTask?.cancel() }
                        .buttonStyle(TranscriptLessonButtonStyle())
                }
            }
            .padding(28)
            .background(AppTheme.editField)
            .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: 3))
        }
    }

    private var processingMessage: String {
        switch workflow.snapshot.phase {
        case .acquiring: return "Looking for usable captions or temporary media…"
        case .transcribing: return "Transcribing the authorized local file…"
        default: return "Analyzing meaning and natural English…"
        }
    }
}

struct TranscriptLessonResultView: View {
    @ObservedObject var workflow: TranscriptLessonWorkflow
    let lesson: TranscriptLesson
    @State private var selectedItemID: String?
    @State private var answers: [String: String] = [:]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let sourceURL = lesson.sourceURL, let url = URL(string: sourceURL) {
                        Link(destination: url) {
                            Label("Open original source for replay and shadowing", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(TranscriptLessonButtonStyle(fill: AppTheme.actionSecondary))
                    }
                    meaningOverview
                    transcript(proxy: proxy)
                    languageItems
                    practice
                }
                .padding(28)
                .frame(maxWidth: 1040)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var meaningOverview: some View {
        LessonSection(title: "Meaning Overview", systemImage: "lightbulb") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(lesson.overview.summary.enumerated()), id: \.offset) { _, sentence in
                    Text(sentence)
                }
                Divider()
                LabeledContent("Main point", value: lesson.overview.mainPoint)
                if !lesson.overview.supportingIdeas.isEmpty {
                    LabeledContent(
                        "Supporting ideas",
                        value: lesson.overview.supportingIdeas.joined(separator: " · ")
                    )
                }
                LabeledContent("Tone & register", value: lesson.overview.toneAndRegister)
                ForEach(lesson.overview.contextNotes, id: \.self) { note in
                    Text(note)
                        .font(AppTheme.inputFont(size: 14))
                        .foregroundColor(AppTheme.text.opacity(0.8))
                }
            }
        }
    }

    private func transcript(proxy: ScrollViewProxy) -> some View {
        LessonSection(title: "Approved Transcript", systemImage: "text.quote") {
            Text(HighlightedTranscriptBuilder.make(transcript: lesson.approvedTranscript, items: lesson.items))
                .font(AppTheme.inputFont(size: 17))
                .lineSpacing(7)
                .textSelection(.enabled)
                .environment(
                    \.openURL,
                    OpenURLAction { url in
                        guard url.scheme == "anki-mate", let itemID = url.pathComponents.last else {
                            return .systemAction
                        }
                        selectedItemID = itemID
                        withAnimation { proxy.scrollTo(itemID, anchor: .center) }
                        return .handled
                    }
                )
        }
    }

    private var languageItems: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("High-value Natural English")
                .font(AppTheme.displayFont(size: 22))
                .foregroundColor(AppTheme.text)

            ForEach(lesson.items) { item in
                LanguageItemCard(
                    item: item,
                    isSelected: selectedItemID == item.id,
                    isExporting: workflow.snapshot.exportingItemIDs.contains(item.id),
                    export: { Task { await workflow.exportToAnki(itemID: item.id) } }
                )
                    .id(item.id)
                    .onTapGesture { selectedItemID = item.id }
            }
        }
    }

    private var practice: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Practice the most reusable items")
                .font(AppTheme.displayFont(size: 22))
                .foregroundColor(AppTheme.text)

            ForEach(lesson.exercises) { exercise in
                ExerciseCard(
                    exercise: exercise,
                    item: lesson.items.first(where: { $0.id == exercise.itemID }),
                    answer: Binding(
                        get: { answers[exercise.id, default: ""] },
                        set: { answers[exercise.id] = $0 }
                    ),
                    isEvaluating: workflow.snapshot.evaluatingExerciseIDs.contains(exercise.id),
                    latestAttempt: lesson.attempts.last(where: { $0.exerciseID == exercise.id }),
                    submit: {
                        Task {
                            await workflow.submitAnswer(
                                exerciseID: exercise.id,
                                answer: answers[exercise.id, default: ""]
                            )
                        }
                    }
                )
            }

            if let error = workflow.snapshot.errorMessage {
                Text(error)
                    .foregroundColor(AppTheme.destructive)
            }
        }
    }
}

private struct LessonSection<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(AppTheme.displayFont(size: 22))
                .foregroundColor(AppTheme.text)
            content
                .font(AppTheme.inputFont(size: 15))
                .foregroundColor(AppTheme.text)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card.opacity(0.52))
        .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: 2))
    }
}

private struct LanguageItemCard: View {
    let item: TranscriptLanguageItem
    let isSelected: Bool
    let isExporting: Bool
    let export: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.expression)
                    .font(AppTheme.inputFont(size: 19))
                    .fontWeight(.semibold)
                Spacer()
                Text(item.cefrEstimate)
                    .font(AppTheme.inputFont(size: 13))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.primary)
                    .foregroundColor(.white)
            }

            HStack {
                Text(item.primaryCategory.rawValue)
                ForEach(item.secondaryCategories, id: \.rawValue) { category in
                    Text(category.rawValue)
                }
            }
            .font(AppTheme.inputFont(size: 12))
            .foregroundColor(AppTheme.text.opacity(0.72))

            Text(item.meaningAndUsage)
            Text("In the video: “\(item.sourceExcerpt)”")
                .italic()
            Text("Why it matters: \(item.selectionRationale)")
            Text("New example: \(item.naturalExample)")
            if let vietnameseGloss = item.vietnameseGloss, !vietnameseGloss.isEmpty {
                Text("Tiếng Việt: \(vietnameseGloss)")
                    .foregroundColor(AppTheme.primary)
            }
            HStack {
                Spacer()
                Button {
                    export()
                } label: {
                    Label(
                        item.ankiNoteID == nil ? (isExporting ? "Exporting…" : "Add to Anki") : "Exported to Anki",
                        systemImage: item.ankiNoteID == nil ? "rectangle.stack.badge.plus" : "checkmark.circle.fill"
                    )
                    .frame(minWidth: 160)
                }
                .buttonStyle(TranscriptLessonButtonStyle(fill: AppTheme.actionSecondary))
                .disabled(isExporting || item.ankiNoteID != nil)
            }
        }
        .font(AppTheme.inputFont(size: 15))
        .foregroundColor(AppTheme.text)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? AppTheme.card.opacity(0.8) : AppTheme.editField)
        .overlay(Rectangle().stroke(isSelected ? AppTheme.destructive : AppTheme.primary, lineWidth: isSelected ? 3 : 1))
    }
}

private struct ExerciseCard: View {
    let exercise: LessonExercise
    let item: TranscriptLanguageItem?
    @Binding var answer: String
    let isEvaluating: Bool
    let latestAttempt: ExerciseAttempt?
    let submit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercise.kind == .recognition ? "Recognize in context" : "Use it naturally")
                .font(AppTheme.inputFont(size: 13))
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.primary)
            if let item {
                Text(item.expression).fontWeight(.semibold)
            }
            Text(exercise.prompt)
            TextField("Your answer", text: $answer, axis: .vertical)
                .textFieldStyle(TranscriptLessonTextFieldStyle())
                .lineLimit(2...5)
            HStack {
                Spacer()
                Button(action: submit) {
                    Text(isEvaluating ? "Checking…" : "Check answer")
                        .frame(minWidth: 100)
                }
                    .buttonStyle(TranscriptLessonButtonStyle())
                    .disabled(isEvaluating || answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let attempt = latestAttempt {
                VStack(alignment: .leading, spacing: 6) {
                    Text(attempt.feedback.isCorrect ? "Good work" : "Try this revision")
                        .fontWeight(.semibold)
                    Text(attempt.feedback.explanation)
                    Text("Meaning: \(attempt.feedback.meaningFeedback)")
                    Text("Correctness: \(attempt.feedback.correctnessFeedback)")
                    Text("Context: \(attempt.feedback.appropriatenessFeedback)")
                    Text("Naturalness: \(attempt.feedback.naturalnessFeedback)")
                    Text("Natural revision: \(attempt.feedback.naturalRevision)")
                        .italic()
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.card.opacity(0.38))
            }
        }
        .font(AppTheme.inputFont(size: 15))
        .foregroundColor(AppTheme.text)
        .padding(18)
        .background(AppTheme.editField)
        .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: 1))
    }
}

private enum HighlightedTranscriptBuilder {
    static func make(transcript: String, items: [TranscriptLanguageItem]) -> AttributedString {
        var attributed = AttributedString(transcript)
        for item in items {
            let nsRange = NSRange(location: item.spanStart, length: item.spanEnd - item.spanStart)
            guard let stringRange = Range(nsRange, in: transcript),
            let range = Range(stringRange, in: attributed),
            let link = URL(string: "anki-mate://lesson-item/\(item.id)") else {
                continue
            }
            attributed[range].backgroundColor = AppTheme.card
            attributed[range].foregroundColor = AppTheme.text
            attributed[range].font = .system(size: 17, weight: .semibold)
            attributed[range].link = link
        }
        return attributed
    }
}

struct TranscriptLessonHistoryView: View {
    @ObservedObject var workflow: TranscriptLessonWorkflow
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let error = workflow.snapshot.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.destructive)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.editField)
                }

                if workflow.snapshot.history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 36))
                        Text("No saved lessons")
                            .font(.title2)
                        Text("Analyze your first transcript to create a weekly lesson.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(workflow.snapshot.history) { summary in
                        Button {
                            Task {
                                await workflow.openLesson(id: summary.id)
                                if workflow.snapshot.phase == .ready {
                                    isPresented = false
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(summary.mainPoint)
                                    .font(.headline)
                                    .foregroundColor(AppTheme.text)
                                Text("\(summary.itemCount) language items · \(summary.createdAt)")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.text.opacity(0.7))
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(AppTheme.editField)
                    }
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.editField)
                    .foregroundStyle(AppTheme.text)
                }
            }
            .foregroundStyle(AppTheme.text)
            .background(AppTheme.background)
            .navigationTitle("Saved Transcript Lessons")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                        .buttonStyle(TranscriptLessonButtonStyle())
                }
            }
        }
    }
}

struct TranscriptLessonButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var fill: Color = AppTheme.actionPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.displayFont(size: 15))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(fill)
            .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: 4))
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.45)
    }
}

private struct TranscriptLessonTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(AppTheme.inputFont(size: 16))
            .foregroundStyle(AppTheme.text)
            .padding(10)
            .background(AppTheme.editField)
            .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: 2))
    }
}
