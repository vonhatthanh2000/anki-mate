import unittest
from types import SimpleNamespace
from unittest.mock import patch

from transcript_lesson import (
    LanguageItem,
    LessonAnalysis,
    LessonExercise,
    MeaningOverview,
    analyze_transcript,
    normalize_analysis,
)


class NormalizeAnalysisTests(unittest.TestCase):
    transcript = (
        "Although the evidence was limited, Maya took the broader context into account, "
        "ruled out a quick fix, followed through on the experiment, came across an unexpected "
        "pattern, and ended up changing course."
    )

    expressions = [
        "Although the evidence was limited",
        "took the broader context into account",
        "ruled out",
        "followed through",
        "came across",
        "ended up",
    ]

    def make_analysis(self) -> LessonAnalysis:
        items = [
            LanguageItem(
                id=f"raw-{index}",
                expression=expression,
                spanStart=999,
                spanEnd=1000,
                sourceExcerpt="incorrect",
                primaryCategory="Collocation",
                secondaryCategories=[],
                meaningAndUsage="Meaning in context.",
                cefrEstimate="B2",
                selectionRationale="Useful and reusable.",
                naturalExample="A natural example.",
                vietnameseGloss=None,
                practicePriority=index if index <= 3 else None,
            )
            for index, expression in enumerate(self.expressions, start=1)
        ]
        exercises = []
        for index in range(1, 4):
            exercises.extend(
                [
                    LessonExercise(
                        id=f"raw-r-{index}",
                        itemID=f"raw-{index}",
                        kind="recognition",
                        prompt="Recognize it.",
                        expectedAnswer="Answer",
                        explanation="Because of the context.",
                    ),
                    LessonExercise(
                        id=f"raw-p-{index}",
                        itemID=f"raw-{index}",
                        kind="production",
                        prompt="Use it.",
                        expectedAnswer=None,
                        explanation=None,
                    ),
                ]
            )
        return LessonAnalysis(
            overview=MeaningOverview(
                summary=["One.", "Two.", "Three."],
                mainPoint="Investigate carefully.",
                supportingIdeas=["Use context."],
                toneAndRegister="Reflective",
                contextNotes=[],
            ),
            items=items,
            exercises=exercises,
        )

    def test_repairs_spans_ids_and_source_excerpts(self):
        normalized = normalize_analysis(self.make_analysis(), self.transcript)

        self.assertEqual([item.id for item in normalized.items], [f"item-{i}" for i in range(1, 7)])
        for item in normalized.items:
            self.assertEqual(
                self.transcript[item.spanStart:item.spanEnd],
                item.expression,
            )
            self.assertIn(item.expression, item.sourceExcerpt)

    def test_keeps_exactly_two_exercises_for_each_practiced_item(self):
        normalized = normalize_analysis(self.make_analysis(), self.transcript)

        self.assertEqual(len(normalized.exercises), 6)
        self.assertEqual(
            {item.id for item in normalized.items if item.practicePriority is not None},
            {"item-1", "item-2", "item-3"},
        )

    def test_rejects_expressions_not_present_in_transcript(self):
        analysis = self.make_analysis()
        analysis.items[-1].expression = "not present"

        with self.assertRaisesRegex(ValueError, "6–10 unique expressions"):
            normalize_analysis(analysis, self.transcript)

    def test_spans_use_utf16_offsets_expected_by_swift(self):
        transcript = "🔬 " + self.transcript
        normalized = normalize_analysis(self.make_analysis(), transcript)
        first = normalized.items[0]
        utf16 = transcript.encode("utf-16-le")
        selected = utf16[first.spanStart * 2:first.spanEnd * 2].decode("utf-16-le")

        self.assertEqual(selected, first.expression)

    @patch("transcript_lesson._client")
    def test_analyzer_request_requires_speaker_attribution(self, client_factory):
        client = client_factory.return_value
        client.responses.parse.return_value = SimpleNamespace(
            output_parsed=self.make_analysis()
        )

        analyze_transcript(self.transcript)

        instructions = client.responses.parse.call_args.kwargs["instructions"]
        self.assertIn("Attribute unsupported claims to the speaker", instructions)


if __name__ == "__main__":
    unittest.main()
