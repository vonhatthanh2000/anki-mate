# Transcript Insight — UI Design

Status: Draft for UI implementation  
Scope: Native macOS SwiftUI only. Transcript retrieval, speech-to-text, lesson generation, persistence, and Anki integration are described as UI contracts but are not implemented here.

## 1. Product intent

Transcript Insight turns a short YouTube or TikTok video into a focused listening-comprehension lesson for a B2+ English learner.

The primary flow is:

1. Paste a YouTube or TikTok URL.
2. Select **Get Insight**.
3. Use the platform transcript when one is available.
4. Otherwise, automatically transcribe the audio with speech-to-text.
5. Show the transcript.
6. Analyze that transcript and show a lesson built around the most useful language.
7. Practice the strongest items, optionally export selected items to Anki, and open the original video for another listen.

The first version should feel like a sibling of BoostVocab: the same header, two-column workspace, rectangular bordered cards, Coastal Calm colors, typography, spacing, and button hierarchy.

## 2. Design principles

- Keep the happy path to one field and one primary action.
- Hide acquisition complexity by default. The user should not need to choose between captions and speech-to-text.
- Make system activity legible. A long-running task must say what stage it is in.
- Preserve partial success. If a transcript succeeds but lesson analysis fails, keep the transcript visible and let the user retry only the lesson.
- Make the transcript inspectable and editable. A corrected transcript can become the input for regenerating the lesson.
- Prefer 6–10 high-value language items over exhaustive extraction.
- Treat the transcript and lesson as scaffolding; the learning loop ends by listening to the source again.
- Match BoostVocab before introducing new visual language.

## 3. Information architecture

Use the same page skeleton as `BoostVocabView`:

- Full-window sandy beige background.
- Fixed top header.
- Main content padded by 32 points.
- Two equal-width columns separated by 24 points.
- Cards use seafoam fill and a 4-point ocean-blue rectangular border.

```text
+----------------------------------------------------------------------------------+
| [<- Back to Home]       Transcript Insight — Learn from any video       [History] |
+----------------------------------------------------------------------------------+
|                                32 pt page padding                                 |
| +--------------------------------------+  +--------------------------------------+ |
| | Video URL                            |  | Your Lesson                          | |
| | [ Paste YouTube or TikTok URL...   ] |  |                                      | |
| | [             Get Insight          ] |  |  What this video says                | |
| +--------------------------------------+  |  ...                                 | |
|                                         |  |                                      | |
| +--------------------------------------+  |  Language to notice (6–10)           | |
| | Transcript              [Copy] [Edit]|  |  [ ] expression · Collocation · C1   | |
| | Source: YouTube captions             |  |      meaning, excerpt, rationale     | |
| |                                      |  |                                      | |
| | Scrollable transcript text...        |  |  Practice (3–5 reusable items)       | |
| |                                      |  |                                      | |
| |                         [Re-analyze]  |  |  recognition + typed production      | |
| +--------------------------------------+  |                                      | |
|                                         |  | [Send to Anki] [Listen Again]        | |
|                                         | +--------------------------------------+ |
+----------------------------------------------------------------------------------+
```

### 3.1 Header

Mirror the BoostVocab header exactly:

- Left: **← Back to Home** button, 24-point horizontal and 12-point vertical padding.
- Center: **Transcript Insight — Learn from any video**, using `AppTheme.displayFont(size: 32)`.
- Right: 48 × 48 history button using `clock.arrow.circlepath`.
- Keep the right button present even before history is implemented; in the initial UI-only build it may be disabled with a tooltip reading “History coming soon.” This maintains the centered title and the same silhouette as BoostVocab.

### 3.2 Left column: source and transcript

#### URL card

Contents, top to bottom:

1. Label: **Video URL**.
2. Single-line URL field.
   - Placeholder: **Paste a YouTube or TikTok URL...**
   - Permit normal macOS paste behavior.
   - Pressing Return performs the primary action when the URL is valid.
3. Inline validation or status message, only when needed.
4. Full-width primary button: **Get Insight**.

Validation rules represented by the UI:

- Blank: button disabled; no error shown before interaction.
- Malformed URL: **Enter a valid video URL.**
- Unsupported host: **Use a YouTube or TikTok link.**
- Supported YouTube forms include standard video, Shorts, and shortened links.
- TikTok share links may be redirected before processing; the UI continues to show the URL the user pasted.

During processing, keep the URL visible but disable editing and replace the button label with the active stage:

- **Checking for transcript...**
- **Transcribing audio...**
- **Creating your lesson...**

Show a `ProgressView` beside the stage label. Add a secondary **Cancel** text button below it when cancellation is supported.

If best-effort URL acquisition fails, expand a recovery area inside this card:

- **Choose Media File...** for a local audio/video file the learner owns or is authorized to use.
- **Paste Transcript** to reveal a multiline transcript input.
- Keep **Try URL Again** available.

These are fallback paths, not competing choices in the initial empty state. This keeps the common URL flow simple while preserving an escape hatch when a platform changes or content is inaccessible.

#### Transcript card

The transcript card fills the remaining height of the left column.

Header row:

- Left: **Transcript**.
- Under or beside the title: a compact source label:
  - **YouTube captions**
  - **TikTok captions**
  - **Speech-to-text**
- Right: icon buttons for **Copy** and **Edit**. Use tooltips because icon meaning is not sufficient by itself.

Body:

- Scrollable selectable text.
- Use `AppTheme.inputFont(size: 16)` with comfortable line spacing.
- Use sandy beige inside the transcript surface with a 4-point primary border.
- Preserve paragraph breaks. Do not expose timestamp data in v1.
- In edit mode, replace selectable text with a `TextEditor`, and replace **Edit** with **Done**.
- If edits make the visible lesson stale, show: **Transcript changed. Re-analyze to update the lesson.**
- Show a full-width **Re-analyze Lesson** secondary button at the bottom only when the transcript has changed or lesson generation has failed.

### 3.3 Right column: lesson

Use one full-height seafoam card titled **Your Lesson**. Its inner content scrolls independently, while the final actions remain visible in a footer when practical.

The v1 lesson has four predictable sections:

1. **What This Video Says** — a short comprehension summary, not a generic long-form recap.
2. **Language to Notice** — 6–10 high-value items across vocabulary, idiom, phrasal verb, collocation, slang, and grammar pattern. Categories have no quota and may be absent.
3. **Practice** — recognition and production tasks for the 3–5 most reusable items.
4. **Listen Again** — a short prompt and button that opens the original URL in YouTube or TikTok.

Each section uses a bordered sandy-beige sub-card. Predictable section order makes generated content easier to scan and gives the future analysis response a stable presentation contract.

Each language-item row/card includes:

- Selection checkbox for later Anki export.
- Expression or grammar pattern as the primary label.
- Category chip and estimated CEFR chip; include “estimated” in the CEFR tooltip or accessibility description.
- Meaning and usage explanation.
- Original source excerpt.
- New natural example.
- **Why this matters** selection rationale.

Cards are expanded by default for the first three items and collapsed for the remainder. **Expand All** and **Collapse All** text actions sit beside the section title. Avoid horizontal card layouts that compress longer explanations.

The lesson footer contains:

- Secondary action: **Send Selected to Anki**. Disabled until an item is selected. This targets the dedicated Natural English note type, not the BoostVocab word schema.
- Primary action: **Open Video and Listen Again**. Opens the source platform; no embedded playback is added.

Practice is shown inline beneath the language list, not in a modal. Recognition comes first, followed by a typed production response. Production feedback reserves space for meaning, correctness, contextual fit, naturalness, and a suggested revision. Spoken answers are deferred.

## 4. Screen states

The view should have one explicit state enum instead of several loosely related booleans.

| State | Left column | Right column | Allowed actions |
|---|---|---|---|
| Empty | URL card; transcript placeholder | Lesson placeholder | Paste/type URL |
| Invalid URL | Inline URL error | Lesson placeholder | Correct URL |
| Fetching transcript | URL locked; progress stage; transcript skeleton | Lesson placeholder | Cancel, when supported |
| Transcribing | URL locked; speech-to-text stage; transcript skeleton | Lesson placeholder | Cancel, when supported |
| Analyzing | Transcript visible and selectable | Lesson skeleton | Copy transcript; cancel analysis when supported |
| Complete | Transcript and source visible | Language items, practice, and listen-again action visible | Copy, edit, re-analyze, select/export items, practice, open source |
| Transcript failure | Error plus upload/paste fallbacks | Lesson placeholder | Retry; change URL; choose authorized media; paste transcript |
| Lesson failure | Transcript remains visible | Analysis error | Retry lesson; edit transcript; copy transcript |

### Empty placeholders

Transcript card:

> Your transcript will appear here after you add a video link.

Lesson card:

> Your lesson will be created from the transcript.

### Error language

Use specific, actionable copy:

- Video unavailable: **This video is unavailable or private. Try another link.**
- Captions unavailable and audio cannot be accessed: **We couldn’t access captions or audio for this video.**
- Speech-to-text failed: **We couldn’t transcribe this video. Try again.**
- Lesson generation failed: **The transcript is ready, but the lesson couldn’t be created.**
- Network failure: **Check your internet connection and try again.**

Never discard a successful transcript because a later stage fails.

For URL acquisition failure, follow the error with: **You can choose a media file you’re allowed to use or paste a transcript instead.**

## 5. Interaction details

### Starting a new link

When a completed result is visible and the user replaces the URL, do not immediately erase the old result. Clear it only after the new URL passes validation and processing begins. This prevents accidental loss from an incomplete paste.

### Editing the transcript

- **Edit** enters a local edit mode.
- **Done** saves the text in view state.
- If the user tries to analyze an empty edited transcript, disable the action and show **Transcript cannot be empty.**
- Re-analysis updates the lesson but does not reacquire the transcript.

### Copy feedback

After copying, temporarily replace the copy icon with a checkmark and expose **Transcript copied** to accessibility APIs. Avoid a modal alert.

### Lesson item selection and Anki export

- Selection is per language item, not per exercise.
- **Select recommended** selects the 3–5 items already ranked as most reusable.
- Show a count in the button label, for example **Send 3 to Anki**.
- Export feedback follows BoostVocab’s inline status pattern.
- The UI contract assumes a Natural English note with expression/pattern, category, meaning and usage, source excerpt, new example, CEFR estimate, and source URL.
- Note-type setup, duplicate handling, and transport are implementation work, but their error states must not remove the lesson.

### Keyboard and focus

- Initial focus goes to the URL field.
- Return in the URL field triggers **Get Insight**.
- Escape exits transcript edit mode without applying uncommitted edits; this requires keeping an edit buffer.
- All icon buttons must have accessibility labels and Help tooltips.

## 6. Visual specification

Reuse `AppTheme` without adding colors for v1:

| Role | Existing token |
|---|---|
| Window and inner surfaces | `AppTheme.background` |
| Cards and header | `AppTheme.card` |
| Borders and primary action | `AppTheme.primary` |
| Headings and body text | `AppTheme.text` |
| Recoverable errors | `AppTheme.destructive` |

Spacing and sizing:

- Window minimum remains 1200 × 800.
- Header padding: 24.
- Page padding: 32.
- Column gap: 24.
- Card internal padding: 24.
- Major vertical gap: 24.
- Label-to-control gap: 12.
- Button height comes from 16-point vertical padding, matching BoostVocab.
- Outer card borders: 4 points.
- Inner list/section borders: 2 points.

Typography:

- Page title: display, 32.
- Card title: display, 20.
- Field labels and buttons: display, 16.
- Transcript and generated content: input/system, 16.
- Metadata and status: input/system, 14.

Avoid rounded corners, shadows, gradients, and platform-colored controls; these would conflict with the current BoostVocab language.

## 7. Component model

Suggested SwiftUI decomposition:

```text
TranscriptInsightView
├── FeatureHeader
│   ├── Back button
│   ├── Title
│   └── History button
├── TranscriptSourceCard
│   ├── URL field
│   ├── Validation/status message
│   └── Primary action
├── TranscriptCard
│   ├── TranscriptCardHeader
│   ├── TranscriptDisplay | TranscriptEditor
│   └── Re-analyze action
└── LessonCard
    ├── ComprehensionSummary
    ├── LanguageItemList
    │   └── LanguageItemCard × 6–10
    ├── PracticeSection
    │   └── PracticeItem × 3–5
    └── LessonFooter
        ├── Anki export action
        └── Listen-again action
```

Prefer extracting a reusable `FeatureHeader` from BoostVocab rather than copying the header markup. Keep feature-specific state and labels in each feature view.

Suggested view state:

```swift
enum TranscriptInsightPhase: Equatable {
    case empty
    case invalidURL(message: String)
    case fetchingTranscript
    case transcribing
    case analyzing
    case complete
    case transcriptFailed(message: String)
    case lessonFailed(message: String)
}

enum TranscriptSource: Equatable {
    case youtubeCaptions
    case tiktokCaptions
    case speechToText
}

struct TranscriptLesson: Equatable {
    var comprehensionSummary: String
    var languageItems: [LanguageItem]
    var practiceItems: [PracticeItem]
    var sourceURL: URL
}
```

The lesson should be structured data, not one Markdown string. This keeps layout stable and lets individual sections evolve later.

## 8. Domain glossary

| Term | Meaning in this feature |
|---|---|
| Source URL | The YouTube or TikTok link submitted by the user. |
| Transcript acquisition | The attempt to obtain existing platform captions. |
| Speech-to-text fallback | Audio transcription used automatically when platform captions are unavailable. |
| Transcript source | The successful origin: platform captions or speech-to-text. |
| Transcript | The text used as the sole input to lesson analysis. |
| Lesson analysis | Transformation of the transcript into the four structured learning sections. |
| Language item | A selected vocabulary item, idiom, phrasal verb, collocation, slang expression, or grammar pattern. |
| High-value language | Language selected because it unlocks the source meaning, is reusable, or is particularly useful above B2. |
| Selection rationale | A short explanation of why a language item was included. |
| CEFR estimate | A prioritization signal for an item, not an objective proficiency certification. |
| Recognition practice | A contextual task such as a cloze, usage choice, or sentence transformation. |
| Production practice | A typed task requiring the learner to retrieve and use a target item naturally. |
| Natural English note | The dedicated Anki note shape for expressions and patterns derived from transcript lessons. |
| Re-analyze | Generate a new lesson from the current transcript without fetching the video again. |
| Stale lesson | A lesson that no longer corresponds to the edited transcript. |
| Partial success | Transcript acquisition succeeded, but lesson analysis failed. |

## 9. Decisions (mini ADRs)

### ADR-001: Use a two-column workspace

Decision: Put URL and transcript on the left, lesson on the right.

Why: It directly echoes BoostVocab’s input/context-left and transformed-output-right structure. It also keeps the evidence and interpretation visible at the same time.

### ADR-002: Automatically choose the transcript method

Decision: Try platform captions first, then speech-to-text without asking the user.

Why: The method is an implementation concern; the user’s goal is a lesson. The source label maintains transparency after the choice is made.

### ADR-003: Separate transcript and analysis phases

Decision: Model acquisition/transcription and lesson analysis as separate visible states.

Why: It communicates progress accurately and preserves the transcript when analysis fails.

### ADR-004: Make transcripts editable

Decision: Permit local transcript edits and explicit lesson re-analysis.

Why: Captions and speech recognition can be wrong, and those errors can materially change a lesson.

### ADR-005: Use a fixed lesson structure

Decision: Comprehension summary, 6–10 ranked language items, practice for the strongest 3–5 items, and a listen-again handoff are the initial sections.

Why: A stable structure is easier to scan, test, render, and later map to structured AI output, while directly supporting the agreed listening-learning loop.

### ADR-006: Keep playback on the source platform

Decision: Provide an external **Open Video and Listen Again** action without embedding playback.

Why: The app owns analysis and practice, while YouTube or TikTok continues to own playback.

### ADR-007: Reveal acquisition fallbacks only after failure

Decision: Keep URL submission as the initial happy path, then offer authorized local media upload and manual transcript paste if URL acquisition fails.

Why: This preserves a simple first impression without pretending every platform URL can always be acquired.

## 10. UI-only implementation checklist

- [ ] Add a `transcript-insight` feature card to `HomeView`.
- [ ] Route `transcript-insight` from `ContentView`.
- [ ] Extract or recreate the shared feature header.
- [ ] Build `TranscriptInsightView` with mocked view states.
- [ ] Build URL validation feedback for YouTube and TikTok hosts.
- [ ] Build the acquisition-failure recovery area for authorized file upload and transcript paste.
- [ ] Build transcript empty, loading, display, edit, and error presentations.
- [ ] Build lesson empty, loading, ranked-language, practice, complete, and error presentations.
- [ ] Add source badges and stage-specific progress copy.
- [ ] Add copy feedback, focus behavior, tooltips, and accessibility labels.
- [ ] Add language-item selection and mocked Natural English Anki export feedback.
- [ ] Add **Open Video and Listen Again** using the source URL.
- [ ] Preview at 1200 × 800 and a larger desktop window.
- [ ] Confirm long transcripts and long lessons scroll independently.
- [ ] Confirm partial-success state keeps the transcript visible.

## 11. Deferred decisions

These are intentionally outside the UI-only v1 and should not block the first screen implementation:

- Persisted result history and its storage model.
- Timestamps and click-to-seek playback.
- Embedded video playback.
- Lesson language and proficiency-level controls.
- Maximum video length and cost limits.
- Authentication or quota presentation.
- Exercise persistence and progress history.
- Spoken production answers.
